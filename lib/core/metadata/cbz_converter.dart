import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../sources/archive_page_source.dart';
import '../sources/cbz_page_source.dart';
import '../sources/fingerprint.dart';
import '../sources/libarchive/libarchive.dart';
import '../sources/page_source.dart';
import '../util/natural_sort.dart';

/// Why a comic couldn't be converted.
class ConversionException implements Exception {
  ConversionException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// A finished conversion: the new CBZ and the book's old and new IDs (the
/// IDs [CbzPageSource] and [ArchivePageSource] give them), so reading
/// progress can follow.
typedef Conversion = ({String cbzPath, String oldId, String newId});

/// What kind of file [path] is, by content.
enum ComicFormat { zip, pdf, other }

ComicFormat comicFormatOf(String path) {
  final magic = readMagic(path, 4);
  bool starts(List<int> sig) =>
      magic.length >= sig.length &&
      Iterable<int>.generate(sig.length).every((i) => magic[i] == sig[i]);
  if (starts(const [0x50, 0x4B, 0x03, 0x04]) ||
      starts(const [0x50, 0x4B, 0x05, 0x06])) {
    return ComicFormat.zip;
  }
  if (starts('%PDF'.codeUnits)) return ComicFormat.pdf;
  return ComicFormat.other;
}

/// Converts the CBR/CB7/CBT (any archive libarchive reads) at [path] into a
/// CBZ beside it with the same name. Every file inside is kept (pages
/// stored as they are, without recompressing; ComicInfo.xml and other
/// files compressed), except OS junk such as `__MACOSX/`.
///
/// The CBZ is written to a hidden temp file, checked (same pages, byte for
/// byte, in the same reading order), then renamed into place. The original
/// is left alone: deleting it is the caller's choice. A ZIP that is only
/// named `.cbr` is renamed instead. Runs in a worker isolate.
Future<Conversion> convertToCbz(String path) =>
    Isolate.run(() => _convert(path));

Conversion _convert(String path) {
  final target = p.setExtension(path, '.cbz');
  if (p.equals(target, path)) {
    throw ConversionException('${p.basename(path)} is already a CBZ');
  }
  if (File(target).existsSync()) {
    throw ConversionException('${p.basename(target)} already exists');
  }
  switch (comicFormatOf(path)) {
    case ComicFormat.pdf:
      throw ConversionException('PDFs can’t be converted to CBZ');
    case ComicFormat.zip:
      // Already a ZIP with the wrong name: its ID doesn't depend on it.
      final id = _cbzId(path);
      File(path).renameSync(target);
      return (cbzPath: target, oldId: id, newId: id);
    case ComicFormat.other:
  }

  final la = LibArchive.load();
  if (la == null) {
    throw ConversionException('libarchive is not installed');
  }
  final oldId = 'file:${fileFingerprint(path)}';
  final dir = p.dirname(path);
  // Hidden, so the library watcher ignores it; beside the comic, so there's
  // room for it and the rename is on the same disk.
  final work = Directory(dir).createTempSync('.panelist-convert-');
  try {
    final entries = _extract(la, path, work.path);
    final pages = [
      for (final e in entries)
        if (isPageEntry(e.name)) e,
    ]..sort((a, b) => naturalCompare(a.name, b.name));
    if (pages.isEmpty) {
      throw ConversionException('No images found in ${p.basename(path)}');
    }
    final others = entries.where((e) => !isPageEntry(e.name));

    final zipPath = p.join(work.path, 'out.cbz');
    final out = OutputFileStream(zipPath);
    final inputs = <InputFileStream>[];
    try {
      final encoder = ZipEncoder()..startEncode(out);
      for (final e in [...pages, ...others]) {
        final input = InputFileStream(e.file);
        inputs.add(input);
        encoder.add(
          ArchiveFile.stream(e.name, input)
            ..compression = isPageEntry(e.name)
                ? CompressionType.none
                : CompressionType.deflate,
        );
      }
      encoder.endEncode();
    } finally {
      out.closeSync();
      for (final i in inputs) {
        i.closeSync();
      }
    }

    final newId = _verify(zipPath, pages);
    if (File(target).existsSync()) {
      throw ConversionException('${p.basename(target)} already exists');
    }
    File(zipPath).renameSync(target);
    return (cbzPath: target, oldId: oldId, newId: newId);
  } on ConversionException {
    rethrow;
  } on Object catch (e) {
    throw ConversionException('Couldn’t convert ${p.basename(path)}: $e');
  } finally {
    try {
      work.deleteSync(recursive: true);
    } on FileSystemException {
      // Best effort.
    }
  }
}

typedef _Entry = ({String name, String file, int crc32, int size});

/// Extracts every file entry of the archive into [dir], with its CRC-32.
List<_Entry> _extract(LibArchive la, String path, String dir) {
  final entries = <_Entry>[];
  final seen = <String>{};
  final ArchiveReader r;
  try {
    r = ArchiveReader.open(la, path);
  } on LibArchiveException catch (e) {
    throw ConversionException(
      'Not a readable comic archive: ${p.basename(path)} ($e)',
    );
  }
  try {
    while (r.next()) {
      final name = _safeName(r.path);
      if (!r.isFile || name == null || _isJunk(name) || !seen.add(name)) {
        r.skip();
        continue;
      }
      if (r.isEncrypted) {
        throw ConversionException(
          'Password-protected archives can’t be converted: '
          '${p.basename(path)}',
        );
      }
      final file = p.join(dir, '${entries.length}');
      final sink = File(file).openSync(mode: FileMode.writeOnly);
      var crc = 0, size = 0;
      try {
        r.readData((data, n) {
          final bytes = data.asTypedList(n);
          crc = getCrc32(bytes, crc);
          size += n;
          sink.writeFromSync(bytes);
        });
      } finally {
        sink.closeSync();
      }
      entries.add((name: name, file: file, crc32: crc, size: size));
    }
  } on LibArchiveException catch (e) {
    throw ConversionException(describeExtractFailure(p.basename(path), e));
  } finally {
    r.close();
  }
  return entries;
}

/// The entry's name as a safe relative ZIP path (forward slashes, no
/// leading `/`, no `..`), or null if nothing is left.
String? _safeName(String? raw) {
  if (raw == null) return null;
  final parts = raw
      .replaceAll(r'\', '/')
      .split('/')
      .where((s) => s.isNotEmpty && s != '.' && s != '..');
  return parts.isEmpty ? null : parts.join('/');
}

bool _isJunk(String name) {
  final parts = name.split('/');
  return parts.any((s) => s.startsWith('.') || s == '__MACOSX') ||
      parts.last.toLowerCase() == 'thumbs.db';
}

/// Checks the CBZ at [zipPath] has exactly [pages] in reading order, and
/// returns its book ID.
String _verify(String zipPath, List<_Entry> pages) {
  final input = InputFileStream(zipPath);
  try {
    final written = cbzPages(ZipDecoder().decodeStream(input));
    final same =
        written.length == pages.length &&
        Iterable<int>.generate(pages.length).every(
          (i) =>
              written[i].name == pages[i].name &&
              written[i].crc32 == pages[i].crc32 &&
              written[i].size == pages[i].size,
        );
    if (!same) {
      throw ConversionException('The CBZ’s pages didn’t match the original');
    }
    return 'file:${cbzPagesFingerprint(written)}';
  } finally {
    input.closeSync();
  }
}

String _cbzId(String path) {
  final input = InputFileStream(path);
  try {
    final pages = cbzPages(ZipDecoder().decodeStream(input));
    return 'file:${cbzPagesFingerprint(pages) ?? fileFingerprint(path)}';
  } finally {
    input.closeSync();
  }
}

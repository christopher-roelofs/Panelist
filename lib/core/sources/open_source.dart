import 'dart:io';

import '../../platform/android_documents.dart';
import 'archive_page_source.dart';
import 'cbz_page_source.dart';
import 'fingerprint.dart';
import 'page_source.dart';
import 'pdf_page_source.dart';

/// File extensions offered in the "Open file" dialog.
const comicFileExtensions = [
  'cbz', 'cbr', 'cb7', 'cbt', 'pdf', //
  'zip', 'rar', '7z', 'tar',
];

/// Opens [path] with the right [PageSource] for its format. On Android,
/// [path] may also be a `content://` document URI.
///
/// Files are identified by content rather than extension, because
/// mislabelled comics (e.g. a ZIP named `.cbr`) are common.
Future<PageSource> openSource(String path) async {
  if (AndroidDocuments.isContentUri(path)) return _openDocument(path);
  // Only comic files: a folder of loose images isn't a comic.
  return switch (await FileSystemEntity.type(path)) {
    FileSystemEntityType.file => _openFile(path),
    FileSystemEntityType.directory => throw UnsupportedSourceException(
      'Not a comic file: $path',
    ),
    _ => throw UnsupportedSourceException('Not found: $path'),
  };
}

Future<PageSource> _openDocument(String uri) async {
  final doc = await AndroidDocuments.open(uri);
  try {
    return await _openFile(doc.path, name: doc.name, onClose: doc.release);
  } catch (_) {
    await doc.release?.call();
    rethrow;
  }
}

Future<PageSource> _openFile(
  String path, {
  String? name,
  Future<void> Function()? onClose,
}) async {
  final magic = readMagic(path);
  bool startsWith(List<int> sig) {
    if (magic.length < sig.length) return false;
    for (var i = 0; i < sig.length; i++) {
      if (magic[i] != sig[i]) return false;
    }
    return true;
  }

  // ZIP: our own reader has true random access.
  if (startsWith(const [0x50, 0x4B, 0x03, 0x04]) ||
      startsWith(const [0x50, 0x4B, 0x05, 0x06])) {
    return CbzPageSource.open(path, name: name, onClose: onClose);
  }
  if (startsWith('%PDF'.codeUnits)) {
    return PdfPageSource.open(path, name: name, onClose: onClose);
  }
  // Everything else (RAR, 7z, tar, ...): libarchive detects the format.
  return ArchivePageSource.open(path, name: name, onClose: onClose);
}

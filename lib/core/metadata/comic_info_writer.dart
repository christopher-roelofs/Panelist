import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';

import '../../platform/comic_files.dart';
import '../sources/cbz_page_source.dart';
import 'comic_info.dart';

/// Why a comic's metadata couldn't be saved.
class ComicInfoWriteException implements Exception {
  ComicInfoWriteException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Writes [xml] as the ComicInfo.xml inside the CBZ at [location] (a path,
/// or an Android library document).
///
/// Pages and other entries are copied as they are (no recompression). The
/// new archive is written apart, checked (it opens, and has the same pages
/// and the new ComicInfo), and only then replaces the original; if anything
/// fails the original is untouched. Runs in a worker isolate.
Future<void> writeComicInfoToCbz(String location, String xml) {
  final name = ComicFiles.nameOf(location);
  return ComicFiles.rewrite(
    location,
    (source, target) => Isolate.run(() => _write(source, target, name, xml)),
  );
}

void _write(String path, String target, String name, String xml) {
  final temp = File(target);
  final input = InputFileStream(path);
  try {
    final Archive original;
    final decoder = ZipDecoder();
    try {
      original = decoder.decodeStream(input);
    } on Object {
      throw ComicInfoWriteException('Not a CBZ (ZIP) file: $name');
    }
    final pagesBefore = cbzPagesFingerprint(cbzPages(original));

    // Replace the ComicInfo.xml in place (the shallowest, if there are
    // several; the others are dropped), else add one at the root.
    final infos = [
      for (final f in original.files)
        if (f.isFile && ComicInfo.isComicInfoName(f.name)) f.name,
    ]..sort((a, b) => '/'.allMatches(a).length - '/'.allMatches(b).length);
    final infoName = infos.firstOrNull ?? 'ComicInfo.xml';

    // The archive comment (some scanners sign their releases there).
    final comment = decoder.directory.zipFileComment;
    final updated = Archive()..comment = comment.isEmpty ? null : comment;
    var added = false;
    for (final f in original.files) {
      if (f.isFile && ComicInfo.isComicInfoName(f.name)) {
        if (f.name == infoName && !added) {
          updated.add(ArchiveFile.string(infoName, xml));
          added = true;
        }
        continue;
      }
      updated.add(f);
    }
    if (!added) updated.add(ArchiveFile.string(infoName, xml));

    final out = OutputFileStream(temp.path);
    try {
      ZipEncoder().encodeStream(updated, out);
    } finally {
      out.closeSync();
    }

    _verify(temp.path, pagesBefore, infoName, xml);
    input.closeSync();
  } catch (e) {
    input.closeSync();
    if (temp.existsSync()) temp.deleteSync();
    if (e is ComicInfoWriteException) rethrow;
    throw ComicInfoWriteException('Couldn’t save $name: $e');
  }
}

void _verify(String path, String? pagesBefore, String infoName, String xml) {
  final input = InputFileStream(path);
  try {
    final archive = ZipDecoder().decodeStream(input);
    final pages = cbzPages(archive);
    if (pages.isEmpty || cbzPagesFingerprint(pages) != pagesBefore) {
      throw ComicInfoWriteException('The saved copy’s pages didn’t match');
    }
    final info = archive.findFile(infoName);
    if (info == null || utf8.decode(info.readBytes()!) != xml) {
      throw ComicInfoWriteException('The saved copy’s ComicInfo didn’t match');
    }
  } finally {
    input.closeSync();
  }
}

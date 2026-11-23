import 'dart:io';

import 'archive_page_source.dart';
import 'cbz_page_source.dart';
import 'fingerprint.dart';
import 'folder_page_source.dart';
import 'page_source.dart';
import 'pdf_page_source.dart';

/// File extensions offered in the "Open file" dialog.
const comicFileExtensions = [
  'cbz', 'cbr', 'cb7', 'cbt', 'pdf', //
  'zip', 'rar', '7z', 'tar',
];

/// Opens [path] with the right [PageSource] for its format.
///
/// Files are identified by content rather than extension, because
/// mislabelled comics (e.g. a ZIP named `.cbr`) are common.
Future<PageSource> openSource(String path) async {
  switch (await FileSystemEntity.type(path)) {
    case FileSystemEntityType.directory:
      return FolderPageSource.open(path);
    case FileSystemEntityType.file:
      return _openFile(path);
    default:
      throw UnsupportedSourceException('Not found: $path');
  }
}

Future<PageSource> _openFile(String path) async {
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
    return CbzPageSource.open(path);
  }
  if (startsWith('%PDF'.codeUnits)) {
    return PdfPageSource.open(path);
  }
  // Everything else (RAR, 7z, tar, ...): libarchive detects the format.
  return ArchivePageSource.open(path);
}

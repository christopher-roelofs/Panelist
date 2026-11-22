import 'dart:io';

import 'package:path/path.dart' as p;

import 'cbz_page_source.dart';
import 'fingerprint.dart';
import 'folder_page_source.dart';
import 'page_source.dart';

/// File extensions offered in the "Open file" dialog.
const comicFileExtensions = ['cbz', 'zip'];

/// Opens [path] with the right [PageSource] for its format.
///
/// Files are identified by their magic bytes rather than their extension,
/// because mislabelled comics (e.g. a ZIP named `.cbr`) are common.
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

  if (startsWith(const [0x50, 0x4B, 0x03, 0x04]) ||
      startsWith(const [0x50, 0x4B, 0x05, 0x06])) {
    return CbzPageSource.open(path);
  }
  final name = p.basename(path);
  if (startsWith('Rar!'.codeUnits)) {
    throw UnsupportedSourceException('RAR/CBR support is coming soon: $name');
  }
  if (startsWith(const [0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C])) {
    throw UnsupportedSourceException('7z/CB7 support is coming soon: $name');
  }
  if (startsWith('%PDF'.codeUnits)) {
    throw UnsupportedSourceException('PDF support is coming soon: $name');
  }
  throw UnsupportedSourceException('Not a supported comic file: $name');
}

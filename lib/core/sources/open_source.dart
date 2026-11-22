import 'dart:io';

import 'folder_page_source.dart';
import 'page_source.dart';

/// Opens [path] with the right [PageSource] implementation for its format.
Future<PageSource> openSource(String path) async {
  final type = await FileSystemEntity.type(path);
  switch (type) {
    case FileSystemEntityType.directory:
      return FolderPageSource.open(path);
    case FileSystemEntityType.file:
      // CBZ arrives in M1; CBR/CB7/CBT/PDF in M2.
      throw UnsupportedSourceException(
        'This file type is not supported yet: $path',
      );
    default:
      throw UnsupportedSourceException('Not found: $path');
  }
}

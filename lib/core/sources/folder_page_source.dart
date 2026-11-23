import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:path/path.dart' as p;

import '../imaging/image_probe.dart';
import '../metadata/comic_info.dart';
import '../util/natural_sort.dart';
import 'page_source.dart';

/// A comic stored as a directory of image files (searched recursively,
/// so chapter sub-folders work). Pages are ordered by natural sort of their
/// path relative to the root.
class FolderPageSource implements EncodedPageSource {
  FolderPageSource._(this._root, this._pages);

  final Directory _root;
  final List<String> _pages; // absolute paths, in reading order

  static Future<FolderPageSource> open(String path) async {
    final root = Directory(path);
    if (!await root.exists()) {
      throw UnsupportedSourceException('Folder not found: $path');
    }
    final rel = <String>[];
    await for (final e in root.list(recursive: true, followLinks: false)) {
      if (e is! File) continue;
      final r = p.relative(e.path, from: root.path);
      if (isPageEntry(r)) rel.add(r);
    }
    if (rel.isEmpty) {
      throw UnsupportedSourceException('No images found in $path');
    }
    rel.sort(naturalCompare);
    return FolderPageSource._(root, [
      for (final r in rel) p.join(root.path, r),
    ]);
  }

  @override
  String get id => 'folder:${p.canonicalize(_root.path)}';

  @override
  String get title => p.basename(p.canonicalize(_root.path));

  @override
  int get pageCount => _pages.length;

  @override
  Future<Uint8List> page(int index) => File(_pages[index]).readAsBytes();

  @override
  Future<List<Size?>> probePageSizes() async => [
    for (final path in _pages) await probeImageFile(path),
  ];

  @override
  Future<String?> readComicInfo() async {
    await for (final e in _root.list(followLinks: false)) {
      if (e is File && ComicInfo.isComicInfoName(e.path)) {
        return utf8.decode(await e.readAsBytes(), allowMalformed: true);
      }
    }
    return null;
  }

  @override
  Future<void> close() async {}
}

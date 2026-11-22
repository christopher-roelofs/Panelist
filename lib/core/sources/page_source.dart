import 'dart:typed_data';

import 'package:path/path.dart' as p;

/// A readable comic: an ordered list of page images, regardless of the
/// container format (folder, CBZ, CBR, PDF, ...).
///
/// The reader only ever talks to this interface.
abstract class PageSource {
  /// Stable identifier for this book, used for image cache keys and,
  /// later, for persisting reading progress.
  String get id;

  /// Human-readable title (usually derived from the file/folder name).
  String get title;

  int get pageCount;

  /// Encoded image bytes (JPEG/PNG/WebP/...) for page [index].
  Future<Uint8List> page(int index);

  /// Releases any open handles. The source must not be used afterwards.
  Future<void> close();
}

/// Thrown when a path can't be opened as a comic.
class UnsupportedSourceException implements Exception {
  UnsupportedSourceException(this.message);
  final String message;
  @override
  String toString() => message;
}

const imageExtensions = {'.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp'};

/// Whether an entry inside a comic (relative path) is a real page image,
/// filtering out OS junk such as `__MACOSX/`, `.DS_Store` and `Thumbs.db`.
bool isPageEntry(String relativePath) {
  final parts = p.split(relativePath);
  if (parts.any((s) => s.startsWith('.') || s == '__MACOSX')) return false;
  return imageExtensions.contains(p.extension(relativePath).toLowerCase());
}

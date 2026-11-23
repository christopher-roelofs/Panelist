import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:path/path.dart' as p;

/// A readable comic: an ordered list of pages, regardless of the container
/// format (folder, CBZ, CBR, PDF, ...).
///
/// Implementations are either [EncodedPageSource] (pages are image files)
/// or [RenderedPageSource] (pages are drawn on demand, e.g. PDF).
sealed class PageSource {
  /// Stable identifier for this book, used for image cache keys and for
  /// persisting reading progress.
  String get id;

  /// Human-readable title (usually derived from the file/folder name).
  String get title;

  int get pageCount;

  /// Releases any open handles. The source must not be used afterwards.
  Future<void> close();
}

/// Pages are stored as encoded images (JPEG/PNG/WebP/...).
abstract class EncodedPageSource implements PageSource {
  /// Encoded image bytes for page [index].
  Future<Uint8List> page(int index);
}

/// Pages are rendered on demand at any requested resolution (vector
/// formats such as PDF).
abstract class RenderedPageSource implements PageSource {
  /// The page's natural size in points (1/72 inch).
  ui.Size pageSize(int index);

  /// Renders page [index] at exactly [width] × [height] pixels.
  Future<ui.Image> render(int index, int width, int height);
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

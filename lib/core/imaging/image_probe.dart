import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'image_header.dart';

/// Pixel size of the image file at [path], reading only its header when
/// possible (falls back to the whole file for JPEGs with huge metadata).
Future<Size?> probeImageFile(String path) async {
  final raf = await File(path).open();
  try {
    final head = await raf.read(64 * 1024);
    final size = readImageSize(head);
    if (size != null || head.length < 64 * 1024) return size;
    await raf.setPosition(0);
    return readImageSize(await raf.read(await raf.length()));
  } finally {
    await raf.close();
  }
}

/// Convenience for sources that already hold the bytes.
Size? probeImageBytes(Uint8List bytes) => readImageSize(bytes);

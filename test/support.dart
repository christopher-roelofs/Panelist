import 'dart:typed_data';

/// Just enough of a PNG for header-based size probing.
Uint8List pngHeader(int width, int height) {
  final b = ByteData(33);
  const sig = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  for (var i = 0; i < 8; i++) {
    b.setUint8(i, sig[i]);
  }
  b.setUint32(8, 13);
  for (final (i, c) in 'IHDR'.codeUnits.indexed) {
    b.setUint8(12 + i, c);
  }
  b.setUint32(16, width);
  b.setUint32(20, height);
  return b.buffer.asUint8List();
}

const comicInfoXml =
    '<?xml version="1.0"?><ComicInfo><Series>Ünïcode Saga</Series>'
    '<Number>3</Number></ComicInfo>';

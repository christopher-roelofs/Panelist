import 'dart:typed_data';
import 'dart:ui' show Size;

/// Reads an image's pixel dimensions from its header without decoding it.
///
/// Supports JPEG, PNG, GIF, BMP and WebP (lossy, lossless, extended).
/// Returns null for unknown formats, or if [bytes] is truncated before the
/// dimensions (callers can retry with more bytes).
Size? readImageSize(Uint8List bytes) {
  if (bytes.length < 10) return null;
  final d = ByteData.sublistView(bytes);
  int u8(int i) => bytes[i];
  int be16(int i) => d.getUint16(i);
  int le16(int i) => d.getUint16(i, Endian.little);

  // PNG: signature, then IHDR width/height (big-endian).
  if (u8(0) == 0x89 && u8(1) == 0x50 && u8(2) == 0x4E && u8(3) == 0x47) {
    if (bytes.length < 24) return null;
    return _size(d.getUint32(16), d.getUint32(20));
  }
  // GIF87a / GIF89a: logical screen size (little-endian).
  if (u8(0) == 0x47 && u8(1) == 0x49 && u8(2) == 0x46) {
    return _size(le16(6), le16(8));
  }
  // BMP: BITMAPINFOHEADER width/height (height negative = top-down).
  if (u8(0) == 0x42 && u8(1) == 0x4D) {
    if (bytes.length < 26) return null;
    return _size(
      d.getInt32(18, Endian.little).abs(),
      d.getInt32(22, Endian.little).abs(),
    );
  }
  // WebP: RIFF....WEBP then a VP8 / VP8L / VP8X chunk.
  if (bytes.length >= 30 &&
      _ascii(bytes, 0, 'RIFF') &&
      _ascii(bytes, 8, 'WEBP')) {
    if (_ascii(bytes, 12, 'VP8 ')) {
      return _size(le16(26) & 0x3FFF, le16(28) & 0x3FFF);
    }
    if (_ascii(bytes, 12, 'VP8L')) {
      final b = d.getUint32(21, Endian.little);
      return _size((b & 0x3FFF) + 1, ((b >> 14) & 0x3FFF) + 1);
    }
    if (_ascii(bytes, 12, 'VP8X')) {
      int le24(int i) => u8(i) | u8(i + 1) << 8 | u8(i + 2) << 16;
      return _size(le24(24) + 1, le24(27) + 1);
    }
    return null;
  }
  // JPEG: walk segments to the first start-of-frame marker.
  if (u8(0) == 0xFF && u8(1) == 0xD8) {
    var i = 2;
    while (i + 9 < bytes.length) {
      if (u8(i) != 0xFF) return null; // corrupt
      final marker = u8(i + 1);
      if (marker == 0xFF) {
        i++; // fill byte
        continue;
      }
      // SOF0..SOF15, excluding DHT (C4), JPG (C8) and DAC (CC).
      if (marker >= 0xC0 &&
          marker <= 0xCF &&
          marker != 0xC4 &&
          marker != 0xC8 &&
          marker != 0xCC) {
        return _size(be16(i + 7), be16(i + 5));
      }
      // Standalone markers without a length.
      if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) {
        i += 2;
        continue;
      }
      i += 2 + be16(i + 2);
    }
    return null; // truncated before SOF
  }
  return null;
}

Size? _size(int w, int h) =>
    w > 0 && h > 0 ? Size(w.toDouble(), h.toDouble()) : null;

bool _ascii(Uint8List b, int offset, String s) {
  for (var i = 0; i < s.length; i++) {
    if (b[offset + i] != s.codeUnitAt(i)) return false;
  }
  return true;
}

import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';

const _sampleSize = 64 * 1024;

/// A content-based identity for a file: SHA-1 over its length plus the first
/// and last 64 KiB. Cheap (reads at most 128 KiB) and survives renames and
/// moves, so reading progress follows the book rather than its path.
String fileFingerprint(String path) {
  final raf = File(path).openSync();
  try {
    final length = raf.lengthSync();
    final head = raf.readSync(math.min(_sampleSize, length));
    final tailStart = math.max(head.length, length - _sampleSize);
    raf.setPositionSync(tailStart);
    final tail = raf.readSync(length - tailStart);
    final digest = sha1.convert([...'$length:'.codeUnits, ...head, ...tail]);
    return digest.toString();
  } finally {
    raf.closeSync();
  }
}

/// The first [n] bytes of [path], for format sniffing.
List<int> readMagic(String path, [int n = 8]) {
  final raf = File(path).openSync();
  try {
    return raf.readSync(n);
  } finally {
    raf.closeSync();
  }
}

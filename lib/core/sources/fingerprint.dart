import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'fd_file.dart';

const _sampleSize = 64 * 1024;

/// A content-based identity for a file: SHA-1 over its length plus the first
/// and last 64 KiB. Cheap (reads at most 128 KiB) and survives renames and
/// moves, so reading progress follows the book rather than its path.
String fileFingerprint(String path) {
  final (length, read, done) = _openForRead(path);
  try {
    final head = read(0, math.min(_sampleSize, length));
    final tailStart = math.max(head.length, length - _sampleSize);
    final tail = read(tailStart, length - tailStart);
    final digest = sha1.convert([...'$length:'.codeUnits, ...head, ...tail]);
    return digest.toString();
  } finally {
    done();
  }
}

/// The first [n] bytes of [path], for format sniffing.
List<int> readMagic(String path, [int n = 8]) {
  final (length, read, done) = _openForRead(path);
  try {
    return read(0, math.min(n, length));
  } finally {
    done();
  }
}

/// (length, read(offset, count), close) for a path or `/proc/self/fd/<n>`.
(int, Uint8List Function(int, int), void Function()) _openForRead(String path) {
  final fd = fdOfPath(path);
  if (fd != null) {
    final r = FdReader(fd);
    return (r.length, r.read, r.dispose);
  }
  final raf = File(path).openSync();
  return (
    raf.lengthSync(),
    (offset, count) {
      raf.setPositionSync(offset);
      return raf.readSync(count);
    },
    raf.closeSync,
  );
}

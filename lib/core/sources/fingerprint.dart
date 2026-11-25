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

/// A content-based identity from a comic's pages alone: SHA-1 over each
/// page's CRC-32 and size, in reading order. Metadata files (ComicInfo.xml
/// and the like), file and page names, and how the archive was compressed
/// don't affect it, so tagging a comic or re-zipping it keeps its reading
/// progress. Null if a page has no CRC (then use [fileFingerprint]).
String? pagesFingerprint(Iterable<({int? crc32, int size})> pages) {
  final parts = <String>[];
  for (final page in pages) {
    final crc = page.crc32;
    if (crc == null) return null;
    parts.add('${crc.toRadixString(16)}:${page.size}');
  }
  return 'pages:${sha1.convert(parts.join(',').codeUnits)}';
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

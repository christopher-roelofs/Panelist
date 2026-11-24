import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:ffi/ffi.dart';

/// Reading files through an already-open file descriptor.
///
/// On Android, documents from the Storage Access Framework arrive as file
/// descriptors. Their `/proc/self/fd/<n>` path names the descriptor, but
/// *opening* that path re-resolves the underlying file (e.g. a path in
/// shared storage) and fails with EACCES. So readers recognise such paths
/// with [fdOfPath] and read the descriptor directly with `pread`, which
/// never moves the shared file offset and is safe from any isolate.

final _fdPath = RegExp(r'^/proc/self/fd/(\d+)$');

/// The descriptor named by a `/proc/self/fd/<n>` [path], or null.
int? fdOfPath(String path) {
  final m = _fdPath.firstMatch(path);
  return m == null ? null : int.parse(m.group(1)!);
}

final _libc = DynamicLibrary.process();

final _pread = _libc
    .lookupFunction<
      IntPtr Function(Int, Pointer<Uint8>, Size, Int64),
      int Function(int, Pointer<Uint8>, int, int)
    >('pread64');

final _lseek = _libc
    .lookupFunction<
      Int64 Function(Int, Int64, Int),
      int Function(int, int, int)
    >('lseek64');

const _seekSet = 0;
const _seekCur = 1;
const _seekEnd = 2;

/// Random-access reads from file descriptor [fd]. Does not own [fd].
class FdReader {
  FdReader(this.fd);

  final int fd;
  Pointer<Uint8> _buf = nullptr;
  int _bufSize = 0;

  /// The file's size in bytes.
  int get length {
    final saved = _lseek(fd, 0, _seekCur);
    final end = _lseek(fd, 0, _seekEnd);
    _lseek(fd, saved, _seekSet);
    if (end < 0) throw FileSystemException('Cannot seek', 'fd $fd');
    return end;
  }

  /// Reads up to [count] bytes at [offset] into [into] (from index
  /// [start]). Returns the number of bytes read; fewer than [count] only at
  /// the end of the file.
  int readInto(Uint8List into, int offset, int count, [int start = 0]) {
    if (count > _bufSize) {
      if (_buf != nullptr) malloc.free(_buf);
      _bufSize = math.max(count, 64 * 1024);
      _buf = malloc<Uint8>(_bufSize);
    }
    var done = 0;
    while (done < count) {
      final n = _pread(fd, _buf + done, count - done, offset + done);
      if (n < 0) throw FileSystemException('Read failed', 'fd $fd');
      if (n == 0) break;
      done += n;
    }
    into.setRange(start, start + done, _buf.asTypedList(done));
    return done;
  }

  /// Reads up to [count] bytes at [offset].
  Uint8List read(int offset, int count) {
    final out = Uint8List(count);
    final n = readInto(out, offset, count);
    return n == count ? out : Uint8List.sublistView(out, 0, n);
  }

  /// Rewinds the shared file offset (for readers that use read(2), such as
  /// libarchive's `archive_read_open_fd`).
  void rewind() => _lseek(fd, 0, _seekSet);

  void dispose() {
    if (_buf != nullptr) malloc.free(_buf);
    _buf = nullptr;
    _bufSize = 0;
  }
}

/// An `archive` package file handle over a descriptor, for [InputFileStream].
class FdFileHandle extends AbstractFileHandle {
  FdFileHandle(int fd) : _reader = FdReader(fd) {
    _length = _reader.length;
  }

  final FdReader _reader;
  late final int _length;
  var _position = 0;
  var _open = true;

  @override
  int get position => _position;

  @override
  set position(int p) => _position = p;

  @override
  int get length => _length;

  @override
  bool get isOpen => _open;

  @override
  Future<void> close() async => closeSync();

  @override
  void closeSync() {
    _open = false;
    _reader.dispose();
  }

  @override
  int readInto(Uint8List buffer, [int? length]) {
    final n = _reader.readInto(buffer, _position, length ?? buffer.length);
    _position += n;
    return n;
  }

  @override
  void writeFromSync(List<int> buffer, [int start = 0, int? end]) =>
      throw UnsupportedError('read-only');
}

// Minimal dart:ffi bindings for libarchive's read API.
// https://github.com/libarchive/libarchive/wiki/ManualPages

import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import '../fd_file.dart';

final class LaArchive extends Opaque {}

final class LaEntry extends Opaque {}

// Return codes.
const archiveOk = 0;
const archiveEof = 1;
const archiveRetry = -10;
const archiveWarn = -20;
const archiveFailed = -25;
const archiveFatal = -30;

// File types (st_mode & AE_IFMT). mode_t is 16-bit on macOS, so callers
// mask the result.
const _aeIfmt = 0xF000;
const _aeIfreg = 0x8000;

typedef _ArchivePtrFn = Pointer<LaArchive> Function();
typedef _IntArchiveC = Int Function(Pointer<LaArchive>);
typedef _IntArchive = int Function(Pointer<LaArchive>);

class LibArchive {
  LibArchive._(DynamicLibrary lib)
    : readNew = lib.lookupFunction<_ArchivePtrFn, _ArchivePtrFn>(
        'archive_read_new',
      ),
      supportFilterAll = lib.lookupFunction<_IntArchiveC, _IntArchive>(
        'archive_read_support_filter_all',
      ),
      supportFormatAll = lib.lookupFunction<_IntArchiveC, _IntArchive>(
        'archive_read_support_format_all',
      ),
      openFilename = lib
          .lookupFunction<
            Int Function(Pointer<LaArchive>, Pointer<Utf8>, Size),
            int Function(Pointer<LaArchive>, Pointer<Utf8>, int)
          >('archive_read_open_filename'),
      openFd = lib
          .lookupFunction<
            Int Function(Pointer<LaArchive>, Int, Size),
            int Function(Pointer<LaArchive>, int, int)
          >('archive_read_open_fd'),
      nextHeader = lib
          .lookupFunction<
            Int Function(Pointer<LaArchive>, Pointer<Pointer<LaEntry>>),
            int Function(Pointer<LaArchive>, Pointer<Pointer<LaEntry>>)
          >('archive_read_next_header'),
      readData = lib
          .lookupFunction<
            IntPtr Function(Pointer<LaArchive>, Pointer<Void>, Size),
            int Function(Pointer<LaArchive>, Pointer<Void>, int)
          >('archive_read_data'),
      dataSkip = lib.lookupFunction<_IntArchiveC, _IntArchive>(
        'archive_read_data_skip',
      ),
      errorString = lib
          .lookupFunction<
            Pointer<Utf8> Function(Pointer<LaArchive>),
            Pointer<Utf8> Function(Pointer<LaArchive>)
          >('archive_error_string'),
      readFree = lib.lookupFunction<_IntArchiveC, _IntArchive>(
        'archive_read_free',
      ),
      _entryPathnameUtf8 = lib
          .lookupFunction<
            Pointer<Utf8> Function(Pointer<LaEntry>),
            Pointer<Utf8> Function(Pointer<LaEntry>)
          >('archive_entry_pathname_utf8'),
      _entryPathname = lib
          .lookupFunction<
            Pointer<Utf8> Function(Pointer<LaEntry>),
            Pointer<Utf8> Function(Pointer<LaEntry>)
          >('archive_entry_pathname'),
      _entryFiletype = lib
          .lookupFunction<
            Uint32 Function(Pointer<LaEntry>),
            int Function(Pointer<LaEntry>)
          >('archive_entry_filetype'),
      _entryIsEncrypted = lib
          .lookupFunction<
            Int Function(Pointer<LaEntry>),
            int Function(Pointer<LaEntry>)
          >('archive_entry_is_encrypted'),
      _entrySize = lib
          .lookupFunction<
            Int64 Function(Pointer<LaEntry>),
            int Function(Pointer<LaEntry>)
          >('archive_entry_size'),
      _entrySizeIsSet = lib
          .lookupFunction<
            Int Function(Pointer<LaEntry>),
            int Function(Pointer<LaEntry>)
          >('archive_entry_size_is_set');

  static LibArchive? _instance;

  /// Loads the system libarchive, or returns null if it isn't available.
  static LibArchive? load() {
    if (_instance != null) return _instance;
    final candidates = switch (Platform.operatingSystem) {
      'linux' || 'android' => ['libarchive.so.13', 'libarchive.so'],
      'macos' => [
        'libarchive.13.dylib',
        '/opt/homebrew/opt/libarchive/lib/libarchive.13.dylib',
        '/usr/local/opt/libarchive/lib/libarchive.13.dylib',
      ],
      'windows' => ['archive.dll'],
      _ => const <String>[],
    };
    for (final name in candidates) {
      try {
        return _instance = LibArchive._(DynamicLibrary.open(name));
      } on ArgumentError {
        // try the next candidate
      }
    }
    return null;
  }

  final Pointer<LaArchive> Function() readNew;
  final int Function(Pointer<LaArchive>) supportFilterAll;
  final int Function(Pointer<LaArchive>) supportFormatAll;
  final int Function(Pointer<LaArchive>, Pointer<Utf8>, int) openFilename;
  final int Function(Pointer<LaArchive>, int, int) openFd;
  final int Function(Pointer<LaArchive>, Pointer<Pointer<LaEntry>>) nextHeader;
  final int Function(Pointer<LaArchive>, Pointer<Void>, int) readData;
  final int Function(Pointer<LaArchive>) dataSkip;
  final Pointer<Utf8> Function(Pointer<LaArchive>) errorString;
  final int Function(Pointer<LaArchive>) readFree;
  final Pointer<Utf8> Function(Pointer<LaEntry>) _entryPathnameUtf8;
  final Pointer<Utf8> Function(Pointer<LaEntry>) _entryPathname;
  final int Function(Pointer<LaEntry>) _entryFiletype;
  final int Function(Pointer<LaEntry>) _entryIsEncrypted;
  final int Function(Pointer<LaEntry>) _entrySize;
  final int Function(Pointer<LaEntry>) _entrySizeIsSet;

  String? entryPath(Pointer<LaEntry> e) {
    var s = _entryPathnameUtf8(e);
    if (s == nullptr) s = _entryPathname(e);
    return s == nullptr ? null : s.toDartString();
  }

  bool entryIsFile(Pointer<LaEntry> e) =>
      (_entryFiletype(e) & _aeIfmt) == _aeIfreg;

  bool entryIsEncrypted(Pointer<LaEntry> e) => _entryIsEncrypted(e) > 0;

  /// The entry's unpacked size, or null if the archive doesn't say.
  int? entrySize(Pointer<LaEntry> e) =>
      _entrySizeIsSet(e) != 0 ? _entrySize(e) : null;

  String error(Pointer<LaArchive> a) {
    final s = errorString(a);
    return s == nullptr ? 'unknown error' : s.toDartString();
  }
}

/// Thrown by [ArchiveReader] on a libarchive failure.
class LibArchiveException implements Exception {
  LibArchiveException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Sequential reader over one archive. Always [close] it.
class ArchiveReader {
  ArchiveReader._(this._la, this._a);

  /// Opens [path]; throws [LibArchiveException] if it isn't a readable
  /// archive.
  factory ArchiveReader.open(LibArchive la, String path) {
    final a = la.readNew();
    if (a == nullptr) throw LibArchiveException('Out of memory');
    la.supportFilterAll(a);
    la.supportFormatAll(a);
    // A `/proc/self/fd/<n>` path can't be reopened on Android (see
    // fd_file.dart), so read the descriptor itself, from the start.
    final fd = fdOfPath(path);
    final int status;
    if (fd != null) {
      FdReader(fd).rewind();
      status = la.openFd(a, fd, 1 << 16);
    } else {
      final cPath = path.toNativeUtf8();
      try {
        status = la.openFilename(a, cPath, 1 << 16);
      } finally {
        malloc.free(cPath);
      }
    }
    if (status != archiveOk) {
      final msg = la.error(a);
      la.readFree(a);
      throw LibArchiveException(msg);
    }
    return ArchiveReader._(la, a);
  }

  final LibArchive _la;
  final Pointer<LaArchive> _a;
  final _entry = calloc<Pointer<LaEntry>>();
  Pointer<Uint8>? _buffer;
  static const _bufferSize = 1 << 20;
  static const _rar5PastEnd = 'Unsupported block header size';

  /// Advances to the next entry. Returns false at the end of the archive.
  bool next() {
    while (true) {
      final r = _la.nextHeader(_a, _entry);
      if (r == archiveEof) return false;
      if (r == archiveOk || r == archiveWarn) return true;
      if (r == archiveRetry) continue;
      throw LibArchiveException(_la.error(_a));
    }
  }

  String? get path => _la.entryPath(_entry.value);
  bool get isFile => _la.entryIsFile(_entry.value);
  bool get isEncrypted => _la.entryIsEncrypted(_entry.value);

  void skip() {
    final r = _la.dataSkip(_a);
    if (r < archiveWarn) throw LibArchiveException(_la.error(_a));
  }

  /// Streams the current entry's data in chunks to [sink]. [shouldStop] is
  /// polled between chunks; returns false if it stopped early.
  bool readData(
    void Function(Pointer<Uint8> data, int length) sink, {
    bool Function()? shouldStop,
  }) {
    final buf = _buffer ??= malloc<Uint8>(_bufferSize);
    final size = _la.entrySize(_entry.value);
    var delivered = 0;
    while (true) {
      if (shouldStop?.call() ?? false) return false;
      final n = _la.readData(_a, buf.cast(), _bufferSize);
      if (n == 0) return true;
      if (n < 0) {
        if (n == archiveRetry || n == archiveWarn) continue;
        // libarchive's RAR 5 reader can miss the end of an entry and read
        // one block past it, after the whole entry has come out (files by
        // recent WinRAR versions; checked against unrar byte for byte).
        // The data is complete and the next header is still readable, so
        // take it. Only that error: others that come after the last byte
        // (a failed checksum) mean the data is wrong.
        final message = _la.error(_a);
        if (delivered == size &&
            delivered > 0 &&
            message.contains(_rar5PastEnd)) {
          return true;
        }
        throw LibArchiveException(message);
      }
      sink(buf, n);
      delivered += n;
    }
  }

  void close() {
    _la.readFree(_a);
    calloc.free(_entry);
    final b = _buffer;
    if (b != null) malloc.free(b);
  }
}

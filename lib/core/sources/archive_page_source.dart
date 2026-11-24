import 'dart:async';
import 'dart:convert';
import 'dart:ffi' hide Size;
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

import '../imaging/image_probe.dart';
import '../metadata/comic_info.dart';
import '../util/natural_sort.dart';
import 'fingerprint.dart';
import 'libarchive/libarchive.dart';
import 'page_source.dart';

/// A comic in any archive format libarchive reads: CBR (RAR 4/5), CB7 (7z),
/// CBT (tar), and more.
///
/// Solid archives (common for 7z, possible for RAR) can't be read at random
/// positions without decompressing everything before them, so a worker
/// isolate lists the pages and then extracts them all in one sequential pass
/// into a private cache directory. Pages become readable as soon as they are
/// extracted; [page] waits for pages that aren't there yet. The cache is
/// deleted on [close].
class ArchivePageSource implements EncodedPageSource {
  ArchivePageSource._(
    this.path,
    this.fileName,
    this._onClose,
    this.id,
    this._names,
    this._dir,
    this._stopFlag,
    this._exited,
    this._comicInfo,
  );

  /// Where per-book extraction directories are created. Set at startup to
  /// the app cache directory; defaults to the system temp directory.
  static Directory? cacheRoot;

  final String path;

  /// The comic's file name, for display.
  final String fileName;
  final Future<void> Function()? _onClose;
  @override
  final String id;
  final List<String> _names;
  final Directory _dir;
  final Pointer<Int32> _stopFlag; // shared with the worker
  final Future<void> _exited;
  final String? _comicInfo;

  final _extracted = <int>{};
  final _waiters = <int, List<Completer<void>>>{};
  Object? _failure;
  bool _closed = false;

  /// [name] is the file name to show (defaults to [path]'s basename, which
  /// is meaningless for e.g. `/proc/self/fd/N`); [onClose] runs after
  /// [close] has released everything.
  static Future<ArchivePageSource> open(
    String path, {
    String? name,
    Future<void> Function()? onClose,
  }) async {
    final fileName = name ?? p.basename(path);
    final root = cacheRoot ?? Directory.systemTemp;
    await root.create(recursive: true);
    final dir = await root.createTemp('book_${pid}_');
    final stopFlag = calloc<Int32>();
    // One port for everything, so the exit notice is ordered after the
    // worker's last message.
    final replies = ReceivePort();
    final ready = Completer<(String, List<String>, String?)>();
    final exited = Completer<void>();
    ArchivePageSource? source;

    replies.listen((msg) {
      switch (msg) {
        case (
          'ready',
          final String fp,
          final List<String> names,
          final String? info,
        ):
          ready.complete((fp, names, info));
        case ('page', final int i):
          source?._onExtracted(i);
        case ('failed', final String error):
          if (!ready.isCompleted) {
            ready.completeError(UnsupportedSourceException(error));
          }
          source?._onFailed(error);
        case [final String error, _]: // uncaught error in the worker
          source?._onFailed(error);
        case null: // onExit notice
          if (!ready.isCompleted) {
            ready.completeError(
              UnsupportedSourceException('Could not read $fileName'),
            );
          }
          source?._onExited();
          exited.complete();
          replies.close();
      }
    });

    await Isolate.spawn(
      _workerMain,
      (replies.sendPort, path, fileName, dir.path, stopFlag.address),
      debugName: 'archive:$fileName',
      onExit: replies.sendPort,
      onError: replies.sendPort,
      errorsAreFatal: true,
    );

    try {
      final (fp, names, info) = await ready.future;
      return source = ArchivePageSource._(
        path,
        fileName,
        onClose,
        'file:$fp',
        names,
        dir,
        stopFlag,
        exited.future,
        info,
      );
    } catch (_) {
      await exited.future;
      calloc.free(stopFlag);
      await _deleteQuietly(dir);
      rethrow;
    }
  }

  @override
  String get title => p.basenameWithoutExtension(fileName);

  @override
  int get pageCount => _names.length;

  /// Entry names in reading order (exposed for tests and diagnostics).
  List<String> get pageNames => List.unmodifiable(_names);

  /// Whether every page has been extracted (for tests and diagnostics).
  bool get isFullyExtracted => _extracted.length == _names.length;

  @override
  Future<Uint8List> page(int index) async {
    await _waitFor(index);
    return File(_pagePath(index)).readAsBytes();
  }

  @override
  Future<List<Size?>> probePageSizes() async => [
    for (var i = 0; i < pageCount; i++)
      await _waitFor(i).then((_) => probeImageFile(_pagePath(i))),
  ];

  @override
  Future<String?> readComicInfo() async => _comicInfo;

  String _pagePath(int index) => p.join(_dir.path, '$index');

  Future<void> _waitFor(int index) async {
    RangeError.checkValidIndex(index, _names);
    if (_extracted.contains(index)) return;
    if (_closed) throw StateError('Source is closed');
    if (_failure != null) throw Exception(_failure);
    final c = Completer<void>();
    (_waiters[index] ??= []).add(c);
    await c.future;
  }

  void _onExtracted(int i) {
    _extracted.add(i);
    for (final c in _waiters.remove(i) ?? const <Completer<void>>[]) {
      c.complete();
    }
  }

  void _onFailed(String error) {
    _failure = error;
    _failWaiters(Exception(error));
  }

  /// Worker finished (or crashed): anything not extracted by now never will be.
  void _onExited() {
    if (!isFullyExtracted && !_closed) {
      _onFailed(_failure?.toString() ?? 'Extraction stopped unexpectedly');
    }
  }

  void _failWaiters(Object error) {
    for (final list in _waiters.values) {
      for (final c in list) {
        c.completeError(error);
      }
    }
    _waiters.clear();
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _failWaiters(StateError('Source was closed'));
    // Ask the worker to stop between chunks so libarchive frees its memory,
    // then remove the extracted pages.
    _stopFlag.value = 1;
    await _exited;
    calloc.free(_stopFlag);
    await _deleteQuietly(_dir);
    await _onClose?.call();
  }

  /// Removes extraction directories left behind by a crash or kill.
  ///
  /// Directories are named `book_<pid>_…`; one is stale if its process is
  /// gone (checked via /proc where available) or, elsewhere, if it is older
  /// than [olderThan].
  static Future<void> cleanStaleCache({
    Duration olderThan = const Duration(days: 1),
  }) async {
    final root = cacheRoot;
    if (root == null || !await root.exists()) return;
    final hasProc = await Directory('/proc/self').exists();
    final cutoff = DateTime.now().subtract(olderThan);
    await for (final e in root.list()) {
      if (e is! Directory) continue;
      final match = RegExp(r'^book_(\d+)_').firstMatch(p.basename(e.path));
      if (match == null) continue;
      final owner = int.parse(match.group(1)!);
      if (owner == pid) continue;
      final stale = hasProc
          ? !await Directory('/proc/$owner').exists()
          : (await e.stat()).modified.isBefore(cutoff);
      if (stale) await _deleteQuietly(e);
    }
  }

  static Future<void> _deleteQuietly(Directory dir) async {
    try {
      await dir.delete(recursive: true);
    } on FileSystemException {
      // Best effort.
    }
  }
}

// -----------------------------------------------------------------------------
// Worker isolate

void _workerMain((SendPort, String, String, String, int) init) {
  final (reply, path, name, dir, flagAddress) = init;
  final stop = Pointer<Int32>.fromAddress(flagAddress);
  bool stopped() => stop.value != 0;

  final la = LibArchive.load();
  if (la == null) {
    reply.send(('failed', 'libarchive is not installed, needed for $name'));
    return;
  }

  // Pass 1: list page entries (in archive order) and read ComicInfo.xml.
  final names = <String>[];
  String? comicInfo;
  try {
    final r = ArchiveReader.open(la, path);
    try {
      while (!stopped() && r.next()) {
        final entryPath = r.path;
        if (r.isFile && entryPath != null && isPageEntry(entryPath)) {
          if (r.isEncrypted) {
            reply.send((
              'failed',
              'Password-protected archives are not '
                  'supported: $name',
            ));
            return;
          }
          names.add(entryPath);
        } else if (r.isFile &&
            entryPath != null &&
            comicInfo == null &&
            ComicInfo.isComicInfoName(entryPath)) {
          final bytes = BytesBuilder(copy: true);
          r.readData((data, n) => bytes.add(data.asTypedList(n)));
          comicInfo = utf8.decode(bytes.takeBytes(), allowMalformed: true);
          continue; // data consumed; nothing to skip
        }
        r.skip();
      }
    } finally {
      r.close();
    }
  } on LibArchiveException catch (e) {
    reply.send(('failed', 'Not a readable comic archive: $name ($e)'));
    return;
  }
  if (stopped()) return;
  if (names.isEmpty) {
    reply.send(('failed', 'No images found in $name'));
    return;
  }

  // Reading order: natural sort. sortedIndex[k] = reading position of the
  // k-th page entry in archive order (robust to duplicate names).
  final order = List.generate(names.length, (i) => i)
    ..sort((a, b) => naturalCompare(names[a], names[b]));
  final sortedIndex = List.filled(names.length, 0);
  for (var pos = 0; pos < order.length; pos++) {
    sortedIndex[order[pos]] = pos;
  }
  reply.send((
    'ready',
    fileFingerprint(path),
    [for (final i in order) names[i]],
    comicInfo,
  ));

  // Pass 2: extract pages in archive order.
  try {
    final r = ArchiveReader.open(la, path);
    try {
      var k = 0;
      while (!stopped() && r.next()) {
        final entryPath = r.path;
        if (!(r.isFile && entryPath != null && isPageEntry(entryPath))) {
          r.skip();
          continue;
        }
        final index = sortedIndex[k++];
        final out = File(p.join(dir, '$index.part'))
            .openSync(mode: FileMode.writeOnly);
        bool complete;
        try {
          complete = r.readData(
            (data, n) => out.writeFromSync(data.asTypedList(n)),
            shouldStop: stopped,
          );
        } finally {
          out.closeSync();
        }
        if (!complete) return;
        File(p.join(dir, '$index.part')).renameSync(p.join(dir, '$index'));
        reply.send(('page', index));
      }
    } finally {
      r.close();
    }
  } on Object catch (e) {
    reply.send(('failed', 'Failed to extract $name: $e'));
  }
}

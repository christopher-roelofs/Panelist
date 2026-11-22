import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../util/natural_sort.dart';
import 'fingerprint.dart';
import 'page_source.dart';

/// A CBZ (ZIP) comic.
///
/// The archive lives in a dedicated worker isolate that keeps the central
/// directory parsed and the file handle open, so pages are random-access and
/// decompression never runs on the UI isolate.
class CbzPageSource implements PageSource {
  CbzPageSource._(
    this.path,
    this.id,
    this._pageNames,
    this._isolate,
    this._commands,
    this._replies,
  );

  final String path;
  @override
  final String id;
  final List<String> _pageNames;
  final Isolate _isolate;
  final SendPort _commands;
  final ReceivePort _replies;

  final _pending = <int, Completer<Uint8List>>{};
  var _nextId = 0;
  var _closed = false;

  static Future<CbzPageSource> open(String path) async {
    final replies = ReceivePort();
    final isolate = await Isolate.spawn(_workerMain, (
      replies.sendPort,
      path,
    ), debugName: 'cbz:${p.basename(path)}');
    final ready = Completer<(SendPort, String, List<String>)>();
    CbzPageSource? source;
    replies.listen((msg) {
      switch (msg) {
        case (
          'ready',
          final SendPort port,
          final String fp,
          final List<String> names,
        ):
          ready.complete((port, fp, names));
        case ('error', final String error):
          ready.completeError(UnsupportedSourceException(error));
        case (final int id, final TransferableTypedData data):
          source?._pending
              .remove(id)
              ?.complete(data.materialize().asUint8List());
        case (final int id, final String error):
          source?._pending.remove(id)?.completeError(Exception(error));
      }
    });
    try {
      final (port, fp, names) = await ready.future;
      return source = CbzPageSource._(
        path,
        'file:$fp',
        names,
        isolate,
        port,
        replies,
      );
    } catch (_) {
      replies.close();
      isolate.kill();
      rethrow;
    }
  }

  @override
  String get title => p.basenameWithoutExtension(path);

  @override
  int get pageCount => _pageNames.length;

  /// Entry names in reading order (exposed for tests and diagnostics).
  List<String> get pageNames => List.unmodifiable(_pageNames);

  @override
  Future<Uint8List> page(int index) {
    if (_closed) return Future.error(StateError('Source is closed'));
    RangeError.checkValidIndex(index, _pageNames);
    final id = _nextId++;
    final c = _pending[id] = Completer<Uint8List>();
    _commands.send((id, index));
    return c.future;
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _commands.send(null);
    _replies.close();
    _isolate.kill(priority: Isolate.beforeNextEvent);
    for (final c in _pending.values) {
      c.completeError(StateError('Source was closed'));
    }
    _pending.clear();
  }
}

void _workerMain((SendPort, String) init) {
  final (reply, path) = init;
  final InputFileStream input;
  final List<ArchiveFile> pages;
  final String fingerprint;
  try {
    input = InputFileStream(path);
    final archive = ZipDecoder().decodeStream(input);
    pages = [
      for (final f in archive.files)
        if (f.isFile && isPageEntry(f.name)) f,
    ]..sort((a, b) => naturalCompare(a.name, b.name));
    fingerprint = fileFingerprint(path);
  } catch (e) {
    reply.send(('error', 'Not a readable CBZ/ZIP file: ${p.basename(path)}'));
    return;
  }
  if (pages.isEmpty) {
    input.closeSync();
    reply.send(('error', 'No images found in ${p.basename(path)}'));
    return;
  }

  final commands = ReceivePort();
  reply.send((
    'ready',
    commands.sendPort,
    fingerprint,
    [for (final f in pages) f.name],
  ));
  commands.listen((msg) {
    if (msg == null) {
      input.closeSync();
      commands.close();
      return;
    }
    final (id, index) = msg as (int, int);
    try {
      final out = OutputMemoryStream();
      // Writes decompressed bytes without caching them on the ArchiveFile.
      pages[index].writeContent(out);
      reply.send((id, TransferableTypedData.fromList([out.getBytes()])));
    } catch (e) {
      reply.send((id, 'Failed to read page ${index + 1}: $e'));
    }
  });
}

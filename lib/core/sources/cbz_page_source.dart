import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../imaging/image_header.dart';
import '../metadata/comic_info.dart';
import '../util/natural_sort.dart';
import 'fd_file.dart';
import 'fingerprint.dart';
import 'page_source.dart';

/// A CBZ (ZIP) comic.
///
/// The archive lives in a dedicated worker isolate that keeps the central
/// directory parsed and the file handle open, so pages are random-access and
/// decompression never runs on the UI isolate.
class CbzPageSource implements EncodedPageSource {
  CbzPageSource._(
    this.path,
    this.fileName,
    this._onClose,
    this.id,
    this._pageNames,
    this._isolate,
    this._commands,
    this._replies,
  );

  final String path;

  /// The comic's file name, for display.
  final String fileName;
  final Future<void> Function()? _onClose;
  @override
  final String id;
  final List<String> _pageNames;
  final Isolate _isolate;
  final SendPort _commands;
  final ReceivePort _replies;

  final _pending = <int, Completer<Object?>>{};
  var _nextId = 0;
  var _closed = false;

  /// [name] is the file name to show (defaults to [path]'s basename, which
  /// is meaningless for e.g. `/proc/self/fd/N`); [onClose] runs after
  /// [close] has released everything.
  static Future<CbzPageSource> open(
    String path, {
    String? name,
    Future<void> Function()? onClose,
  }) async {
    final fileName = name ?? p.basename(path);
    final replies = ReceivePort();
    final isolate = await Isolate.spawn(_workerMain, (
      replies.sendPort,
      path,
      fileName,
    ), debugName: 'cbz:$fileName');
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
        case (final int id, 'ok', final Object? result):
          source?._pending.remove(id)?.complete(result);
        case (final int id, 'err', final String error):
          source?._pending.remove(id)?.completeError(Exception(error));
      }
    });
    try {
      final (port, fp, names) = await ready.future;
      return source = CbzPageSource._(
        path,
        fileName,
        onClose,
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
  String get title => p.basenameWithoutExtension(fileName);

  @override
  int get pageCount => _pageNames.length;

  /// Entry names in reading order (exposed for tests and diagnostics).
  List<String> get pageNames => List.unmodifiable(_pageNames);

  Future<Object?> _request(String command, Object? arg) {
    if (_closed) return Future.error(StateError('Source is closed'));
    final id = _nextId++;
    final c = _pending[id] = Completer<Object?>();
    _commands.send((id, command, arg));
    return c.future;
  }

  @override
  Future<Uint8List> page(int index) async {
    RangeError.checkValidIndex(index, _pageNames);
    final data = await _request('page', index) as TransferableTypedData;
    return data.materialize().asUint8List();
  }

  @override
  Future<List<Size?>> probePageSizes() async {
    // Small batches, so page requests from the reader interleave with
    // probing instead of queueing behind the whole archive.
    const batch = 8;
    final sizes = <Size?>[];
    for (var start = 0; start < pageCount; start += batch) {
      final end = (start + batch).clamp(0, pageCount);
      final result = await _request('sizes', (start, end)) as List<Object?>;
      for (final r in result) {
        sizes.add(r is (double, double) ? Size(r.$1, r.$2) : null);
      }
    }
    return sizes;
  }

  @override
  Future<String?> readComicInfo() async =>
      await _request('comicInfo', null) as String?;

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
    await _onClose?.call();
  }
}

/// A CBZ's page images in reading order.
List<ArchiveFile> cbzPages(Archive archive) => [
  for (final f in archive.files)
    if (f.isFile && isPageEntry(f.name)) f,
]..sort((a, b) => naturalCompare(a.name, b.name));

/// The book ID of a CBZ with [pages] (see [pagesFingerprint]).
String? cbzPagesFingerprint(List<ArchiveFile> pages) =>
    pagesFingerprint([for (final f in pages) (crc32: f.crc32, size: f.size)]);

void _workerMain((SendPort, String, String) init) {
  final (reply, path, name) = init;
  final InputFileStream input;
  final List<ArchiveFile> pages;
  final ArchiveFile? comicInfo;
  final String fingerprint;
  try {
    final fd = fdOfPath(path);
    input = fd == null
        ? InputFileStream(path)
        : InputFileStream.withFileHandle(FdFileHandle(fd));
    final archive = ZipDecoder().decodeStream(input);
    pages = cbzPages(archive);
    // Prefer the shallowest ComicInfo.xml if there are several.
    int depth(ArchiveFile f) => '/'.allMatches(f.name).length;
    final infos = [
      for (final f in archive.files)
        if (f.isFile && ComicInfo.isComicInfoName(f.name)) f,
    ]..sort((a, b) => depth(a) - depth(b));
    comicInfo = infos.firstOrNull;
    // From the pages, so writing ComicInfo.xml keeps the book's identity.
    fingerprint = cbzPagesFingerprint(pages) ?? fileFingerprint(path);
  } catch (e) {
    reply.send(('error', 'Not a readable CBZ/ZIP file: $name'));
    return;
  }
  if (pages.isEmpty) {
    input.closeSync();
    reply.send(('error', 'No images found in $name'));
    return;
  }

  Uint8List read(ArchiveFile f) {
    final out = OutputMemoryStream();
    // Writes decompressed bytes without caching them on the ArchiveFile.
    f.writeContent(out);
    return out.getBytes();
  }

  List<(double, double)?> sizes(int start, int end) => [
    for (var i = start; i < end; i++)
      switch (readImageSize(read(pages[i]))) {
        final s? => (s.width, s.height),
        null => null,
      },
  ];

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
    final (id, command, arg) = msg as (int, String, Object?);
    try {
      final result = switch ((command, arg)) {
        ('page', final int i) => TransferableTypedData.fromList([
          read(pages[i]),
        ]),
        ('sizes', (final int start, final int end)) => sizes(start, end),
        ('comicInfo', _) =>
          comicInfo == null
              ? null
              : utf8.decode(read(comicInfo), allowMalformed: true),
        _ => throw ArgumentError('Bad command $command'),
      };
      reply.send((id, 'ok', result));
    } catch (e) {
      reply.send((id, 'err', '$e'));
    }
  });
}

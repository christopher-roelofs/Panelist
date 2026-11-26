import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import '../core/sources/page_source.dart';
import '../data/database.dart';
import 'share_protocol.dart';

/// Serves this computer's library to paired devices on the
/// local network (see docs/PLAN.md, M7).
///
/// Every route but `info` and `pair` needs `Authorization: Bearer <token>`
/// from pairing. Pages are served from the files themselves (opened with
/// [openSource], a few kept open for the reader's preloading).
class LibraryServer {
  LibraryServer({
    required this.db,
    required this.coversDir,
    required this.openSource,
    required this.id,
    this.publisherName,
    String? name,
    DateTime Function()? clock,
    Random? random,
  }) : name = name ?? Platform.localHostname,
       _clock = clock ?? DateTime.now,
       _random = random ?? Random.secure();

  final AppDatabase db;
  final Directory coversDir;
  final Future<PageSource> Function(String location) openSource;

  /// The publisher as the library shows it (the user's naming rules).
  final String? Function(String? publisher)? publisherName;

  /// Stays the same across restarts and address changes, so devices know
  /// it's the same library.
  final String id;

  /// Shown to devices ("Panelist on `name`").
  final String name;
  final DateTime Function() _clock;
  final Random _random;

  HttpServer? _http;

  /// The port being served on, or null when stopped.
  int? get port => _http?.port;

  // --- Pairing ---------------------------------------------------------

  static const codeLifetime = Duration(minutes: 10);
  static const maxWrongCodes = 5;

  String? _code;
  DateTime? _codeExpires;
  int _wrongCodes = 0;

  /// A new 6-digit pairing code, valid for [codeLifetime] (replacing any
  /// earlier one).
  String newPairingCode() {
    _code = List.generate(6, (_) => _random.nextInt(10)).join();
    _codeExpires = _clock().add(codeLifetime);
    _wrongCodes = 0;
    return _code!;
  }

  /// The current code, if it's still valid.
  String? get pairingCode =>
      _code != null && _clock().isBefore(_codeExpires!) ? _code : null;

  void cancelPairing() => _code = null;

  /// Called after a device pairs (for the settings screen to refresh).
  void Function(String deviceName)? onPaired;

  // --- Serving ---------------------------------------------------------

  /// Starts serving on [port] (the next free one if it's taken).
  Future<int> start({int port = defaultSharePort}) async {
    if (_http != null) return _http!.port;
    final handler = const Pipeline()
        .addMiddleware(_auth)
        .addHandler(router.call);
    for (var p = port; p < port + 20; p++) {
      try {
        _http = await shelf_io.serve(handler, InternetAddress.anyIPv4, p);
        _http!.autoCompress = true;
        return _http!.port;
      } on SocketException {
        // Taken: try the next one.
      }
    }
    throw const SocketException('No free port to share the library on');
  }

  Future<void> stop() async {
    await _http?.close(force: true);
    _http = null;
    for (final s in _open.values) {
      await s.close();
    }
    _open.clear();
  }

  /// All routes (also used directly by tests).
  late final Router router = Router()
    ..get('$apiPath/info', _info)
    ..post('$apiPath/pair', _pair)
    ..get('$apiPath/library', _library)
    ..get('$apiPath/books/<id>/cover', _cover)
    ..get('$apiPath/books/<id>/file', _file)
    ..get('$apiPath/books/<id>/pages', _pages)
    ..get('$apiPath/books/<id>/pages/<n|[0-9]+>', _page)
    ..post('$apiPath/progress', _progress);

  /// The test-friendly whole: auth plus routes.
  Handler get handler =>
      const Pipeline().addMiddleware(_auth).addHandler(router.call);

  static String hashToken(String token) =>
      sha256.convert(utf8.encode(token)).toString();

  Handler _auth(Handler inner) => (request) async {
    final path = '/${request.url.path}';
    if (path == '$apiPath/info' || path == '$apiPath/pair') {
      return inner(request);
    }
    final header = request.headers['authorization'] ?? '';
    final token = header.startsWith('Bearer ') ? header.substring(7) : null;
    final device = token == null
        ? null
        : await db.pairedDevice(hashToken(token));
    if (device == null) {
      return _json({'error': 'Not paired'}, status: 401);
    }
    unawaited(db.devicePresent(device.id, _clock()));
    return inner(request);
  };

  Response _json(
    Object body, {
    int status = 200,
    Map<String, String>? headers,
  }) => Response(
    status,
    body: jsonEncode(body),
    headers: {'content-type': 'application/json', ...?headers},
  );

  Response _info(Request _) =>
      _json({'id': id, 'name': name, 'app': 'panelist', 'api': apiVersion});

  Future<Response> _pair(Request request) async {
    final Map<String, Object?> body;
    try {
      body = jsonDecode(await request.readAsString()) as Map<String, Object?>;
    } on Object {
      return _json({'error': 'Bad request'}, status: 400);
    }
    final code = pairingCode;
    if (code == null) {
      return _json({
        'error': 'No pairing code is open on the computer',
      }, status: 403);
    }
    if (body['code'] != code) {
      if (++_wrongCodes >= maxWrongCodes) cancelPairing();
      return _json({'error': 'Wrong code'}, status: 403);
    }
    cancelPairing();
    final token = base64Url
        .encode(List.generate(32, (_) => _random.nextInt(256)))
        .replaceAll('=', '');
    final device = '${body['device'] ?? 'Device'}'.trim();
    await db.addPairedDevice(
      name: device.isEmpty ? 'Device' : device,
      tokenHash: hashToken(token),
      added: _clock(),
    );
    onPaired?.call(device);
    return _json({'token': token, 'id': id, 'name': name});
  }

  Future<Response> _library(Request request) async {
    final entries = [
      for (final e in await db.select(db.libraryEntries).get())
        if (e.bookId != null) e,
    ];
    final body = jsonEncode({
      'comics': [
        for (final e in entries)
          RemoteComic.fromEntry(
            e,
            publisher: publisherName?.call(e.publisher),
          ).toJson(),
      ],
    });
    final etag = '"${sha1.convert(utf8.encode(body))}"';
    if (request.headers['if-none-match'] == etag) {
      return Response.notModified(headers: {'etag': etag});
    }
    return Response.ok(
      body,
      headers: {'content-type': 'application/json', 'etag': etag},
    );
  }

  Future<LibraryEntry?> _entry(String id) async =>
      (await (db.select(db.libraryEntries)
                ..where((e) => e.bookId.equals(id))
                ..limit(1))
              .get())
          .firstOrNull;

  Future<Response> _cover(Request request, String id) async {
    final f = File(p.join(coversDir.path, '$id.png'));
    if (!p.isWithin(coversDir.path, f.path) || !f.existsSync()) {
      return Response.notFound('No cover');
    }
    return Response.ok(
      f.openRead(),
      headers: {
        'content-type': 'image/png',
        'content-length': '${f.lengthSync()}',
        'cache-control': 'max-age=86400',
      },
    );
  }

  /// The whole file, resumable (`Range: bytes=N-`).
  Future<Response> _file(Request request, String id) async {
    final e = await _entry(id);
    final file = e == null ? null : File(e.location);
    if (file == null || !file.existsSync()) return Response.notFound('Gone');
    final length = file.lengthSync();
    final name = e!.fileName;
    final headers = {
      'content-type': 'application/octet-stream',
      'accept-ranges': 'bytes',
      'content-disposition':
          "attachment; filename*=UTF-8''${Uri.encodeComponent(name)}",
    };
    final range = RegExp(r'^bytes=(\d+)-(\d*)$')
        .firstMatch(request.headers['range'] ?? '');
    if (range != null) {
      final start = int.parse(range[1]!);
      final end = range[2]!.isEmpty ? length - 1 : int.parse(range[2]!);
      if (start >= length || end < start) {
        return Response(416, headers: {'content-range': 'bytes */$length'});
      }
      final last = min(end, length - 1);
      return Response(
        206,
        body: file.openRead(start, last + 1),
        headers: {
          ...headers,
          'content-range': 'bytes $start-$last/$length',
          'content-length': '${last - start + 1}',
        },
      );
    }
    return Response.ok(
      file.openRead(),
      headers: {...headers, 'content-length': '$length'},
    );
  }

  // A few sources stay open, so page after page doesn't reopen the file.
  final _open = <String, PageSource>{};
  static const _keepOpen = 4;

  Future<PageSource?> _source(String id) async {
    if (_open.remove(id) case final s?) return _open[id] = s;
    final e = await _entry(id);
    if (e == null) return null;
    final s = await openSource(e.location);
    _open[id] = s;
    while (_open.length > _keepOpen) {
      final oldest = _open.keys.first;
      unawaited(_open.remove(oldest)!.close());
    }
    return s;
  }

  Future<Response> _pages(Request request, String id) async {
    final s = await _source(id);
    if (s == null) return Response.notFound('Gone');
    final sizes = await s.probePageSizes();
    return _json({
      'count': s.pageCount,
      'rendered': s is RenderedPageSource,
      'sizes': [
        for (final z in sizes)
          z == null ? null : [z.width.round(), z.height.round()],
      ],
    });
  }

  /// One page's image. Pages drawn on demand (PDF) are rendered at
  /// `?width=` (default 1600) and sent as PNG.
  Future<Response> _page(Request request, String id, String n) async {
    final s = await _source(id);
    final index = int.parse(n);
    if (s == null || index >= s.pageCount) return Response.notFound('No page');
    final Uint8List bytes;
    switch (s) {
      case final EncodedPageSource s:
        bytes = await s.page(index);
      case final RenderedPageSource s:
        final size = s.pageSize(index);
        final width =
            (int.tryParse(request.url.queryParameters['width'] ?? '') ?? 1600)
                .clamp(200, 4000);
        final height = (width * size.height / size.width).round();
        final image = await s.render(index, width, height);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        bytes = png!.buffer.asUint8List();
    }
    return Response.ok(
      bytes,
      headers: {
        'content-type': imageType(bytes),
        'content-length': '${bytes.length}',
        'cache-control': 'max-age=86400',
      },
    );
  }

  /// Takes a device's progress changes (each applied if newer than what's
  /// here) and answers with every change since the device's last sync.
  Future<Response> _progress(Request request) async {
    final ProgressSync sync;
    try {
      sync = ProgressSync.fromJson(
        jsonDecode(await request.readAsString()) as Map<String, Object?>,
      );
    } on Object {
      return _json({'error': 'Bad request'}, status: 400);
    }
    final now = _clock();
    // Device times shifted onto this clock (the device says what its clock
    // read when it sent this).
    final skew = sync.now == null ? Duration.zero : now.difference(sync.now!);
    for (final c in sync.changes) {
      final e = await _entry(c.id);
      // Only books this computer has (not the device's own comics).
      if (e == null && await db.book(c.id) == null) continue;
      await db.applyProgress(
        c.shifted(skew),
        path: e?.location ?? '',
        title: e == null ? c.id : p.basenameWithoutExtension(e.fileName),
      );
    }
    return _json(
      ProgressSync(
        since: now,
        now: now,
        changes: await db.progressChangedSince(sync.since),
      ).toJson(),
    );
  }
}

/// `Content-Type` from an image's first bytes.
String imageType(Uint8List b) {
  bool starts(List<int> sig) =>
      b.length >= sig.length &&
      Iterable<int>.generate(sig.length).every((i) => b[i] == sig[i]);
  if (starts([0xFF, 0xD8, 0xFF])) return 'image/jpeg';
  if (starts([0x89, 0x50, 0x4E, 0x47])) return 'image/png';
  if (starts([0x47, 0x49, 0x46])) return 'image/gif';
  if (starts([0x42, 0x4D])) return 'image/bmp';
  if (b.length >= 12 &&
      String.fromCharCodes(b.sublist(0, 4)) == 'RIFF' &&
      String.fromCharCodes(b.sublist(8, 12)) == 'WEBP') {
    return 'image/webp';
  }
  return 'application/octet-stream';
}

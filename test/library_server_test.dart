import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panelist/core/sources/open_source.dart';
import 'package:panelist/data/database.dart';
import 'package:panelist/share/library_server.dart';
import 'package:panelist/share/share_protocol.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';

import 'support.dart';

void main() {
  late Directory dir;
  late AppDatabase db;
  late LibraryServer server;
  var now = DateTime.utc(2026, 11, 25, 12);

  Future<Response> call(
    String method,
    String path, {
    String? token,
    Object? body,
    Map<String, String>? headers,
  }) async => server.handler(
    Request(
      method,
      Uri.parse('http://pc$apiPath/$path'),
      body: body == null ? null : jsonEncode(body),
      headers: {
        'authorization': ?token == null ? null : 'Bearer $token',
        ...?headers,
      },
    ),
  );

  Future<Map<String, Object?>> json(Response r) async =>
      jsonDecode(await r.readAsString()) as Map<String, Object?>;

  Future<String> pair() async {
    final code = server.newPairingCode();
    final r = await call(
      'POST',
      'pair',
      body: {'code': code, 'device': 'Tablet'},
    );
    expect(r.statusCode, 200);
    return (await json(r))['token']! as String;
  }

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('panelist_server');
    final covers = Directory(p.join(dir.path, 'covers'))..createSync();
    db = AppDatabase(NativeDatabase.memory());
    final cbz = p.join(dir.path, 'Saga 001 (2012).cbz');
    File(cbz).writeAsBytesSync(
      ZipEncoder().encodeBytes(
        Archive()
          ..add(ArchiveFile.bytes('01.png', pngHeader(800, 1200)))
          ..add(ArchiveFile.bytes('02.png', pngHeader(1600, 1200))),
      ),
    );
    await db.addRoot(dir.path, 'Comics');
    final root = (await db.roots()).single;
    await db.putEntry(
      LibraryEntriesCompanion.insert(
        location: cbz,
        rootId: root.id,
        folder: 'Image Comics',
        fileName: 'Saga 001 (2012).cbz',
        size: File(cbz).lengthSync(),
        modified: 0,
        bookId: const Value('saga1'),
        pageCount: const Value(2),
        series: const Value('Saga'),
        number: const Value('1'),
      ),
    );
    File(p.join(covers.path, 'saga1.png')).writeAsBytesSync(pngHeader(10, 15));
    server = LibraryServer(
      db: db,
      coversDir: covers,
      openSource: openSource,
      name: 'Desktop',
      clock: () => now,
      random: Random(1),
    );
  });

  tearDown(() async {
    await server.stop();
    await db.close();
    dir.deleteSync(recursive: true);
  });

  test('info answers anyone; everything else needs pairing', () async {
    expect((await json(await call('GET', 'info')))['name'], 'Desktop');
    expect((await call('GET', 'library')).statusCode, 401);
    expect((await call('GET', 'library', token: 'nope')).statusCode, 401);
  });

  test('pairing needs the code shown, once, before it expires', () async {
    expect(
      (await call('POST', 'pair', body: {'code': '123456'})).statusCode,
      403,
    );
    final code = server.newPairingCode();
    expect((await call('POST', 'pair', body: {'code': 'x'})).statusCode, 403);
    final r = await call(
      'POST',
      'pair',
      body: {'code': code, 'device': 'Pixel'},
    );
    expect(r.statusCode, 200);
    final token = (await json(r))['token']! as String;
    expect((await call('GET', 'library', token: token)).statusCode, 200);
    // Used up.
    expect((await call('POST', 'pair', body: {'code': code})).statusCode, 403);
    // The token itself isn't stored.
    final device = (await db.select(db.pairedDevices).get()).single;
    expect(device.name, 'Pixel');
    expect(device.tokenHash, isNot(token));

    final late = server.newPairingCode();
    now = now.add(const Duration(minutes: 11));
    expect((await call('POST', 'pair', body: {'code': late})).statusCode, 403);
  });

  test('too many wrong codes close pairing', () async {
    final code = server.newPairingCode();
    for (var i = 0; i < LibraryServer.maxWrongCodes; i++) {
      await call('POST', 'pair', body: {'code': 'wrong'});
    }
    expect((await call('POST', 'pair', body: {'code': code})).statusCode, 403);
  });

  test('a removed device is locked out', () async {
    final token = await pair();
    await db.removePairedDevice(
      (await db.select(db.pairedDevices).get()).single.id,
    );
    expect((await call('GET', 'library', token: token)).statusCode, 401);
  });

  test('library lists comics, with an ETag', () async {
    final token = await pair();
    final r = await call('GET', 'library', token: token);
    final comics = (await json(r))['comics']! as List;
    final saga = RemoteComic.fromJson(comics.single as Map<String, Object?>);
    expect(saga.id, 'saga1');
    expect(saga.folder, 'Image Comics');
    expect(saga.series, 'Saga');
    final again = await call(
      'GET',
      'library',
      token: token,
      headers: {'if-none-match': r.headers['etag']!},
    );
    expect(again.statusCode, 304);
  });

  test('cover, pages and page images', () async {
    final token = await pair();
    final cover = await call('GET', 'books/saga1/cover', token: token);
    expect(cover.headers['content-type'], 'image/png');
    expect(
      (await call('GET', 'books/nope/cover', token: token)).statusCode,
      404,
    );
    expect(
      (await call('GET', 'books/..%2F..%2Fx/cover', token: token)).statusCode,
      404,
    );

    final pages = await json(
      await call('GET', 'books/saga1/pages', token: token),
    );
    expect(pages['count'], 2);
    expect(pages['sizes'], [
      [800, 1200],
      [1600, 1200],
    ]);
    final page = await call('GET', 'books/saga1/pages/1', token: token);
    expect(page.headers['content-type'], 'image/png');
    final bytes = await page.read().expand((b) => b).toList();
    expect(Uint8List.fromList(bytes), pngHeader(1600, 1200));
    expect(
      (await call('GET', 'books/saga1/pages/5', token: token)).statusCode,
      404,
    );
  });

  test('file download resumes with Range', () async {
    final token = await pair();
    final whole = await call('GET', 'books/saga1/file', token: token);
    final all = await whole.read().expand((b) => b).toList();
    expect(all.length, int.parse(whole.headers['content-length']!));
    final part = await call(
      'GET',
      'books/saga1/file',
      token: token,
      headers: {'range': 'bytes=10-'},
    );
    expect(part.statusCode, 206);
    expect(await part.read().expand((b) => b).toList(), all.sublist(10));
  });

  test('progress: newer wins both ways, device clock corrected', () async {
    final token = await pair();
    // Read on the PC at 12:00.
    await db.recordOpened(id: 'saga1', path: 'x', title: 'Saga', pageCount: 2);
    await db.saveProgress('saga1', 0);
    final pcTime = (await db.book('saga1'))!.progressUpdated!;

    // First sync: the device has nothing; gets the PC's position.
    var r = ProgressSync.fromJson(
      await json(
        await call(
          'POST',
          'progress',
          token: token,
          body: const ProgressSync().toJson(),
        ),
      ),
    );
    expect(r.changes.map((c) => c.id), ['saga1']);
    expect(r.since, now);

    // The device's clock is 5 minutes slow; it read page 1 "a minute after"
    // the PC by its own clock, which is really later still.
    final deviceNow = pcTime.toUtc().add(const Duration(minutes: 1));
    now = deviceNow.add(const Duration(minutes: 5));
    r = ProgressSync.fromJson(
      await json(
        await call(
          'POST',
          'progress',
          token: token,
          body: ProgressSync(
            since: r.since,
            now: deviceNow,
            changes: [
              ProgressChange(
                id: 'saga1',
                page: 1,
                pageCount: 2,
                finished: true,
                updated: deviceNow,
              ),
              // A book never opened on the PC.
              ProgressChange(
                id: 'other',
                page: 3,
                pageCount: 20,
                finished: false,
                updated: deviceNow,
              ),
            ],
          ).toJson(),
        ),
      ),
    );
    final saga = (await db.book('saga1'))!;
    expect(saga.currentPage, 1);
    expect(saga.finished, isTrue);
    expect(saga.progressUpdated!.toUtc(), now);
    final other = (await db.book('other'))!;
    expect(other.currentPage, 3);
    expect(other.lastOpened.toUtc(), now, reason: 'shows in Continue reading');

    // An older change from the device loses.
    await call(
      'POST',
      'progress',
      token: token,
      body: ProgressSync(
        since: r.since,
        now: now,
        changes: [
          ProgressChange(
            id: 'saga1',
            page: 0,
            pageCount: 2,
            finished: false,
            updated: now.subtract(const Duration(hours: 1)),
          ),
        ],
      ).toJson(),
    );
    expect((await db.book('saga1'))!.currentPage, 1);
  });

  test('serves over HTTP on a free port', () async {
    final port = await server.start(port: 0);
    final client = HttpClient();
    addTearDown(client.close);
    final req = await client.get('127.0.0.1', port, '$apiPath/info');
    final res = await req.close();
    expect(res.statusCode, 200);
    expect(
      jsonDecode(await res.transform(utf8.decoder).join()),
      containsPair('app', 'panelist'),
    );
  });
}

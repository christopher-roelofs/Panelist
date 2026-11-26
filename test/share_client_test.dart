import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panelist/app/providers.dart';
import 'package:panelist/core/sources/open_source.dart';
import 'package:panelist/data/database.dart';
import 'package:panelist/library/library_scanner.dart';
import 'package:panelist/share/library_server.dart';
import 'package:panelist/share/remote_library.dart';
import 'package:panelist/share/remote_page_source.dart';
import 'package:panelist/share/remote_widgets.dart';
import 'package:panelist/share/share_client.dart';
import 'package:panelist/share/share_protocol.dart';
import 'package:path/path.dart' as p;

import 'support.dart';

void main() {
  // A computer's database and a device's, on purpose.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory dir;
  late AppDatabase pc;
  late AppDatabase device;
  late LibraryServer server;
  late String address;
  late String cbz;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('panelist_share');
    pc = AppDatabase(NativeDatabase.memory());
    device = AppDatabase(NativeDatabase.memory());
    cbz = p.join(dir.path, 'Saga 001 (2012).cbz');
    File(cbz).writeAsBytesSync(
      ZipEncoder().encodeBytes(
        Archive()
          ..add(ArchiveFile.bytes('01.png', pngHeader(800, 1200)))
          ..add(ArchiveFile.bytes('02.png', pngHeader(800, 1200)))
          ..add(ArchiveFile.bytes('03.png', pngHeader(800, 1200))),
      ),
    );
    final id = (await openSource(cbz)).id;
    await pc.addRoot(dir.path, 'Comics');
    await pc.putEntry(
      LibraryEntriesCompanion.insert(
        location: cbz,
        rootId: (await pc.roots()).single.id,
        folder: 'Saga',
        fileName: p.basename(cbz),
        size: File(cbz).lengthSync(),
        modified: 0,
        bookId: Value(id),
        pageCount: const Value(3),
      ),
    );
    server = LibraryServer(
      id: 'pc-library',
      db: pc,
      coversDir: Directory(p.join(dir.path, 'covers'))..createSync(),
      openSource: openSource,
      name: 'Desktop',
    );
    address = '127.0.0.1:${await server.start(port: 0)}';
  });

  tearDown(() async {
    await server.stop();
    await pc.close();
    await device.close();
    dir.deleteSync(recursive: true);
  });

  Future<(RemoteLibrary, ShareClient)> pairDevice() async {
    final r = await ShareClient(address).pair(server.newPairingCode(), 'Tab');
    expect(r.id, 'pc-library');
    final rowId = await device.saveRemoteLibrary(
      serverId: r.id,
      name: r.name,
      address: address,
      token: r.token,
    );
    final lib = (await device.remoteLibraryList()).singleWhere(
      (l) => l.id == rowId,
    );
    return (lib, ShareClient(address, token: r.token));
  }

  test('pair, list, read pages, download: same book ID', () async {
    final info = await ShareClient(address).info();
    expect(info, (id: 'pc-library', name: 'Desktop'));
    await expectLater(
      ShareClient(address).library(),
      throwsA(
        isA<ShareException>().having((e) => e.unpaired, 'unpaired', true),
      ),
    );
    await expectLater(
      ShareClient(address).pair('000000', 'x'),
      throwsA(isA<ShareException>()),
    );

    final (_, client) = await pairDevice();
    final list = (await client.library())!;
    final comic = list.comics.single;
    expect(comic.folder, 'Saga');
    expect(await client.library(etag: list.etag), isNull);

    final source = await RemotePageSource.open(
      client,
      comic.id,
      fileName: comic.fileName,
    );
    expect(source.pageCount, 3);
    expect(source.title, 'Saga 001 (2012)');
    expect(await source.page(2), pngHeader(800, 1200));

    final to = File(p.join(dir.path, 'device', comic.id, comic.fileName));
    var last = 0;
    await client.download(comic.id, to, onProgress: (d, _) => last = d);
    expect(to.readAsBytesSync(), File(cbz).readAsBytesSync());
    expect(last, File(cbz).lengthSync());
    expect((await openSource(to.path)).id, comic.id);
    client.close();
  });

  test('closing a client lets a request in progress finish', () async {
    final (_, client) = await pairDevice();
    final pending = client.library();
    client.close();
    expect((await pending)!.comics, hasLength(1));
  });

  test('a paired library loads on a fresh start', () async {
    final (lib, client) = await pairDevice();
    client.close();
    final dirs = Directory(p.join(dir.path, 'device-data'));
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(device),
        coversDirProvider.overrideWithValue(
          Directory(p.join(dirs.path, 'covers')),
        ),
        shareDirsProvider.overrideWithValue((
          cache: Directory(p.join(dirs.path, 'cache')),
          downloads: Directory(p.join(dirs.path, 'downloads')),
        )),
        shownLibraryProvider.overrideWith(() => ShownLibrary(lib.id)),
      ],
    );
    addTearDown(container.dispose);
    // What the library screen watches, straight away.
    final sub = container.listen(shownComicsProvider, (_, _) {});
    addTearDown(sub.close);
    final state = container.listen(remoteComicsProvider(lib.id), (_, _) {});
    addTearDown(state.close);
    for (var i = 0; i < 50 && state.read().loading; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    expect(state.read().loading, isFalse);
    expect(state.read().error, isNull);
    expect(sub.read(), hasLength(1));
    // A book synced before the list came is named once it does.
    final id = sub.read().single.entry.bookId!;
    await device.applyProgress(
      ProgressChange(
        id: id,
        page: 1,
        pageCount: 3,
        finished: false,
        updated: DateTime.now(),
      ),
      path: remoteLocation(lib.id, id),
      title: id,
    );
    await container.read(remoteComicsProvider(lib.id).notifier).refresh();
    expect((await device.book(id))!.title, 'Saga 001 (2012)');
  });

  test('download all: the queue downloads each comic in turn', () async {
    final (lib, client) = await pairDevice();
    final comics = (await client.library())!.comics;
    client.close();
    final dirs = Directory(p.join(dir.path, 'device-data'));
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(device),
        coversDirProvider.overrideWithValue(
          Directory(p.join(dirs.path, 'covers')),
        ),
        shareDirsProvider.overrideWithValue((
          cache: Directory(p.join(dirs.path, 'cache')),
          downloads: Directory(p.join(dirs.path, 'downloads')),
        )),
      ],
    );
    addTearDown(container.dispose);
    final keep = container.listen(downloadQueueProvider, (_, _) {});
    addTearDown(keep.close);
    // As the app's remote access does.
    final libs = container.listen(remoteLibrariesProvider, (_, _) {});
    addTearDown(libs.close);
    final done = Completer<String>();
    container
        .read(downloadQueueProvider.notifier)
        .add(lib.id, comics, onDone: done.complete);
    expect(await done.future, 'Downloaded 1 comic');
    expect(container.read(downloadQueueProvider), isNull);
    final file = container.read(downloadsProvider)[comics.single.id]!;
    expect(file.readAsBytesSync(), File(cbz).readAsBytesSync());
  });

  test('downloads go into the library folder, in the same folders', () async {
    final (lib, client) = await pairDevice();
    final comic = (await client.library())!.comics.single;
    client.close();
    final library = Directory(p.join(dir.path, 'my-comics'))..createSync();
    await device.addRoot(library.path, 'My comics');
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(device),
        coversDirProvider.overrideWithValue(
          Directory(p.join(dir.path, 'covers3')),
        ),
        shareDirsProvider.overrideWithValue((
          cache: Directory(p.join(dir.path, 'cache3')),
          downloads: Directory(p.join(dir.path, 'downloads3')),
        )),
      ],
    );
    addTearDown(container.dispose);
    final libs = container.listen(remoteLibrariesProvider, (_, _) {});
    addTearDown(libs.close);
    final keep = container.listen(downloadsProvider, (_, _) {});
    addTearDown(keep.close);
    final file = await container
        .read(downloadsProvider.notifier)
        .download(lib.id, comic);
    expect(
      file.path,
      p.joinAll([
        library.path,
        ...comic.folder.split('/').where((f) => f.isNotEmpty),
        comic.fileName,
      ]),
    );
    expect(file.readAsBytesSync(), File(cbz).readAsBytesSync());
    expect(
      container.read(downloadsProvider.notifier).removable(comic.id),
      isFalse,
    );
    // Another file by that name already there: left alone.
    await expectLater(
      container.read(downloadsProvider.notifier).download(lib.id, comic),
      throwsA(isA<ShareException>()),
    );
    expect(file.readAsBytesSync(), File(cbz).readAsBytesSync());
    // The download started a scan, which adds it to this device's library.
    final scan = container.listen(libraryScanProvider, (_, _) {});
    addTearDown(scan.close);
    await container.read(libraryScanProvider.notifier).scan();
    expect(
      (await device.entriesOf((await device.roots()).single.id))
          .single
          .location,
      file.path,
    );
  });

  test('download all: a file this device can’t write is reported', () async {
    final (lib, client) = await pairDevice();
    final comics = (await client.library())!.comics;
    client.close();
    // A file where the downloads folder should be: nothing can go in it.
    final blocked = File(p.join(dir.path, 'blocked'))..writeAsStringSync('x');
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(device),
        coversDirProvider.overrideWithValue(
          Directory(p.join(dir.path, 'covers2')),
        ),
        shareDirsProvider.overrideWithValue((
          cache: Directory(p.join(dir.path, 'cache2')),
          downloads: Directory(blocked.path),
        )),
      ],
    );
    addTearDown(container.dispose);
    final keep = container.listen(downloadQueueProvider, (_, _) {});
    addTearDown(keep.close);
    final libs = container.listen(remoteLibrariesProvider, (_, _) {});
    addTearDown(libs.close);
    final done = Completer<String>();
    container
        .read(downloadQueueProvider.notifier)
        .add(lib.id, comics, onDone: done.complete);
    expect(await done.future, startsWith('Downloaded 0 comics · 1 failed: '));
  });

  test('a download picks up where it stopped', () async {
    final (_, client) = await pairDevice();
    final comic = (await client.library())!.comics.single;
    final to = File(p.join(dir.path, 'device', 'x.cbz'));
    final bytes = File(cbz).readAsBytesSync();
    File('${to.path}.part')
      ..createSync(recursive: true)
      ..writeAsBytesSync(Uint8List.sublistView(bytes, 0, 100));
    int? first;
    await client.download(comic.id, to, onProgress: (d, _) => first ??= d);
    expect(first, greaterThan(100), reason: 'resumed, not from the start');
    expect(to.readAsBytesSync(), bytes);
    client.close();
  });

  test('progress syncs both ways; the latest wins', () async {
    final (lib, client) = await pairDevice();
    final id = (await client.library())!.comics.single.id;

    // Read on the PC.
    await pc.recordOpened(id: id, path: cbz, title: 'Saga', pageCount: 3);
    await pc.saveProgress(id, 1);
    await syncProgress(device, lib, client, titleFor: (_) => 'Saga 001');
    var mine = (await device.book(id))!;
    expect(mine.currentPage, 1);
    expect(mine.path, remoteLocation(lib.id, id));

    // Then on the device, a little later.
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    await device.saveProgress(id, 2);
    final again = (await device.remoteLibraryList()).single;
    await syncProgress(device, again, client, titleFor: (_) => 'Saga 001');
    final theirs = (await pc.book(id))!;
    expect(theirs.currentPage, 2);
    expect(theirs.finished, isTrue);

    // Nothing new: nothing changes.
    mine = (await device.book(id))!;
    await syncProgress(
      device,
      (await device.remoteLibraryList()).single,
      client,
      titleFor: (_) => '',
    );
    expect((await device.book(id))!.currentPage, mine.currentPage);
    client.close();
  });
}

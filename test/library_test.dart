import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panelist/app/providers.dart';
import 'package:panelist/core/metadata/comic_info.dart';
import 'package:panelist/data/database.dart';
import 'package:panelist/library/library_model.dart';
import 'package:panelist/library/library_scanner.dart';
import 'package:path/path.dart' as p;

LibraryEntry entry(
  String folder,
  String file, {
  int root = 1,
  String? series,
  String? number,
  String? publisher,
  String? bookId,
}) => LibraryEntry(
  location: '/lib/$folder/$file',
  rootId: root,
  folder: folder,
  fileName: file,
  size: 1,
  modified: 0,
  bookId: bookId,
  series: series,
  number: number,
  publisher: publisher,
);

void main() {
  group('model', () {
    final comics = [
      // The tablet's layout: Series/issue, and Publisher/Series/issue.
      for (final n in [2, 1, 10])
        LibraryComic(
          entry(
            'Locke & Key - Welcome to Lovecraft (2008)',
            'Locke & Key - Welcome to Lovecraft #00$n (2008).cbz',
            series: 'Locke & Key: Welcome to Lovecraft',
            number: '$n',
            publisher: 'IDW',
            bookId: 'lk$n',
          ),
          n == 1 ? (currentPage: 35, pageCount: 36, finished: true) : null,
        ),
      LibraryComic(
        entry(
          'HexComix/Hex11 - The Magic Age Rises (2016)',
          'Hex11 - The Magic Age Rises #001 (2016).cbz',
          series: 'Hex11: The Magic Age Rises',
          number: '1',
          publisher: 'HexComix',
        ),
        null,
      ),
      LibraryComic(
        entry(
          'Eight Billion Genies (2022)',
          'Eight Billion Genies #001.cbz',
          publisher: 'Image Comics',
          series: 'Eight Billion Genies',
        ),
        null,
      ),
      LibraryComic(
        entry(
          "Jupiter's Legacy - Requiem (2021)",
          'JLR #001.cbz',
          publisher: 'Image',
          series: "Jupiter's Legacy: Requiem",
        ),
        null,
      ),
      // No ComicInfo.
      LibraryComic(entry('', 'Atomic_War_001.cbr'), (
        currentPage: 3,
        pageCount: 36,
        finished: false,
      )),
      LibraryComic(entry('Untagged Series (1999)', 'Issue 03.cbz'), null),
    ];

    test('falls back to folder, then file name', () {
      final atomic = comics.firstWhere(
        (c) => c.entry.fileName.startsWith('Atomic'),
      );
      expect(atomic.series, 'Atomic War');
      expect(atomic.number, '1');
      expect(atomic.seriesWithSource.$2, FieldSource.fileName);
      expect(atomic.readState, ReadState.reading);

      final untagged = comics.last;
      expect(untagged.seriesWithSource, (
        'Untagged Series',
        FieldSource.folder,
      ));
      expect(untagged.number, '3');
      expect(untagged.yearWithSource, (1999, FieldSource.folder));
    });

    test('a folder that isn’t the series doesn’t name it', () {
      LibraryComic at(String folder, String file) =>
          LibraryComic(entry(folder, file), null);
      final pack = at(
        '2026.11.18 DC Week',
        'Batwoman 009 (2026) (digital) (Subrosa-DCP).cbz',
      );
      expect(pack.seriesWithSource, ('Batwoman', FieldSource.fileName));
      expect(pack.nameGuess.series, 'Batwoman');
      expect(at('Image', 'Saga 054 (2018).cbr').series, 'Saga');
      // Same series, folder's fuller name wins.
      expect(
        at(
          'Locke & Key - Welcome to Lovecraft (2008)',
          'Locke & Key 001.cbz',
        ).seriesWithSource,
        ('Locke & Key - Welcome to Lovecraft', FieldSource.folder),
      );
      expect(at('Saga', 'saga_001.cbz').series, 'Saga');
      expect(
        at('Batman', 'Batman - Superman 001.cbz').series,
        'Batman - Superman',
      );
      expect(at('Saga', '001.cbz').series, 'Saga');
      expect(at('Saga', 'Chapter 01.cbz').series, 'Saga');
    });

    test('series are grouped exactly as written, issues in number order', () {
      final series = groupBySeries(comics);
      expect(series.map((s) => s.name), [
        'Atomic War',
        'Eight Billion Genies',
        'Hex11: The Magic Age Rises',
        "Jupiter's Legacy: Requiem",
        'Locke & Key: Welcome to Lovecraft',
        'Untagged Series',
      ]);
      final lk = series.firstWhere((s) => s.name.startsWith('Locke'));
      expect(lk.comics.map((c) => c.number), ['1', '2', '10']);
      expect(lk.readCount, 1);
    });

    test('publishers are not merged; unknown comes last', () {
      final pubs = groupByPublisher(comics);
      expect(pubs.map((g) => g.name), [
        'HexComix',
        'IDW',
        'Image',
        'Image Comics',
        null,
      ]);
      expect(pubs.last.series.map((s) => s.name), [
        'Atomic War',
        'Untagged Series',
      ]);
      expect(pubs[1].first.number, '1');
    });

    test('search matches every word, in series then issue order', () {
      String names(String q) => searchComics(
        comics,
        q,
      ).map((c) => '${c.series} ${c.number}').join(', ');
      expect(
        names('locke'),
        'Locke & Key: Welcome to Lovecraft 1, '
        'Locke & Key: Welcome to Lovecraft 2, '
        'Locke & Key: Welcome to Lovecraft 10',
      );
      expect(names('LOCKE #10'), 'Locke & Key: Welcome to Lovecraft 10');
      expect(names('image'), contains('Eight Billion Genies'));
      expect(names('atomic war'), 'Atomic War 1');
      expect(names('  '), '');
      expect(names('nothing like this'), '');
    });

    test('next in series', () {
      String? next(String bookId) {
        final c = nextInSeries(comics, bookId);
        return c == null ? null : '${c.series} ${c.number}';
      }

      expect(next('lk1'), 'Locke & Key: Welcome to Lovecraft 2');
      expect(next('lk2'), 'Locke & Key: Welcome to Lovecraft 10');
      expect(next('lk10'), isNull); // last issue
      expect(next('not-in-library'), isNull);
    });

    test('folder contents', () {
      final (top, files) = folderContents(comics, 1, '');
      expect(top.map((f) => f.name), [
        'Eight Billion Genies (2022)',
        'HexComix',
        "Jupiter's Legacy - Requiem (2021)",
        'Locke & Key - Welcome to Lovecraft (2008)',
        'Untagged Series (1999)',
      ]);
      expect(files.map((c) => c.entry.fileName), ['Atomic_War_001.cbr']);
      final lk = top.firstWhere((f) => f.name.startsWith('Locke'));
      expect(lk.first.number, '1');

      final (inHex, hexFiles) = folderContents(comics, 1, 'HexComix');
      expect(inHex.single.name, 'Hex11 - The Magic Age Rises (2016)');
      expect(inHex.single.comics, hasLength(1));
      expect(hexFiles, isEmpty);
      expect(folderContents(comics, 2, '').$1, isEmpty);
    });
  });

  group('scanner', () {
    late Directory dir;
    late AppDatabase db;
    late ProviderContainer container;
    late List<String> opened;

    setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
    setUp(() {
      dir = Directory.systemTemp.createTempSync('panelist_lib');
      db = AppDatabase(NativeDatabase.memory());
      opened = [];
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          coversDirProvider.overrideWithValue(
            Directory(p.join(dir.path, '.covers')),
          ),
          comicReaderProvider.overrideWithValue((location) async {
            opened.add(p.basename(location));
            if (location.endsWith('bad.cbz')) throw Exception('broken');
            return (
              bookId: 'id-${p.basename(location)}',
              pageCount: 20,
              info: const ComicInfo(series: 'S', number: '1', publisher: 'P'),
              cover: Uint8List.fromList([1, 2, 3]),
              problem: null,
            );
          }),
        ],
      );
    });
    tearDown(() async {
      container.dispose();
      await db.close();
      dir.deleteSync(recursive: true);
    });

    File put(String rel) => File(p.join(dir.path, 'comics', rel))
      ..createSync(recursive: true)
      ..writeAsStringSync(rel);

    Future<List<LibraryEntry>> scan() async {
      await container.read(libraryScanProvider.notifier).scan();
      return (await db.entriesOf(1))
        ..sort((a, b) => a.location.compareTo(b.location));
    }

    test('a problem from an earlier run is tried once more', () async {
      put('fixed.cbz');
      await db.addRoot(p.join(dir.path, 'comics'), 'comics');
      await scan();
      // As an earlier run left it: read, with a problem.
      final location = p.join(dir.path, 'comics', 'fixed.cbz');
      await db.updateEntry(
        location,
        const LibraryEntriesCompanion(error: Value('could not unpack')),
      );
      // A new run (a new scanner): tried again, and now it reads.
      final next = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          coversDirProvider.overrideWithValue(
            Directory(p.join(dir.path, '.covers')),
          ),
          comicReaderProvider.overrideWithValue((location) async {
            opened.add(p.basename(location));
            return (
              bookId: 'id-fixed',
              pageCount: 20,
              info: null,
              cover: null,
              problem: null,
            );
          }),
        ],
      );
      addTearDown(next.dispose);
      opened.clear();
      await next.read(libraryScanProvider.notifier).scan();
      expect(opened, ['fixed.cbz']);
      expect((await db.entryAt(location))!.error, isNull);
      // Once per run.
      opened.clear();
      await next.read(libraryScanProvider.notifier).scan();
      expect(opened, isEmpty);
    });

    test(
      'finds comics, skips hidden and non-comics, rescans only changes',
      () async {
        put('Pub/Series/a.cbz');
        put('top.pdf');
        put('notes.txt');
        put('.hidden/x.cbz');
        put('Series/.y.cbr');
        put('bad.cbz');
        await db.addRoot(p.join(dir.path, 'comics'), 'comics');

        var entries = await scan();
        expect(entries.map((e) => (e.folder, e.fileName)), [
          ('Pub/Series', 'a.cbz'),
          ('', 'bad.cbz'),
          ('', 'top.pdf'),
        ]);
        final a = entries.first;
        expect(
          (a.bookId, a.series, a.publisher, a.pageCount),
          ('id-a.cbz', 'S', 'P', 20),
        );
        expect(
          File(p.join(dir.path, '.covers', 'id-a.cbz.png')).readAsBytesSync(),
          [1, 2, 3],
        );
        expect(entries[1].error, contains('broken'));
        expect(opened, unorderedEquals(['a.cbz', 'top.pdf', 'bad.cbz']));

        // Nothing changed: nothing reopened (not even the broken one).
        opened.clear();
        await scan();
        expect(opened, isEmpty);

        // A changed file is reread, a deleted one disappears.
        put('top.pdf').writeAsStringSync('longer contents');
        File(p.join(dir.path, 'comics', 'bad.cbz')).deleteSync();
        entries = await scan();
        expect(opened, ['top.pdf']);
        expect(entries.map((e) => e.fileName), ['a.cbz', 'top.pdf']);
      },
    );

    test('covers of comics that left the library are deleted', () async {
      put('a.cbz');
      put('b.cbz');
      await db.addRoot(p.join(dir.path, 'comics'), 'comics');
      await scan();
      final covers = Directory(p.join(dir.path, '.covers'));
      expect(covers.listSync(), hasLength(2));
      File(p.join(dir.path, 'comics', 'b.cbz')).deleteSync();
      await scan();
      expect(covers.listSync().map((f) => p.basename(f.path)), [
        'id-a.cbz.png',
      ]);
    });

    test('a missing folder keeps its comics', () async {
      put('a.cbz');
      await db.addRoot(p.join(dir.path, 'comics'), 'comics');
      await scan();
      Directory(p.join(dir.path, 'comics'))
          .renameSync(p.join(dir.path, 'gone'));
      expect(await scan(), hasLength(1));
    });

    test('removing a folder removes its comics', () async {
      put('a.cbz');
      await db.addRoot(p.join(dir.path, 'comics'), 'comics');
      await scan();
      await db.removeRoot(1);
      expect(await db.entriesOf(1), isEmpty);
    });
  });

  test('mark read and unread', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    LibraryComic comic(String id, {int? pages = 10}) => LibraryComic(
      LibraryEntry(
        location: '/lib/$id.cbz',
        rootId: 1,
        folder: '',
        fileName: '$id.cbz',
        size: 1,
        modified: 0,
        bookId: id,
        pageCount: pages,
        series: 'S',
        number: id,
      ),
      null,
    );
    // One opened book, part read, with its own page count kept.
    await db.recordOpened(id: '2', path: '/x/2.cbz', title: 'x', pageCount: 12);
    await db.saveProgress('2', 3);

    await markComics(db, [
      comic('1'),
      comic('2'),
      comic('3', pages: null), // not scanned yet: skipped
    ], read: true);
    var progress = await db.watchProgress().first;
    // Read, keeping their place.
    expect(progress['1'], (currentPage: 0, pageCount: 10, finished: true));
    expect(progress['2'], (currentPage: 3, pageCount: 12, finished: true));
    expect(progress.containsKey('3'), isFalse);
    // Books marked read without opening them aren't recent.
    expect((await db.watchRecent().first).map((b) => b.id), ['2']);

    // Paging back in a read book doesn't unread it.
    await db.saveProgress('2', 1);
    expect((await db.watchProgress().first)['2']!.finished, isTrue);

    await db.saveBookSettings(
      '2',
      fitMode: 'width',
      layoutMode: 'single',
      coverAlone: true,
    );
    await markComics(db, [comic('1'), comic('2')], read: false);
    progress = await db.watchProgress().first;
    expect(progress['2'], (currentPage: 0, pageCount: 12, finished: false));
    expect(
      LibraryComic(comic('2').entry, progress['2']).readState,
      ReadState.unread,
    );
    // Settings survive; the book leaves recent books.
    expect((await db.book('2'))!.fitMode, 'width');
    expect(await db.watchRecent().first, isEmpty);

    // Reaching the last page finishes it again.
    await db.saveProgress('2', 11);
    expect((await db.watchProgress().first)['2']!.finished, isTrue);
  });
}

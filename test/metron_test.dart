import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panelist/core/metadata/comic_info.dart';
import 'package:panelist/core/metadata/comic_info_document.dart';
import 'package:panelist/core/metadata/metron.dart';
import 'package:panelist/core/metadata/metron_cache.dart';
import 'package:panelist/data/database.dart';
import 'package:panelist/library/library_model.dart';
import 'package:panelist/library/metron_lookup.dart';
import 'package:path/path.dart' as p;

Map<String, Object?> summary(
  int id,
  String series,
  String number, {
  int began = 2012,
  String cover = '2012-03-01',
}) => {
  'id': id,
  'number': number,
  'issue': '$series ($began) #$number',
  'series': {'id': 1, 'name': series, 'volume': 1, 'year_began': began},
  'cover_date': cover,
  'store_date': null,
  'image': null,
  'cover_hash': '',
  'modified': '2024-01-01T00:00:00Z',
};

final sagaDetail = <String, Object?>{
  'id': 4242,
  'publisher': {'id': 9, 'name': 'Image'},
  'imprint': null,
  'series': {
    'id': 1,
    'name': 'Saga',
    'sort_name': 'Saga',
    'volume': 1,
    'year_began': 2012,
    'series_type': {'id': 1, 'name': 'Ongoing Series'},
    'genres': [
      {'id': 1, 'name': 'Science Fiction'},
      {'id': 2, 'name': 'Fantasy'},
    ],
    'language': 'en',
  },
  'number': '1',
  'title': '',
  'name': ['Chapter One'],
  'cover_date': '2012-03-01',
  'store_date': '2012-03-14',
  'rating': {'id': 4, 'name': 'Mature'},
  'upc': '70985301766700111',
  'isbn': '',
  'desc': 'The start.',
  'arcs': [
    {'id': 1, 'name': 'Volume One', 'modified': '2024-01-01T00:00:00Z'},
  ],
  'credits': [
    {
      'id': 1,
      'creator': 'Brian K. Vaughan',
      'role': [
        {'id': 1, 'name': 'Writer'},
      ],
    },
    {
      'id': 2,
      'creator': 'Fiona Staples',
      'role': [
        {'id': 2, 'name': 'Artist'},
        {'id': 3, 'name': 'Cover'},
      ],
    },
    {
      'id': 3,
      'creator': 'Fonografiks',
      'role': [
        {'id': 4, 'name': 'Letterer'},
      ],
    },
  ],
  'characters': [
    {'id': 1, 'name': 'Alana', 'modified': '2024-01-01T00:00:00Z'},
    {'id': 2, 'name': 'Marko', 'modified': '2024-01-01T00:00:00Z'},
  ],
  'teams': <Object?>[],
  'resource_url': 'https://metron.cloud/issue/saga-2012-1/',
};

void main() {
  group('chooseMatch', () {
    final results = [
      MetronIssueSummary.fromJson(summary(1, 'Saga', '1')),
      MetronIssueSummary.fromJson(summary(2, 'Saga Deluxe', '1')),
      MetronIssueSummary.fromJson(
        summary(3, 'Batman', '1', began: 1940, cover: '1940-04-01'),
      ),
      MetronIssueSummary.fromJson(
        summary(4, 'Batman', '1', began: 2016, cover: '2016-08-01'),
      ),
      MetronIssueSummary.fromJson(summary(5, 'The Walking Dead', '001')),
    ];

    test('same name and number', () {
      expect(chooseMatch(results, series: 'saga', number: '01')?.id, 1);
      expect(chooseMatch(results, series: 'Walking Dead', number: '1')?.id, 5);
    });

    test('the year tells same-named series apart', () {
      expect(chooseMatch(results, series: 'Batman', number: '1'), isNull);
      expect(
        chooseMatch(results, series: 'Batman', number: '1', year: 2016)?.id,
        4,
      );
      expect(
        chooseMatch(results, series: 'Batman', number: '1', year: 1999),
        isNull,
      );
    });

    test('no match for other numbers or names', () {
      expect(chooseMatch(results, series: 'Saga', number: '2'), isNull);
      expect(chooseMatch(results, series: 'Sag', number: '1'), isNull);
    });
  });

  test('an anthology lists its stories, keeping commas in titles', () {
    final doc = ComicInfoDocument.empty();
    applyMetronIssue(doc, {
      ...sagaDetail,
      'name': [
        'The New Future, Part Nine',
        'Ghosted: Book Two, Part Ten',
        'Hungry City, Part 10',
      ],
    });
    expect(
      doc['Title'],
      'The New Future, Part Nine; Ghosted: Book Two, Part Ten; '
      'Hungry City, Part 10',
    );
  });

  test('searchForms: same-name forms first, then shorter ones', () {
    expect(searchForms('2000AD prog'), [
      ('2000AD prog', true),
      ('2000 AD prog', true),
      ('2000AD', false),
      ('2000 AD', false),
    ]);
    expect(searchForms('Hellboy in Hell - Nothing But Blood').take(3), [
      ('Hellboy in Hell - Nothing But Blood', true),
      ('Hellboy in Hell: Nothing But Blood', true),
      ('Hellboy in Hell - Nothing But', false),
    ]);
    expect(searchForms('Saga'), [('Saga', true)]);
  });

  test('applyMetronIssue maps like MetronTagger and keeps other fields', () {
    final doc = ComicInfoDocument.parse(
      '<ComicInfo><Series>saga</Series><Notes>My note\n'
      'Tagged with MetronTagger. [issue_id:1]</Notes>'
      '<ScanInformation>Zone</ScanInformation></ComicInfo>',
    );
    applyMetronIssue(doc, sagaDetail, now: DateTime(2026, 11, 25));

    expect(doc['Series'], 'Saga');
    expect(doc['Number'], '1');
    expect(doc['Volume'], '2012');
    expect(doc['Title'], 'Chapter One');
    expect(doc['Summary'], 'The start.');
    expect((doc['Year'], doc['Month'], doc['Day']), ('2012', '3', '1'));
    expect(doc['Publisher'], 'Image');
    expect(doc['Imprint'], isNull);
    expect(doc['Writer'], 'Brian K. Vaughan');
    expect(doc['Penciller'], 'Fiona Staples');
    expect(doc['Inker'], 'Fiona Staples');
    expect(doc['CoverArtist'], 'Fiona Staples');
    expect(doc['Letterer'], 'Fonografiks');
    expect(doc['Genre'], 'Science Fiction, Fantasy');
    expect(doc['Characters'], 'Alana, Marko');
    expect(doc['Teams'], isNull);
    expect(doc['StoryArc'], 'Volume One');
    expect(doc['AgeRating'], 'Mature');
    expect(doc['Format'], 'Series');
    expect(doc['Web'], 'https://metron.cloud/issue/saga-2012-1/');
    expect(doc['GTIN'], '70985301766700111');
    expect(doc['LanguageISO'], 'en');
    expect(doc['ScanInformation'], 'Zone');
    expect(
      doc['Notes'],
      'My note\nTagged with Panelist using info from Metron on 2026-11-25. '
      '[issue_id:4242]',
    );
    expect(metronIdFrom(doc), 4242);
  });

  group('client', () {
    late List<(Uri, Map<String, String>)> requests;
    late List<Duration> sleeps;
    late List<({int status, Map<String, String> headers, String body})> replies;

    MetronClient client() => MetronClient(
      'tok',
      transport: (uri, headers) async {
        requests.add((uri, headers));
        return replies.removeAt(0);
      },
      sleep: (d) async => sleeps.add(d),
    );

    ({int status, Map<String, String> headers, String body}) ok(Object json) =>
        (status: 200, headers: const {}, body: jsonEncode(json));

    setUp(() {
      requests = [];
      sleeps = [];
      replies = [];
    });

    test('searches with a token, and caches', () async {
      replies.add(
        ok({
          'count': 1,
          'next': null,
          'previous': null,
          'results': [summary(1, 'Saga', '1')],
        }),
      );
      final c = client();
      final r = await c.searchIssues(series: 'Saga', number: '1');
      expect(r.single.seriesName, 'Saga');
      expect(r.single.coverDate, DateTime(2012, 3));
      await c.searchIssues(series: 'Saga', number: '1');
      expect(requests, hasLength(1));
      final (uri, headers) = requests.single;
      expect(uri.path, '/api/issue/');
      expect(uri.queryParameters, {'series_name': 'Saga', 'number': '1'});
      expect(headers['Authorization'], 'Bearer tok');
      expect(headers['User-Agent'], startsWith('Panelist/'));
    });

    test('spaces requests, and waits as long as a 429 asks', () async {
      replies
        ..add(ok(sagaDetail))
        ..add((status: 429, headers: {'retry-after': '7'}, body: ''))
        ..add(ok({...sagaDetail, 'id': 5}));
      final c = client();
      await c.issue(4242);
      final second = await c.issue(5);
      expect(second['id'], 5);
      expect(requests, hasLength(3));
      expect(sleeps, contains(const Duration(seconds: 7)));
      expect(sleeps.where((d) => d > const Duration(seconds: 2)), isNotEmpty);
    });

    /// A Metron with [results] per search (`series_name`, or `id:N` for a
    /// `series_id` search) and [details] per issue ID; [asked] records each
    /// request.
    MetronClient fake(
      List<String> asked,
      List<Object?> Function(String query) results, {
      Map<int, Map<String, Object?>> details = const {},
      MetronCache? cache,
    }) => MetronClient(
      'tok',
      sleep: (_) async {},
      cache: cache,
      transport: (uri, _) async {
        final Object? body;
        if (RegExp(r'/issue/(\d+)/$').firstMatch(uri.path) case final m?) {
          asked.add('detail ${m[1]}');
          body = details[int.parse(m[1]!)] ?? {...sagaDetail, 'id': m[1]};
        } else {
          final q =
              uri.queryParameters['series_name'] ??
              'id:${uri.queryParameters['series_id']}';
          asked.add(q);
          body = {'results': results(q)};
        }
        return (
          status: 200,
          headers: const <String, String>{},
          body: jsonEncode(body),
        );
      },
    );

    test('"A - B" written as Metron\'s "A: B" is still a sure match', () async {
      final asked = <String>[];
      final c = fake(
        asked,
        (q) => q == 'Hellboy in Hell: Nothing But Blood'
            ? [summary(9, 'Hellboy in Hell: Nothing But Blood', '2')]
            : [],
      );
      final found = await c.findIssue(
        series: 'Hellboy in Hell - Nothing But Blood',
        number: '2',
      );
      expect(asked, [
        'Hellboy in Hell - Nothing But Blood',
        'Hellboy in Hell: Nothing But Blood',
      ]);
      expect((found.match?.id, found.sure), (9, true));
    });

    test('a shorter name only gives a likely match', () async {
      final asked = <String>[];
      final c = fake(
        asked,
        (q) => q == '2000 AD'
            ? [summary(7, '2000 AD', '2509', began: 2001, cover: '2026-11-01')]
            : [],
      );
      final found = await c.findIssue(
        series: '2000AD prog',
        number: '2509',
        year: 2026,
      );
      expect(asked, [
        '2000AD prog',
        '2000 AD prog',
        '2000AD',
        '2000 AD',
        'detail 7', // to check the series' other names
      ]);
      expect((found.match?.id, found.sure), (7, false));
      expect(found.results.first.id, 7);
    });

    test('Metron\'s other names for the series make it sure, and the series '
        'is remembered', () async {
      final asked = <String>[];
      final cache = MetronCache();
      final c = fake(
        asked,
        (q) => switch (q) {
          '2000 AD' => [
            summary(7, '2000 AD', '2509', began: 2001, cover: '2026-11-01'),
          ],
          'id:1' => [
            summary(8, '2000 AD', '2510', began: 2001, cover: '2026-11-01'),
          ],
          _ => [],
        },
        details: {
          7: {
            ...sagaDetail,
            'id': 7,
            'series': {
              'id': 1,
              'name': '2000 AD',
              'alt_names': ['2000AD', '2000AD Prog'],
            },
          },
        },
        cache: cache,
      );
      final found = await c.findIssue(
        series: '2000AD prog',
        number: '2509',
        year: 2026,
      );
      expect((found.match?.id, found.sure), (7, true));

      // The next prog: one search, by the series' ID.
      asked.clear();
      final next = await c.findIssue(
        series: '2000AD prog',
        number: '2510',
        year: 2026,
      );
      expect((next.match?.id, next.sure), (8, true));
      expect(asked, ['id:1']);
    });

    test('answers are kept on disk between runs', () async {
      final dir = Directory.systemTemp.createTempSync('panelist_mcache');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File(p.join(dir.path, 'metron.json'));
      final asked = <String>[];
      var now = DateTime(2026, 11, 25);
      MetronCache cache() => MetronCache(file: file, clock: () => now);
      List<Object?> saga(String q) => [summary(1, 'Saga', '1')];

      await fake(
        asked,
        saga,
        cache: cache(),
      ).findIssue(series: 'Saga', number: '1');
      await fake(asked, saga, cache: cache()).issue(1);
      expect(asked, ['Saga', 'detail 1']);

      // Next run, same day: nothing asked.
      await fake(
        asked,
        saga,
        cache: cache(),
      ).findIssue(series: 'Saga', number: '1');
      await fake(asked, saga, cache: cache()).issue(1);
      expect(asked, hasLength(2));

      // Two days on: searches again (new issues), details still kept.
      now = now.add(const Duration(days: 2));
      final later = fake(asked, saga, cache: cache());
      await later.findIssue(series: 'Saga', number: '1');
      await later.issue(1);
      expect(asked, ['Saga', 'detail 1', 'id:1']);
    });

    test('searches stop at the cap', () async {
      final asked = <String>[];
      final c = fake(asked, (_) => []);
      final found = await c.findIssue(
        series: 'One Two Three Four Five Six Seven Eight',
        number: '1',
      );
      expect(asked, hasLength(MetronClient.maxSearches));
      expect(found.match, isNull);
    });

    test('a refused token says so', () async {
      replies.add((status: 401, headers: const {}, body: '{}'));
      await expectLater(
        client().issue(1),
        throwsA(
          isA<MetronException>().having(
            (e) => e.message,
            'message',
            contains('token'),
          ),
        ),
      );
    });
  });

  group('tagComics', () {
    late Directory dir;
    late AppDatabase db;

    setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
    setUp(() {
      dir = Directory.systemTemp.createTempSync('panelist_metron');
      db = AppDatabase(NativeDatabase.memory());
    });
    tearDown(() async {
      await db.close();
      dir.deleteSync(recursive: true);
    });

    LibraryComic cbz(String name, {String? info}) {
      final a = Archive()..addFile(ArchiveFile.bytes('01.jpg', Uint8List(10)));
      if (info != null) a.addFile(ArchiveFile.string('ComicInfo.xml', info));
      final path = p.join(dir.path, name);
      File(path).writeAsBytesSync(ZipEncoder().encodeBytes(a));
      return LibraryComic(
        LibraryEntry(
          location: path,
          rootId: 1,
          folder: '',
          fileName: name,
          size: 1,
          modified: 0,
        ),
        null,
      );
    }

    ComicInfo? infoOf(LibraryComic c) {
      final f = ZipDecoder()
          .decodeBytes(File(c.location).readAsBytesSync())
          .findFile('ComicInfo.xml');
      return f == null ? null : ComicInfo.parse(utf8.decode(f.readBytes()!));
    }

    test('matches by name, uses known IDs, and lists the unsure', () async {
      final byName = cbz('Saga 001 (2012) (Digital).cbz');
      final byId = cbz(
        'whatever.cbz',
        info: '<ComicInfo><Notes>[issue_id:4242]</Notes></ComicInfo>',
      );
      final unsure = cbz('Batman 001.cbz');
      final requests = <Uri>[];
      final metron = MetronClient(
        'tok',
        sleep: (_) async {},
        transport: (uri, _) async {
          requests.add(uri);
          final body = switch (uri.path) {
            '/api/issue/4242/' => sagaDetail,
            '/api/issue/' when uri.queryParameters['series_name'] == 'Saga' => {
              'results': [summary(4242, 'Saga', '1')],
            },
            '/api/issue/' => {
              'results': [
                summary(3, 'Batman', '1', began: 1940, cover: '1940-04-01'),
                summary(4, 'Batman', '1', began: 2016, cover: '2016-08-01'),
              ],
            },
            _ => throw StateError('unexpected $uri'),
          };
          return (
            status: 200,
            headers: const <String, String>{},
            body: jsonEncode(body),
          );
        },
      );

      final r = await tagComics(db, metron, [byName, byId, unsure]);

      expect(r.tagged, 2);
      expect(r.failed, 0);
      expect(r.unmatched.single.comic.location, unsure.location);
      expect(r.unmatched.single.reason, '2 possible matches');
      expect(infoOf(byName)!.writer, 'Brian K. Vaughan');
      expect(infoOf(byId)!.series, 'Saga');
      expect(infoOf(unsure), isNull); // untouched
      // The known ID needed no search; the detail was cached.
      expect(requests.where((u) => u.path == '/api/issue/4242/'), hasLength(1));
      expect(describeTagResult(r), 'Tagged 2 comics · 1 to choose');
    });
  });
}

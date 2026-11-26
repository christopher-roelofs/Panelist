import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panelist/core/metadata/comic_info.dart';
import 'package:panelist/core/metadata/comic_info_document.dart';
import 'package:panelist/core/metadata/lookup/api_client.dart';
import 'package:panelist/core/metadata/lookup/comicvine_provider.dart';
import 'package:panelist/core/metadata/lookup/lookup_cache.dart';
import 'package:panelist/core/metadata/lookup/lookup_provider.dart';
import 'package:panelist/core/metadata/lookup/metron_provider.dart';
import 'package:panelist/data/database.dart';
import 'package:panelist/library/info_lookup.dart';
import 'package:panelist/library/library_model.dart';
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

final _metron = MetronProvider('tok');

IssueCandidate cand(
  int id,
  String series,
  String number, {
  int began = 2012,
  String cover = '2012-03-01',
  String? publisher,
}) => IssueCandidate(
  provider: _metron,
  id: id,
  number: number,
  seriesName: series,
  seriesYearBegan: began,
  coverDate: DateTime.parse(cover),
  publisher: publisher,
);

void main() {
  group('chooseMatch', () {
    final results = [
      cand(1, 'Saga', '1'),
      cand(2, 'Saga Deluxe', '1'),
      cand(3, 'Batman', '1', began: 1940, cover: '1940-04-01'),
      cand(4, 'Batman', '1', began: 2016, cover: '2016-08-01'),
      cand(5, 'The Walking Dead', '001'),
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

    test('the publisher tells same-named series apart', () {
      final r = [
        cand(1, 'Saga', '1', publisher: 'Image'),
        cand(2, 'Saga', '1', publisher: 'Cross Cult'),
      ];
      expect(chooseMatch(r, series: 'Saga', number: '1'), isNull);
      expect(
        chooseMatch(r, series: 'Saga', number: '1', publisher: 'image')?.id,
        1,
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
    expect(_metron.knownId(doc), 4242);
  });

  group('client', () {
    late List<(Uri, Map<String, String>)> requests;
    late List<Duration> sleeps;
    late List<({int status, Map<String, String> headers, String body})> replies;

    MetronProvider client() => MetronProvider(
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
      final r = await c.search('Saga', '1');
      expect(r.single.seriesName, 'Saga');
      expect(r.single.coverDate, DateTime(2012, 3));
      await c.search('Saga', '1');
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
    MetronProvider fake(
      List<String> asked,
      List<Object?> Function(String query) results, {
      Map<int, Map<String, Object?>> details = const {},
      LookupCache? cache,
    }) => MetronProvider(
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
      final cache = LookupCache();
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
      LookupCache cache() => LookupCache(file: file, clock: () => now);
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
      expect(asked, hasLength(LookupProvider.maxSearches));
      expect(found.match, isNull);
    });

    test('a refused token says so, and stops the provider', () async {
      replies.add((status: 401, headers: const {}, body: '{}'));
      await expectLater(
        client().issue(1),
        throwsA(
          isA<LookupException>()
              .having((e) => e.message, 'message', contains('API key'))
              .having((e) => e.stopsProvider, 'stopsProvider', isTrue),
        ),
      );
    });
  });

  group('Comic Vine', () {
    final volumes = <Map<String, Object?>>[
      {
        'id': 46568,
        'name': 'Saga',
        'start_year': '2012',
        'publisher': {'id': 1, 'name': 'Image'},
        'aliases': null,
      },
      {
        'id': 110032,
        'name': 'Saga',
        'start_year': '2013',
        'publisher': {'id': 2, 'name': 'Cross Cult'},
        'aliases': null,
      },
      {
        'id': 44141,
        'name': 'Vinland Saga',
        'start_year': '2006',
        'publisher': {'id': 3, 'name': 'Kodansha'},
        'aliases': 'Vinrando Saga',
      },
      {
        'id': 777,
        'name': '2000 AD',
        'start_year': '1977',
        'publisher': {'id': 4, 'name': 'Rebellion'},
        'aliases': '2000AD\r\n2000 A.D.',
      },
    ];
    Map<String, Object?> issueOf(int id, int volume, String number) => {
      'id': id,
      'issue_number': number,
      'name': 'Chapter One',
      'cover_date': '2012-03-01',
      'store_date': '2012-03-14',
      'image': {'small_url': 'https://cv/img/$id.jpg'},
      'volume': {'id': volume, 'name': 'Saga'},
    };
    final issues = [
      issueOf(321297, 46568, '1'),
      issueOf(667077, 110032, '1'),
      issueOf(999, 777, '2509'),
    ];
    final detail = <String, Object?>{
      'id': 321297,
      'name': 'Chapter One',
      'issue_number': '1',
      'cover_date': '2012-03-01',
      'description':
          '<p>Hazel &amp; her parents.</p><p>Second.</p>'
          '<h2>Cover Information</h2><table><tr><td>x</td></tr></table>',
      'person_credits': [
        {'name': 'Brian K. Vaughan', 'role': 'writer'},
        {'name': 'Fiona Staples', 'role': 'artist, cover'},
        {'name': 'Fonografiks', 'role': 'letterer'},
      ],
      'character_credits': [
        {'name': 'Alana'},
        {'name': 'Marko'},
      ],
      'team_credits': <Object?>[],
      'location_credits': [
        {'name': 'Landfall'},
      ],
      'story_arc_credits': <Object?>[],
      'volume': {'id': 46568, 'name': 'Saga'},
      'site_detail_url':
          'https://comicvine.gamespot.com/saga-1-chapter-one/4000-321297/',
    };

    ComicVineProvider fake(List<String> asked, {int status = 1}) =>
        ComicVineProvider(
          'secret',
          sleep: (_) async {},
          transport: (uri, headers) async {
            expect(uri.queryParameters['api_key'], 'secret');
            expect(headers['User-Agent'], startsWith('Panelist/'));
            final q = uri.queryParameters;
            final path = uri.path.replaceFirst('/api/', '');
            Object? results;
            if (path == 'search/') {
              asked.add('search ${q['query']}');
              final words = q['query']!.toLowerCase().split(' ');
              results = [
                for (final v in volumes)
                  if (words.every(
                    (w) => '${v['name']} ${v['aliases']}'
                        .toLowerCase()
                        .contains(w),
                  ))
                    v,
              ];
            } else if (path == 'issues/') {
              asked.add('issues ${q['filter']}');
              final m = RegExp(r'volume:([\d|]+)(?:,issue_number:(.+))?')
                  .firstMatch(q['filter']!)!;
              final ids = m[1]!.split('|').map(int.parse).toSet();
              results = [
                for (final i in issues)
                  if (ids.contains((i['volume']! as Map)['id']) &&
                      (m[2] == null || i['issue_number'] == m[2]))
                    i,
              ];
            } else if (RegExp(r'^volume/4050-(\d+)/$').firstMatch(path)
                case final m?) {
              asked.add('volume ${m[1]}');
              results = volumes.firstWhere((v) => '${v['id']}' == m[1]);
            } else if (path == 'issue/4000-321297/') {
              asked.add('issue 321297');
              results = detail;
            }
            return (
              status: 200,
              headers: const <String, String>{},
              body: jsonEncode({
                'status_code': status,
                'error': status == 1 ? 'OK' : 'Invalid API Key',
                'results': results,
              }),
            );
          },
        );

    test('finds volumes by name, then the issue in them', () async {
      final asked = <String>[];
      final cv = fake(asked);
      final found = await cv.findIssue(
        series: 'Saga',
        number: '1',
        year: 2012,
        publisher: 'Image',
      );
      expect((found.match?.id, found.sure), (321297, true));
      expect(found.match!.publisher, 'Image');
      expect(found.match!.label, 'Saga (2012) #1: Chapter One');
      // Vinland Saga is not searched for issues.
      expect(asked, [
        'search Saga',
        'issues volume:46568|110032,issue_number:1',
      ]);
    });

    test('a series is sure under one of its other names', () async {
      final asked = <String>[];
      final found = await fake(asked)
          .findIssue(series: '2000AD', number: '2509');
      expect((found.match?.id, found.sure), (999, true));
      expect(asked.first, 'search 2000AD');
    });

    test('the key is never cached', () async {
      final cache = LookupCache();
      final cv = ComicVineProvider(
        'secret',
        cache: cache,
        sleep: (_) async {},
        transport: (_, _) async => (
          status: 200,
          headers: const <String, String>{},
          body: jsonEncode({'status_code': 1, 'results': <Object?>[]}),
        ),
      );
      await cv.search('Saga', '1');
      expect(cv.searchCached('Saga', '1'), isTrue);
      final dir = Directory.systemTemp.createTempSync('panelist_cv');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File(p.join(dir.path, 'lookup.json'));
      final disk = LookupCache(file: file);
      await ComicVineProvider(
        'secret',
        cache: disk,
        sleep: (_) async {},
        transport: (_, _) async => (
          status: 200,
          headers: const <String, String>{},
          body: jsonEncode({'status_code': 1, 'results': <Object?>[]}),
        ),
      ).search('Saga', '1');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(file.readAsStringSync(), isNot(contains('secret')));
      expect(file.readAsStringSync(), contains('comicvine.gamespot.com'));
    });

    test('a refused key stops the provider', () async {
      await expectLater(
        fake([], status: 100).search('Saga', '1'),
        throwsA(
          isA<LookupException>().having(
            (e) => e.stopsProvider,
            'stopsProvider',
            isTrue,
          ),
        ),
      );
    });

    test('applies an issue like ComicTagger', () async {
      final asked = <String>[];
      final doc = ComicInfoDocument.parse(
        '<ComicInfo><Notes>Mine\n[CVDB1]</Notes></ComicInfo>',
      );
      await fake(asked).apply(doc, 321297, now: DateTime(2026, 11, 25));
      expect(asked, ['issue 321297', 'volume 46568']);
      expect(doc['Series'], 'Saga');
      expect(doc['Number'], '1');
      expect(doc['Volume'], '2012');
      expect(doc['Title'], 'Chapter One');
      expect(doc['Summary'], 'Hazel & her parents.\nSecond.');
      expect((doc['Year'], doc['Month'], doc['Day']), ('2012', '3', '1'));
      expect(doc['Publisher'], 'Image');
      expect(doc['Writer'], 'Brian K. Vaughan');
      expect(doc['Penciller'], 'Fiona Staples');
      expect(doc['Inker'], 'Fiona Staples');
      expect(doc['CoverArtist'], 'Fiona Staples');
      expect(doc['Letterer'], 'Fonografiks');
      expect(doc['Characters'], 'Alana, Marko');
      expect(doc['Locations'], 'Landfall');
      expect(doc['Web'], detail['site_detail_url']);
      expect(
        doc['Notes'],
        'Mine\nTagged with Panelist using info from Comic Vine on '
        '2026-11-25. [Issue ID 321297]',
      );
      final cv = fake([]);
      expect(cv.knownId(doc), 321297);
      expect(
        cv.knownId(
          ComicInfoDocument.parse(
            '<ComicInfo><Web>https://comicvine.gamespot.com/x/4000-55/'
            '</Web></ComicInfo>',
          ),
        ),
        55,
      );
      expect(_metron.knownId(doc), isNull);
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

    String? xmlOf(LibraryComic c) {
      final f = ZipDecoder()
          .decodeBytes(File(c.location).readAsBytesSync())
          .findFile('ComicInfo.xml');
      return f == null ? null : utf8.decode(f.readBytes()!);
    }

    ComicInfo? infoOf(LibraryComic c) => switch (xmlOf(c)) {
      final x? => ComicInfo.parse(x),
      _ => null,
    };

    test('matches by name, uses known IDs, and lists the unsure', () async {
      final byName = cbz('Saga 001 (2012) (Digital).cbz');
      final byId = cbz(
        'whatever.cbz',
        info: '<ComicInfo><Notes>[issue_id:4242]</Notes></ComicInfo>',
      );
      final unsure = cbz('Batman 001.cbz');
      final requests = <Uri>[];
      final metron = MetronProvider(
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

      final r = await tagComics(db, [metron], [byName, byId, unsure]);

      expect(r.tagged, 2);
      expect(r.failed, 0);
      expect(r.unmatched.single.comic.location, unsure.location);
      expect(r.unmatched.single.reason, '2 possible matches on Metron');
      expect(infoOf(byName)!.writer, 'Brian K. Vaughan');
      expect(infoOf(byId)!.series, 'Saga');
      expect(infoOf(unsure), isNull); // untouched
      // The known ID needed no search; the detail was cached.
      expect(requests.where((u) => u.path == '/api/issue/4242/'), hasLength(1));
      expect(describeTagResult(r), 'Tagged 2 comics · 1 to choose');
    });
    test('falls back to the next provider when the first finds nothing, '
        'and skips one that refuses its key', () async {
      final saga = cbz('Saga 001 (2012).cbz');
      final other = cbz('Saga 002 (2012).cbz');
      final metronAsked = <String>[];
      final emptyMetron = MetronProvider(
        'tok',
        sleep: (_) async {},
        transport: (uri, _) async {
          metronAsked.add(uri.path);
          return (
            status: 200,
            headers: const <String, String>{},
            body: jsonEncode({'results': <Object?>[]}),
          );
        },
      );
      var cvCalls = 0;
      final cv = ComicVineProvider(
        'k',
        sleep: (_) async {},
        transport: (uri, _) async {
          cvCalls++;
          final path = uri.path.replaceFirst('/api/', '');
          final results = switch (path) {
            'search/' => [
              {'id': 46568, 'name': 'Saga', 'start_year': '2012'},
            ],
            'issues/' => [
              {
                'id': 321297,
                'issue_number': uri.queryParameters['filter']!.split(':').last,
                'cover_date': '2012-03-01',
                'volume': {'id': 46568, 'name': 'Saga'},
              },
            ],
            'volume/4050-46568/' => {
              'id': 46568,
              'name': 'Saga',
              'start_year': '2012',
            },
            _ => {
              'id': 321297,
              'name': 'Chapter One',
              'issue_number': '1',
              'volume': {'id': 46568},
            },
          };
          return (
            status: 200,
            headers: const <String, String>{},
            body: jsonEncode({'status_code': 1, 'results': results}),
          );
        },
      );

      final r = await tagComics(db, [emptyMetron, cv], [saga]);
      expect(r.tagged, 1);
      expect(metronAsked, isNotEmpty);
      expect(infoOf(saga)!.title, 'Chapter One');
      expect(xmlOf(saga), contains('[Issue ID 321297]'));

      // A refused Metron key: noted once, Comic Vine still tags.
      final refused = MetronProvider(
        'bad',
        sleep: (_) async {},
        transport: (_, _) async =>
            (status: 401, headers: const <String, String>{}, body: ''),
      );
      cvCalls = 0;
      final r2 = await tagComics(db, [refused, cv], [other]);
      expect(r2.tagged, 1);
      expect(r2.errors.single, startsWith('Metron: '));
      expect(cvCalls, greaterThan(0));

      // Nothing anywhere: both names in the reason.
      final none = await tagComics(db, [emptyMetron], [cbz('Nope 001.cbz')]);
      expect(none.unmatched.single.reason, 'Not found on Metron');
    });
  });
}

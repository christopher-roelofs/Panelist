import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'comic_info_document.dart';
import 'metron_cache.dart';

/// Why talking to Metron failed.
class MetronException implements Exception {
  MetronException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// One HTTP GET: status, headers (lower-case names) and body. Swappable so
/// tests don't need the network.
typedef MetronTransport =
    Future<({int status, Map<String, String> headers, String body})> Function(
      Uri uri,
      Map<String, String> headers,
    );

/// An issue in Metron's search results.
class MetronIssueSummary {
  MetronIssueSummary.fromJson(Map<String, Object?> j)
    : id = j['id']! as int,
      number = '${j['number'] ?? ''}',
      displayName = '${j['issue'] ?? ''}',
      seriesId = (j['series'] as Map?)?['id'] as int?,
      seriesName = '${(j['series'] as Map?)?['name'] ?? ''}',
      seriesVolume = (j['series'] as Map?)?['volume'] as int?,
      seriesYearBegan = (j['series'] as Map?)?['year_began'] as int?,
      coverDate = DateTime.tryParse('${j['cover_date']}'),
      storeDate = DateTime.tryParse('${j['store_date']}'),
      image = j['image'] as String?;

  final int id;
  final String number;

  /// Metron's own label, e.g. "Chainkata (2026) #1".
  final String displayName;
  final int? seriesId;
  final String seriesName;
  final int? seriesVolume;
  final int? seriesYearBegan;
  final DateTime? coverDate;
  final DateTime? storeDate;

  /// Cover image URL.
  final String? image;
}

/// A client for the Metron comic database (metron.cloud), using an API
/// token from the user's Metron account page.
///
/// Requests are spaced to stay within Metron's per-minute limit; when Metron
/// still says to slow down (HTTP 429) the client waits as long as it asks
/// and tries again. Answers are kept in [cache] (issue details for 30
/// days, searches for a day, so newly added issues still turn up).
class MetronClient {
  MetronClient(
    this.token, {
    MetronTransport? transport,
    this.spacing = const Duration(milliseconds: 3100),
    Future<void> Function(Duration)? sleep,
    this.baseUrl = 'https://metron.cloud/api/',
    MetronCache? cache,
  }) : _transport = transport ?? _httpGet,
       _sleep = sleep ?? Future<void>.delayed,
       cache = cache ?? MetronCache();

  final MetronCache cache;

  static const searchMaxAge = Duration(days: 1);
  static const issueMaxAge = Duration(days: 30);

  final String token;

  /// Time between requests: about 19 a minute, under Metron's burst limit.
  final Duration spacing;
  final String baseUrl;
  final MetronTransport _transport;
  final Future<void> Function(Duration) _sleep;
  DateTime? _last;
  Future<void> _queue = Future.value();

  static const userAgent = 'Panelist/1.0 (comic reader; metadata lookup)';

  /// Issues matching [series] (Metron matches names loosely) and, if given,
  /// [number]. First page of results only (the best matches).
  Future<List<MetronIssueSummary>> searchIssues({
    required String series,
    String? number,
  }) async {
    return _issues({
      'series_name': series,
      if (number != null && number.isNotEmpty) 'number': number,
    });
  }

  Future<List<MetronIssueSummary>> _issues(Map<String, String> params) async {
    final json = await _get('issue/', params, searchMaxAge);
    final results = (json as Map?)?['results'];
    if (results is! List) return const [];
    return [
      for (final r in results)
        if (r is Map<String, Object?> && r['id'] is int)
          MetronIssueSummary.fromJson(r),
    ];
  }

  /// At most this many searches per [findIssue] (each costs ~3 s and
  /// counts against Metron's limits).
  static const maxSearches = 6;

  /// Finds the issue that is [series] #[number] (from [year]), trying more
  /// forms of the name only while nothing fits:
  ///
  /// 1. The name as written.
  /// 2. The same words written differently: digits and letters apart
  ///    (`2000AD` → `2000 AD`), `A - B` as `A: B` (colons can't be in
  ///    Windows file names). Still the same name, so a match is **sure**.
  /// 3. Shorter names: words dropped from the end one at a time, and each
  ///    half of `A - B`. A name that isn't the comic's own can only give a
  ///    **likely** match, for the user to confirm.
  ///
  /// No words are special: the file name decides which forms are tried, and
  /// Metron's answers decide which fit ([chooseMatch]).
  Future<MetronSearch> findIssue({
    required String series,
    String? number,
    int? year,
  }) async {
    final name = _norm(series);
    final byName = {
      'series_name': series,
      if (number != null && number.isNotEmpty) 'number': number,
    };
    // A series this name was found to be before: one search by its ID
    // (unless the search by name is still cached, which costs none).
    if (cache.seriesFor(name) case final id?
        when !_cached('issue/', byName, searchMaxAge)) {
      final r = await _issues({
        'series_id': '$id',
        if (number != null && number.isNotEmpty) 'number': number,
      });
      final m = r.isEmpty
          ? null
          : chooseMatch(
              r,
              series: r.first.seriesName,
              number: number,
              year: year,
            );
      if (m != null) return (results: _bestFirst(r, m), match: m, sure: true);
    }

    final all = <MetronIssueSummary>[];
    MetronIssueSummary? likely;
    var searches = 0;
    for (final (query, sameName) in searchForms(series)) {
      if (searches++ >= maxSearches) break;
      final r = await searchIssues(series: query, number: number);
      for (final x in r) {
        if (!all.any((y) => y.id == x.id)) all.add(x);
      }
      final sure = chooseMatch(all, series: series, number: number, year: year);
      if (sure != null) {
        _remember(series, sure);
        return (results: _bestFirst(all, sure), match: sure, sure: true);
      }
      if (!sameName) {
        likely = chooseMatch(r, series: query, number: number, year: year);
        if (likely != null) break;
      }
    }
    // Metron lists other names a series goes by ("2000AD Prog" for
    // "2000 AD"): if the comic's name is one, the match is sure after all.
    // (The details are needed to save it anyway.)
    if (likely != null) {
      final detail = await issue(likely.id);
      final alt = (detail['series'] as Map?)?['alt_names'];
      if (alt is List && alt.any((a) => _norm('$a') == name)) {
        _remember(series, likely);
        return (results: _bestFirst(all, likely), match: likely, sure: true);
      }
    }
    return (results: _bestFirst(all, likely), match: likely, sure: false);
  }

  void _remember(String series, MetronIssueSummary match) {
    if (match.seriesId case final id?) cache.rememberSeries(_norm(series), id);
  }

  /// The user confirmed that [series] (a name from a file) is [match]'s
  /// series: later issues are found by its ID.
  void rememberSeries(String series, MetronIssueSummary match) =>
      _remember(series, match);

  static List<MetronIssueSummary> _bestFirst(
    List<MetronIssueSummary> all,
    MetronIssueSummary? best,
  ) => [?best, ...all.where((r) => r != best)];

  /// An issue's full details.
  Future<Map<String, Object?>> issue(int id) async {
    final json = await _get('issue/$id/', const {}, issueMaxAge);
    if (json is! Map<String, Object?>) {
      throw MetronException('Metron sent an unexpected reply for issue $id');
    }
    return json;
  }

  Uri _uri(String path, Map<String, String> params) =>
      Uri.parse('$baseUrl$path')
          .replace(queryParameters: params.isEmpty ? null : params);

  bool _cached(String path, Map<String, String> params, Duration maxAge) =>
      cache.get(_uri(path, params), maxAge) != null;

  Future<Object?> _get(
    String path,
    Map<String, String> params,
    Duration maxAge,
  ) {
    final uri = _uri(path, params);
    if (cache.get(uri, maxAge) case final hit?) return Future.value(hit.body);
    // One request at a time, so spacing holds across callers.
    final result = _queue.then((_) => _fetch(uri, maxAge));
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<Object?> _fetch(Uri uri, Duration maxAge) async {
    if (cache.get(uri, maxAge) case final hit?) return hit.body;
    for (var attempt = 0; ; attempt++) {
      final last = _last;
      if (last != null) {
        final wait = spacing - DateTime.now().difference(last);
        if (wait > Duration.zero) await _sleep(wait);
      }
      _last = DateTime.now();
      final ({int status, Map<String, String> headers, String body}) r;
      try {
        r = await _transport(uri, {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'User-Agent': userAgent,
        });
      } on SocketException catch (e) {
        throw MetronException('Couldn’t reach Metron: ${e.message}');
      } on TimeoutException {
        throw MetronException('Metron didn’t answer in time');
      } on HttpException catch (e) {
        throw MetronException('Couldn’t reach Metron: ${e.message}');
      }
      switch (r.status) {
        case 200:
          try {
            final body = jsonDecode(r.body);
            cache.put(uri, body);
            return body;
          } on FormatException {
            throw MetronException('Metron sent an unreadable reply');
          }
        case 429 when attempt < 3:
          final seconds = int.tryParse(r.headers['retry-after'] ?? '') ?? 60;
          await _sleep(Duration(seconds: seconds.clamp(1, 3600)));
        case 429:
          throw MetronException(
            'Metron’s request limit was reached; '
            'try again later',
          );
        case 401 || 403:
          throw MetronException(
            'Metron didn’t accept the API token (check it in Settings)',
          );
        case 404:
          throw MetronException('Not found on Metron');
        default:
          throw MetronException('Metron answered with error ${r.status}');
      }
    }
  }

  static Future<({int status, Map<String, String> headers, String body})>
  _httpGet(Uri uri, Map<String, String> headers) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await client.getUrl(uri);
      headers.forEach(request.headers.set);
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 30));
      final out = <String, String>{};
      response.headers.forEach((name, values) {
        out[name.toLowerCase()] = values.join(',');
      });
      return (status: response.statusCode, headers: out, body: body);
    } finally {
      client.close();
    }
  }
}

/// What [MetronClient.findIssue] found: every result seen, and the match if
/// any; [sure] when its series has the comic's own name.
typedef MetronSearch = ({
  List<MetronIssueSummary> results,
  MetronIssueSummary? match,
  bool sure,
});

/// The names [MetronClient.findIssue] searches for, in order, each with
/// whether it is still the same name as [series] (only written
/// differently).
List<(String, bool)> searchForms(String series) {
  final out = <(String, bool)>[];
  void add(String form, bool same) {
    final f = form.trim();
    if (f.isNotEmpty && !out.any((o) => o.$1 == f)) out.add((f, same));
  }

  String spaced(String s) => s.replaceAllMapped(
    RegExp(r'(?<=\d)(?=[A-Za-z])|(?<=[A-Za-z])(?=\d)'),
    (_) => ' ',
  );

  add(series, true);
  add(spaced(series), true);
  final parts = series.split(' - ');
  if (parts.length > 1) add(parts.join(': '), true);
  // Shorter: drop trailing words, each also spaced.
  final words = series.split(RegExp(r'\s+'));
  for (var n = words.length - 1; n >= 1; n--) {
    final shorter = words
        .take(n)
        .join(' ')
        .replaceAll(RegExp(r'[\s\-:]+$'), '');
    add(shorter, false);
    add(spaced(shorter), false);
  }
  if (parts.length > 1) {
    add(parts.last, false);
  }
  return out;
}

/// The Metron issue ID recorded in a ComicInfo's Notes (`[issue_id:N]`, as
/// MetronTagger and Panelist write it), or null.
int? metronIdFrom(ComicInfoDocument doc) {
  final m = RegExp(r'\[issue_id:(\d+)\]').firstMatch(doc['Notes'] ?? '');
  return m == null ? null : int.parse(m.group(1)!);
}

String _norm(String s) => s
    .toLowerCase()
    .replaceAll('&', 'and')
    .replaceAll(RegExp(r'^the\s+'), '')
    .replaceAll(RegExp(r'[^a-z0-9]'), '');

String _normNumber(String n) {
  final t = n.trim().toLowerCase().replaceFirst(RegExp(r'^0+(?=\d)'), '');
  return t.isEmpty ? '0' : t;
}

/// The one result that is this comic: same series name (ignoring case,
/// punctuation and a leading "The"), same number, and, if [year] is known,
/// a cover, store or series-start year within a year of it. Null when none
/// or several fit (the user picks).
MetronIssueSummary? chooseMatch(
  List<MetronIssueSummary> results, {
  required String series,
  required String? number,
  int? year,
}) {
  final name = _norm(series);
  final fits = [
    for (final r in results)
      if (_norm(r.seriesName) == name &&
          (number == null || _normNumber(r.number) == _normNumber(number)))
        r,
  ];
  if (year == null) return fits.length == 1 ? fits.single : null;
  bool near(int? y) => y != null && (y - year).abs() <= 1;
  final dated = [
    for (final r in fits)
      if (near(r.coverDate?.year) ||
          near(r.storeDate?.year) ||
          near(r.seriesYearBegan))
        r,
  ];
  if (dated.length == 1) return dated.single;
  // Several near: prefer the only one from exactly that year.
  final exact = [
    for (final r in dated)
      if (r.coverDate?.year == year || r.storeDate?.year == year) r,
  ];
  return exact.length == 1 ? exact.single : null;
}

/// Writes Metron issue [json] into [doc], the way MetronTagger does (Volume
/// is the series' start year; credits by role; the issue ID in Notes).
/// Fields Metron has no value for are left as they were.
void applyMetronIssue(
  ComicInfoDocument doc,
  Map<String, Object?> json, {
  DateTime? now,
}) {
  String? str(Object? v) {
    final s = v?.toString().trim();
    return s == null || s.isEmpty ? null : s;
  }

  String? nameOf(Object? v) => v is Map ? str(v['name']) : null;
  String? names(Object? list, {String separator = ', '}) {
    if (list is! List) return null;
    final out = <String>[];
    for (final e in list) {
      final n = e is Map ? str(e['name']) : str(e);
      if (n != null && !out.contains(n)) out.add(n);
    }
    return out.isEmpty ? null : out.join(separator);
  }

  void set(String field, String? value) {
    if (value != null) doc[field] = value;
  }

  final series = json['series'] is Map ? json['series']! as Map : const {};
  set('Series', str(series['name']));
  set('Number', str(json['number']));
  set('Volume', str(series['year_began']));
  set(
    'Title',
    // A collection's own title, else the stories in it. Anthologies (2000
    // AD, Judge Dredd Megazine) list one per serial, so this can be long;
    // the separator mustn't be a comma, which story titles contain.
    str(json['title']) ?? names(json['name'], separator: '; '),
  );
  set('Summary', str(json['desc']));
  final date = DateTime.tryParse('${json['cover_date']}');
  if (date != null) {
    set('Year', '${date.year}');
    set('Month', '${date.month}');
    set('Day', '${date.day}');
  }
  set('Publisher', nameOf(json['publisher']));
  set('Imprint', nameOf(json['imprint']));
  set('Genre', names(series['genres']));
  set('Characters', names(json['characters']));
  set('Teams', names(json['teams']));
  set('StoryArc', names(json['arcs']));
  final rating = nameOf(json['rating']);
  if (rating != null && rating != 'Unknown') set('AgeRating', rating);
  set('Format', switch (nameOf(series['series_type'])) {
    'Ongoing Series' => 'Series',
    'Trade Paperback' => 'TPB',
    'Hard Cover' => 'HC',
    final other => other,
  });
  set('Web', str(json['resource_url']));
  set('GTIN', str(json['upc']) ?? str(json['isbn']));
  set('LanguageISO', str(series['language']));

  // Credits by role.
  const roles = {
    'Writer': ['writer', 'script', 'story', 'plot', 'scripter'],
    'Penciller': ['penciller', 'pencils', 'artist', 'illustrator', 'layouts'],
    'Inker': ['inker', 'inks', 'artist', 'finishes'],
    'Colorist': ['colorist', 'colors', 'colourist', 'colours'],
    'Letterer': ['letterer', 'letters'],
    'CoverArtist': ['cover', 'cover artist'],
    'Editor': ['editor', 'editor in chief', 'senior editor', 'group editor'],
    'Translator': ['translator'],
  };
  final byField = <String, List<String>>{};
  if (json['credits'] case final List<Object?> credits) {
    for (final c in credits) {
      if (c is! Map) continue;
      final creator = str(c['creator']) ?? nameOf(c['creator']);
      if (creator == null || c['role'] is! List) continue;
      for (final role in c['role'] as List) {
        final r = (nameOf(role) ?? str(role))?.toLowerCase();
        for (final MapEntry(key: field, value: names) in roles.entries) {
          if (names.contains(r)) {
            final list = byField[field] ??= [];
            if (!list.contains(creator)) list.add(creator);
          }
        }
      }
    }
  }
  byField.forEach((field, people) => set(field, people.join(', ')));

  // Where it came from, replacing an earlier tagger's line but keeping any
  // other notes.
  final id = json['id'];
  final day = (now ?? DateTime.now()).toIso8601String().substring(0, 10);
  final line =
      'Tagged with Panelist using info from Metron on $day. '
      '[issue_id:$id]';
  final kept = (doc['Notes'] ?? '')
      .split('\n')
      .where((l) => !l.contains('[issue_id:') && l.trim().isNotEmpty)
      .join('\n');
  doc['Notes'] = kept.isEmpty ? line : '$kept\n$line';
}

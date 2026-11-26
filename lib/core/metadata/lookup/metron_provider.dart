import '../comic_info_document.dart';
import 'api_client.dart';
import 'lookup_cache.dart';
import 'lookup_provider.dart';

/// Metron (metron.cloud), a free community comic database. Needs an API
/// token from the user's Metron account page (sent as a Bearer token).
class MetronProvider extends LookupProvider {
  MetronProvider(
    this.token, {
    HttpTransport? transport,
    Future<void> Function(Duration)? sleep,
    LookupCache? cache,
    Duration spacing = const Duration(milliseconds: 3100),
    this.baseUrl = 'https://metron.cloud/api/',
  }) : client = ApiClient(
         name: 'Metron',
         spacing: spacing,
         transport: transport,
         sleep: sleep,
         cache: cache,
       );

  final String token;
  final String baseUrl;

  /// Requests ~3 s apart (about 19 a minute, under Metron's burst limit).
  final ApiClient client;

  static const searchMaxAge = Duration(days: 1);
  static const issueMaxAge = Duration(days: 30);

  @override
  String get id => 'metron';

  @override
  String get name => 'Metron';

  @override
  LookupCache get cache => client.cache;

  @override
  Duration get requestSpacing => client.spacing;

  Uri _uri(String path, [Map<String, String> params = const {}]) =>
      Uri.parse('$baseUrl$path')
          .replace(queryParameters: params.isEmpty ? null : params);

  Future<Object?> _get(Uri uri, Duration maxAge) => client.get(
    uri,
    maxAge: maxAge,
    headers: {'Authorization': 'Bearer $token'},
  );

  Map<String, String> _byName(String query, String? number) => {
    'series_name': query,
    if (number != null && number.isNotEmpty) 'number': number,
  };

  @override
  Future<List<IssueCandidate>> search(String query, String? number) =>
      _issues(_byName(query, number));

  @override
  bool searchCached(String query, String? number) =>
      client.cached(_uri('issue/', _byName(query, number)), searchMaxAge);

  @override
  Future<List<IssueCandidate>> searchSeries(int seriesId, String? number) =>
      _issues({
        'series_id': '$seriesId',
        if (number != null && number.isNotEmpty) 'number': number,
      });

  Future<List<IssueCandidate>> _issues(Map<String, String> params) async {
    final json = await _get(_uri('issue/', params), searchMaxAge);
    final results = (json as Map?)?['results'];
    if (results is! List) return const [];
    return [
      for (final r in results)
        if (r is Map<String, Object?> && r['id'] is int) _candidate(r),
    ];
  }

  IssueCandidate _candidate(Map<String, Object?> j) {
    final series = j['series'] is Map ? j['series']! as Map : const {};
    return IssueCandidate(
      provider: this,
      id: j['id']! as int,
      number: '${j['number'] ?? ''}',
      displayName: '${j['issue'] ?? ''}',
      seriesId: series['id'] as int?,
      seriesName: '${series['name'] ?? ''}',
      seriesYearBegan: series['year_began'] as int?,
      coverDate: DateTime.tryParse('${j['cover_date']}'),
      storeDate: DateTime.tryParse('${j['store_date']}'),
      image: j['image'] as String?,
    );
  }

  /// An issue's full details.
  Future<Map<String, Object?>> issue(int issueId) async {
    final json = await _get(_uri('issue/$issueId/'), issueMaxAge);
    if (json is! Map<String, Object?>) {
      throw LookupException(
        'Metron sent an unexpected reply for issue $issueId',
      );
    }
    return json;
  }

  /// In the issue's details (needed to save it anyway).
  @override
  Future<List<String>> seriesAliases(IssueCandidate c) async {
    final alt = ((await issue(c.id))['series'] as Map?)?['alt_names'];
    return alt is List ? [for (final a in alt) '$a'] : const [];
  }

  static final _marker = RegExp(r'\[issue_id:(\d+)\]');

  /// `[issue_id:N]` in Notes, as MetronTagger and Panelist write it.
  @override
  int? knownId(ComicInfoDocument doc) {
    final m = _marker.firstMatch(doc['Notes'] ?? '');
    return m == null ? null : int.parse(m.group(1)!);
  }

  @override
  Future<void> apply(
    ComicInfoDocument doc,
    int issueId, {
    DateTime? now,
  }) async => applyMetronIssue(doc, await issue(issueId), now: now);
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
  // A collection's own title, else the stories in it. Anthologies (2000 AD,
  // Judge Dredd Megazine) list one per serial, so this can be long; the
  // separator mustn't be a comma, which story titles contain.
  set('Title', str(json['title']) ?? names(json['name'], separator: '; '));
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

  final credits = <(String, String)>[];
  if (json['credits'] case final List<Object?> list) {
    for (final c in list) {
      if (c is! Map) continue;
      final person = str(c['creator']) ?? nameOf(c['creator']);
      if (person == null || c['role'] is! List) continue;
      for (final role in c['role'] as List) {
        if (nameOf(role) ?? str(role) case final r?) credits.add((person, r));
      }
    }
  }
  creditsByField(credits)
      .forEach((field, people) => set(field, people.join(', ')));

  setTaggedNote(
    doc,
    source: 'Metron',
    marker: '[issue_id:${json['id']}]',
    isOwnLine: (l) => l.contains('[issue_id:'),
    now: now,
  );
}

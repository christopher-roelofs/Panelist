import '../comic_info_document.dart';
import 'api_client.dart';
import 'lookup_cache.dart';
import 'lookup_provider.dart';

/// Comic Vine (comicvine.gamespot.com), with a free API key from its API
/// page. Comic Vine calls a series a "volume" (type 4050) and an issue type
/// 4000. A search finds volumes by name, then one request filters their
/// issues by number.
class ComicVineProvider extends LookupProvider {
  ComicVineProvider(
    this.apiKey, {
    HttpTransport? transport,
    Future<void> Function(Duration)? sleep,
    LookupCache? cache,
    Duration spacing = const Duration(milliseconds: 1100),
    this.baseUrl = 'https://comicvine.gamespot.com/api/',
  }) : client = ApiClient(
         name: 'Comic Vine',
         spacing: spacing,
         transport: transport,
         sleep: sleep,
         cache: cache,
       );

  final String apiKey;
  final String baseUrl;

  /// Requests ~1 s apart (Comic Vine allows about 10 per 10 s, and 200 an
  /// hour per kind of request).
  final ApiClient client;

  static const searchMaxAge = Duration(days: 1);
  static const issueMaxAge = Duration(days: 30);

  /// Volumes from one search that are tried for a number (one request
  /// covers them all).
  static const maxVolumes = 40;

  @override
  String get id => 'comicvine';

  @override
  String get name => 'Comic Vine';

  @override
  LookupCache get cache => client.cache;

  @override
  Duration get requestSpacing => client.spacing;

  /// The address without the key: what's cached (keys never go to disk).
  Uri _key(String path, Map<String, String> params) =>
      Uri.parse('$baseUrl$path')
          .replace(queryParameters: {...params, 'format': 'json'});

  Future<Object?> _get(
    String path,
    Map<String, String> params,
    Duration maxAge,
  ) async {
    final key = _key(path, params);
    final json = await client.get(
      key.replace(queryParameters: {...key.queryParameters, 'api_key': apiKey}),
      key: key,
      maxAge: maxAge,
    );
    if (json is! Map) throw LookupException('Comic Vine sent an odd reply');
    switch (json['status_code']) {
      case 1:
        return json['results'];
      case 100:
        throw LookupException(
          'Comic Vine didn’t accept the API key (check it in Settings)',
          stopsProvider: true,
        );
      case 101:
        throw LookupException('Not found on Comic Vine');
      case 107:
        throw LookupException(
          'Comic Vine’s request limit was reached; try again later',
          stopsProvider: true,
        );
      default:
        throw LookupException('Comic Vine: ${json['error']}');
    }
  }

  static const _volumeFields = 'id,name,start_year,publisher,aliases';
  static const _issueFields =
      'id,volume,issue_number,name,image,cover_date,store_date';

  Map<String, String> _volumeSearch(String query) => {
    'resources': 'volume',
    'query': query,
    'field_list': _volumeFields,
    'limit': '50',
  };

  Map<String, String> _issueFilter(Iterable<int> volumes, String? number) => {
    'filter': [
      'volume:${volumes.join('|')}',
      if (number != null && number.isNotEmpty) 'issue_number:$number',
    ].join(','),
    'field_list': _issueFields,
  };

  /// Volumes from a search whose name, or one of whose other names, is
  /// [query].
  List<Map<String, Object?>> _sameNamed(Object? results, String query) {
    final want = normalizeName(query);
    return [
      for (final v in results is List ? results : const [])
        if (v is Map<String, Object?> &&
            v['id'] is int &&
            (normalizeName('${v['name']}') == want ||
                _aliases(v).any((a) => normalizeName(a) == want)))
          v,
    ].take(maxVolumes).toList();
  }

  @override
  Future<List<IssueCandidate>> search(String query, String? number) async {
    final volumes = _sameNamed(
      await _get('search/', _volumeSearch(query), searchMaxAge),
      query,
    );
    if (volumes.isEmpty) return const [];
    return _issues(volumes, number);
  }

  @override
  bool searchCached(String query, String? number) {
    final hit = cache.get(_key('search/', _volumeSearch(query)), searchMaxAge);
    if (hit == null) return false;
    final volumes = _sameNamed((hit.body as Map?)?['results'], query);
    return volumes.isEmpty ||
        client.cached(
          _key(
            'issues/',
            _issueFilter(volumes.map((v) => v['id']! as int), number),
          ),
          searchMaxAge,
        );
  }

  @override
  Future<List<IssueCandidate>> searchSeries(
    int seriesId,
    String? number,
  ) async {
    final volume = await _volume(seriesId);
    return _issues([volume], number);
  }

  Future<List<IssueCandidate>> _issues(
    List<Map<String, Object?>> volumes,
    String? number,
  ) async {
    final byId = {for (final v in volumes) v['id']! as int: v};
    final results = await _get(
      'issues/',
      _issueFilter(byId.keys, number),
      searchMaxAge,
    );
    return [
      for (final i in results is List ? results : const [])
        if (i is Map<String, Object?> && i['id'] is int)
          _candidate(i, byId[(i['volume'] as Map?)?['id']]),
    ];
  }

  IssueCandidate _candidate(
    Map<String, Object?> i,
    Map<String, Object?>? volume,
  ) {
    final v = volume ?? (i['volume'] as Map<String, Object?>? ?? const {});
    final image = i['image'] is Map ? i['image']! as Map : const {};
    final number = '${i['issue_number'] ?? ''}';
    final seriesName = '${v['name'] ?? ''}';
    final year = int.tryParse('${v['start_year']}');
    return IssueCandidate(
      provider: this,
      id: i['id']! as int,
      number: number,
      displayName:
          '$seriesName${year == null ? '' : ' ($year)'} #$number'
          '${_str(i['name']) == null ? '' : ': ${i['name']}'}',
      seriesId: v['id'] as int?,
      seriesName: seriesName,
      seriesYearBegan: year,
      coverDate: DateTime.tryParse('${i['cover_date']}'),
      storeDate: DateTime.tryParse('${i['store_date']}'),
      publisher: _str((v['publisher'] as Map?)?['name']),
      seriesAliases: volume == null ? null : _aliases(volume),
      image: (image['small_url'] ?? image['thumb_url']) as String?,
    );
  }

  Future<Map<String, Object?>> _volume(int volumeId) async {
    final v = await _get('volume/4050-$volumeId/', {
      'field_list': _volumeFields,
    }, issueMaxAge);
    if (v is! Map<String, Object?>) {
      throw LookupException('Comic Vine sent an odd reply for a series');
    }
    return v;
  }

  static List<String> _aliases(Map<String, Object?> volume) => [
    for (final a in '${volume['aliases'] ?? ''}'.split(RegExp(r'\r?\n')))
      if (a.trim().isNotEmpty) a.trim(),
  ];

  @override
  Future<List<String>> seriesAliases(IssueCandidate c) async =>
      c.seriesAliases ??
      (c.seriesId == null ? const [] : _aliases(await _volume(c.seriesId!)));

  static final _marker = RegExp(r'\[(?:Issue ID |CVDB)(\d+)\]');
  static final _url = RegExp(r'comicvine\.gamespot\.com/.*?/4000-(\d+)');

  /// `[Issue ID N]` (ComicTagger, Panelist) or `[CVDBN]` (older
  /// ComicTagger) in Notes, or a Comic Vine issue link in Web.
  @override
  int? knownId(ComicInfoDocument doc) {
    final m =
        _marker.firstMatch(doc['Notes'] ?? '') ??
        _url.firstMatch(doc['Web'] ?? '');
    return m == null ? null : int.parse(m.group(1)!);
  }

  @override
  Future<void> apply(
    ComicInfoDocument doc,
    int issueId, {
    DateTime? now,
  }) async {
    final issue = await _get('issue/4000-$issueId/', {
      'field_list':
          'id,name,issue_number,cover_date,store_date,description,'
          'person_credits,character_credits,team_credits,location_credits,'
          'story_arc_credits,volume,site_detail_url',
    }, issueMaxAge);
    if (issue is! Map<String, Object?>) {
      throw LookupException('Comic Vine sent an odd reply for an issue');
    }
    final volumeId = (issue['volume'] as Map?)?['id'];
    final volume = volumeId is int
        ? await _volume(volumeId)
        : const <String, Object?>{};
    applyComicVineIssue(doc, issue, volume, now: now);
  }
}

String? _str(Object? v) {
  final s = v?.toString().trim();
  return s == null || s.isEmpty || s == 'null' ? null : s;
}

/// Writes Comic Vine [issue] (of [volume]) into [doc] the way ComicTagger
/// does (Volume is the series' start year; credits by role; the issue ID in
/// Notes). Fields Comic Vine has no value for are left as they were.
void applyComicVineIssue(
  ComicInfoDocument doc,
  Map<String, Object?> issue,
  Map<String, Object?> volume, {
  DateTime? now,
}) {
  String? names(Object? list) {
    if (list is! List) return null;
    final out = <String>[];
    for (final e in list) {
      final n = e is Map ? _str(e['name']) : null;
      if (n != null && !out.contains(n)) out.add(n);
    }
    return out.isEmpty ? null : out.join(', ');
  }

  void set(String field, String? value) {
    if (value != null) doc[field] = value;
  }

  set(
    'Series',
    _str(volume['name']) ?? _str((issue['volume'] as Map?)?['name']),
  );
  set('Number', _str(issue['issue_number']));
  set('Volume', _str(volume['start_year']));
  set('Title', _str(issue['name']));
  set('Summary', htmlToText(_str(issue['description'])));
  final date = DateTime.tryParse('${issue['cover_date']}');
  if (date != null) {
    set('Year', '${date.year}');
    set('Month', '${date.month}');
    set('Day', '${date.day}');
  }
  set('Publisher', _str((volume['publisher'] as Map?)?['name']));
  set('Characters', names(issue['character_credits']));
  set('Teams', names(issue['team_credits']));
  set('Locations', names(issue['location_credits']));
  set('StoryArc', names(issue['story_arc_credits']));
  set('Web', _str(issue['site_detail_url']));

  // Roles come as one string per person: "writer, penciler, cover".
  final credits = <(String, String)>[];
  if (issue['person_credits'] case final List<Object?> list) {
    for (final c in list) {
      if (c is! Map) continue;
      final person = _str(c['name']);
      if (person == null) continue;
      for (final role in '${c['role'] ?? ''}'.split(',')) {
        credits.add((person, role));
      }
    }
  }
  creditsByField(credits)
      .forEach((field, people) => set(field, people.join(', ')));

  setTaggedNote(
    doc,
    source: 'Comic Vine',
    marker: '[Issue ID ${issue['id']}]',
    isOwnLine: (l) => l.contains('[Issue ID ') || l.contains('[CVDB'),
    now: now,
  );
}

/// Comic Vine descriptions are HTML: keeps the text and paragraph breaks,
/// drops tables (cover credits lists) and their headings.
String? htmlToText(String? html) {
  if (html == null) return null;
  var s = html
      .replaceAll(
        RegExp(
          r'(<h\d[^>]*>[^<]*</h\d>\s*)?<table.*?</table>',
          dotAll: true,
          caseSensitive: false,
        ),
        '',
      )
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(
        RegExp(r'</(p|div|h\d|li|ul|ol)>', caseSensitive: false),
        '\n',
      )
      .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '• ')
      .replaceAll(RegExp(r'<[^>]+>'), '');
  const entities = {
    '&amp;': '&',
    '&lt;': '<',
    '&gt;': '>',
    '&quot;': '"',
    '&#39;': "'",
    '&apos;': "'",
    '&nbsp;': ' ',
  };
  entities.forEach((e, c) => s = s.replaceAll(e, c));
  s = s.replaceAllMapped(
    RegExp(r'&#(\d+);'),
    (m) => String.fromCharCode(int.parse(m[1]!)),
  );
  final text = s
      .split('\n')
      .map((l) => l.trim())
      .join('\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
  return text.isEmpty ? null : text;
}

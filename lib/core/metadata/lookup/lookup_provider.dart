import '../comic_info_document.dart';
import 'lookup_cache.dart';

/// An issue a provider found.
class IssueCandidate {
  const IssueCandidate({
    required this.provider,
    required this.id,
    required this.number,
    required this.seriesName,
    this.displayName = '',
    this.seriesId,
    this.seriesYearBegan,
    this.coverDate,
    this.storeDate,
    this.publisher,
    this.seriesAliases,
    this.image,
  });

  /// The [LookupProvider] that found it.
  final LookupProvider provider;
  final int id;
  final String number;
  final String seriesName;

  /// The provider's own label, e.g. "Chainkata (2026) #1".
  final String displayName;
  final int? seriesId;
  final int? seriesYearBegan;
  final DateTime? coverDate;
  final DateTime? storeDate;
  final String? publisher;

  /// Other names the series goes by, when the search gave them (null:
  /// unknown, [LookupProvider.seriesAliases] can fetch them).
  final List<String>? seriesAliases;

  /// Cover image URL.
  final String? image;

  String get label =>
      displayName.isNotEmpty ? displayName : '$seriesName #$number';
}

/// What [LookupProvider.findIssue] found: every result seen (best first),
/// and the match if any; [sure] when its series has the comic's own name.
typedef LookupSearch = ({
  List<IssueCandidate> results,
  IssueCandidate? match,
  bool sure,
});

/// A source of comic details (Metron, Comic Vine, …).
///
/// A provider only has to search and fetch; how a comic is matched (which
/// forms of its name are tried, when a match is sure) is shared, in
/// [findIssue].
abstract class LookupProvider {
  /// Stable ID, for settings and cache keys ("metron").
  String get id;

  /// Shown to the user ("Metron").
  String get name;

  LookupCache get cache;

  /// Time between requests (for estimating how long a batch takes).
  Duration get requestSpacing;

  /// Issues of series named like [query], with [number] if given (first
  /// page of results).
  Future<List<IssueCandidate>> search(String query, String? number);

  /// Whether [search] for these is answered from the cache (costs nothing).
  bool searchCached(String query, String? number);

  /// Issues of a known series.
  Future<List<IssueCandidate>> searchSeries(int seriesId, String? number);

  /// Other names [c]'s series goes by (may cost a request).
  Future<List<String>> seriesAliases(IssueCandidate c);

  /// This provider's issue ID if [doc] records one (from us or another
  /// tagger), else null.
  int? knownId(ComicInfoDocument doc);

  /// Fetches issue [issueId] and writes its details into [doc]; fields the
  /// provider has no value for are left as they were.
  Future<void> apply(ComicInfoDocument doc, int issueId, {DateTime? now});

  /// At most this many name searches per [findIssue].
  static const maxSearches = 6;

  /// Finds the issue that is [series] #[number] (from [year], published by
  /// [publisher]), trying more forms of the name only while nothing fits:
  ///
  /// 0. A series this name was matched to before: one search by its ID.
  /// 1. The name as written.
  /// 2. The same words written differently (`2000AD` → `2000 AD`, `A - B`
  ///    → `A: B`): still the same name, so a match is **sure**.
  /// 3. Shorter names (words dropped from the end, the last half of
  ///    `A - B`): only a **likely** match, unless the provider lists the
  ///    comic's name among the series' other names.
  ///
  /// No words are special: the file name decides which forms are tried, and
  /// the provider's answers decide which fit ([chooseMatch]).
  Future<LookupSearch> findIssue({
    required String series,
    String? number,
    int? year,
    String? publisher,
  }) async {
    final name = normalizeName(series);
    final memoryKey = '$id|$name';
    if (cache.seriesFor(memoryKey) case final sid?
        when !searchCached(series, number)) {
      final r = await searchSeries(sid, number);
      final m = chooseMatch(
        r,
        series: null,
        number: number,
        year: year,
        publisher: publisher,
      );
      if (m != null) return (results: _bestFirst(r, m), match: m, sure: true);
    }

    final all = <IssueCandidate>[];
    IssueCandidate? likely;
    var searches = 0;
    for (final (query, sameName) in searchForms(series)) {
      if (searches++ >= maxSearches) break;
      final r = await search(query, number);
      for (final x in r) {
        if (!all.any((y) => y.id == x.id)) all.add(x);
      }
      final sure = chooseMatch(
        all,
        series: series,
        number: number,
        year: year,
        publisher: publisher,
      );
      if (sure != null) {
        rememberSeries(series, sure);
        return (results: _bestFirst(all, sure), match: sure, sure: true);
      }
      if (!sameName) {
        likely = chooseMatch(
          r,
          series: query,
          number: number,
          year: year,
          publisher: publisher,
        );
        if (likely != null) break;
      }
    }
    if (likely != null) {
      final aliases = await seriesAliases(likely);
      if (aliases.any((a) => normalizeName(a) == name)) {
        rememberSeries(series, likely);
        return (results: _bestFirst(all, likely), match: likely, sure: true);
      }
    }
    return (results: _bestFirst(all, likely), match: likely, sure: false);
  }

  /// [series] (a name from a file) is [match]'s series: later issues are
  /// found by its ID.
  void rememberSeries(String series, IssueCandidate match) {
    if (match.seriesId case final sid?) {
      cache.rememberSeries('$id|${normalizeName(series)}', sid);
    }
  }

  static List<IssueCandidate> _bestFirst(
    List<IssueCandidate> all,
    IssueCandidate? best,
  ) => [?best, ...all.where((r) => r != best)];
}

/// The names [LookupProvider.findIssue] searches for, in order, each with
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
  final words = series.split(RegExp(r'\s+'));
  for (var n = words.length - 1; n >= 1; n--) {
    final shorter = words
        .take(n)
        .join(' ')
        .replaceAll(RegExp(r'[\s\-:]+$'), '');
    add(shorter, false);
    add(spaced(shorter), false);
  }
  if (parts.length > 1) add(parts.last, false);
  return out;
}

/// A series name for comparing: lower case, letters and digits only, "&"
/// as "and", no leading "The".
String normalizeName(String s) => s
    .toLowerCase()
    .replaceAll('&', 'and')
    .replaceAll(RegExp(r'^the\s+'), '')
    .replaceAll(RegExp(r'[^a-z0-9]'), '');

String _normNumber(String n) {
  final t = n.trim().toLowerCase().replaceFirst(RegExp(r'^0+(?=\d)'), '');
  return t.isEmpty ? '0' : t;
}

/// The one result that is this comic: its series is named [series] (or
/// lists it among its other names; any series when null), same [number],
/// and, if [year] is known, a cover, store or series-start year within a
/// year of it. If several fit, [publisher] (when known) and then the exact
/// year decide. Null when none or still several fit (the user picks).
IssueCandidate? chooseMatch(
  List<IssueCandidate> results, {
  required String? series,
  required String? number,
  int? year,
  String? publisher,
}) {
  final name = series == null ? null : normalizeName(series);
  bool named(IssueCandidate r) =>
      name == null ||
      normalizeName(r.seriesName) == name ||
      (r.seriesAliases ?? const []).any((a) => normalizeName(a) == name);
  var fits = [
    for (final r in results)
      if (named(r) &&
          (number == null || _normNumber(r.number) == _normNumber(number)))
        r,
  ];
  if (year != null) {
    bool near(int? y) => y != null && (y - year).abs() <= 1;
    fits = [
      for (final r in fits)
        if (near(r.coverDate?.year) ||
            near(r.storeDate?.year) ||
            near(r.seriesYearBegan))
          r,
    ];
  }
  if (fits.length == 1) return fits.single;
  if (fits.isEmpty) return null;
  if (publisher != null) {
    final p = normalizeName(publisher);
    final same = [
      for (final r in fits)
        if (r.publisher != null && normalizeName(r.publisher!) == p) r,
    ];
    if (same.length == 1) return same.single;
    if (same.isNotEmpty) fits = same;
  }
  if (year != null) {
    final exact = [
      for (final r in fits)
        if (r.coverDate?.year == year || r.storeDate?.year == year) r,
    ];
    if (exact.length == 1) return exact.single;
  }
  return null;
}

/// Writes "Tagged with Panelist using info from [source] on (day).
/// [marker]" into Notes, replacing lines an earlier tag from the same source left
/// ([isOwnLine]) but keeping any other notes.
void setTaggedNote(
  ComicInfoDocument doc, {
  required String source,
  required String marker,
  required bool Function(String line) isOwnLine,
  DateTime? now,
}) {
  final day = (now ?? DateTime.now()).toIso8601String().substring(0, 10);
  final line = 'Tagged with Panelist using info from $source on $day. $marker';
  final kept = (doc['Notes'] ?? '')
      .split('\n')
      .where((l) => !isOwnLine(l) && l.trim().isNotEmpty)
      .join('\n');
  doc['Notes'] = kept.isEmpty ? line : '$kept\n$line';
}

/// Credits by ComicInfo field, from (person, role) pairs; roles are matched
/// case-insensitively against [roleNames].
Map<String, List<String>> creditsByField(
  Iterable<(String person, String role)> credits,
) {
  final byField = <String, List<String>>{};
  for (final (person, role) in credits) {
    final r = role.trim().toLowerCase();
    for (final MapEntry(key: field, value: names) in roleNames.entries) {
      if (names.contains(r)) {
        final list = byField[field] ??= [];
        if (!list.contains(person)) list.add(person);
      }
    }
  }
  return byField;
}

/// Role names providers use, per ComicInfo credit field. "Artist" counts as
/// both pencils and inks.
const roleNames = {
  'Writer': ['writer', 'script', 'story', 'plot', 'scripter'],
  'Penciller': [
    'penciller',
    'penciler',
    'pencils',
    'artist',
    'illustrator',
    'layouts',
  ],
  'Inker': ['inker', 'inks', 'artist', 'finishes'],
  'Colorist': ['colorist', 'colors', 'colourist', 'colours'],
  'Letterer': ['letterer', 'letters'],
  'CoverArtist': ['cover', 'cover artist'],
  'Editor': ['editor', 'editor in chief', 'senior editor', 'group editor'],
  'Translator': ['translator'],
};

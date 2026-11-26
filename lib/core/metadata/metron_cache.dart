import 'dart:convert';
import 'dart:io';

/// Metron answers kept between runs, so looking the same comics up again
/// costs no requests, plus which Metron series a name from a file turned out
/// to be. Kept in one JSON file (in memory only when [file] is null).
class MetronCache {
  MetronCache({this.file, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final File? file;
  final DateTime Function() _clock;

  /// Answers older than this are dropped when the file is loaded.
  static const keep = Duration(days: 30);

  final _answers = <String, ({int at, Object? body})>{};
  final _series = <String, int>{};
  bool _loaded = false;

  /// The stored answer for [uri] if younger than [maxAge], else null (a
  /// record, so a stored null is still a hit).
  ({Object? body})? get(Uri uri, Duration maxAge) {
    _load();
    final a = _answers['$uri'];
    if (a == null) return null;
    final age = _clock().millisecondsSinceEpoch - a.at;
    return age <= maxAge.inMilliseconds ? (body: a.body) : null;
  }

  void put(Uri uri, Object? body) {
    _load();
    _answers['$uri'] = (at: _clock().millisecondsSinceEpoch, body: body);
    _save();
  }

  /// The Metron series ID a (normalised) series name from a file was
  /// found to be.
  int? seriesFor(String name) {
    _load();
    return _series[name];
  }

  void rememberSeries(String name, int id) {
    _load();
    if (_series[name] == id) return;
    _series[name] = id;
    _save();
  }

  void _load() {
    if (_loaded) return;
    _loaded = true;
    final f = file;
    if (f == null || !f.existsSync()) return;
    try {
      final json = jsonDecode(f.readAsStringSync()) as Map<String, Object?>;
      final cutoff = _clock().subtract(keep).millisecondsSinceEpoch;
      final answers = json['answers'] as Map<String, Object?>? ?? const {};
      answers.forEach((uri, v) {
        if (v is Map && v['at'] is int && (v['at']! as int) >= cutoff) {
          _answers[uri] = (at: v['at']! as int, body: v['body']);
        }
      });
      final series = json['series'] as Map<String, Object?>? ?? const {};
      series.forEach((name, id) {
        if (id is int) _series[name] = id;
      });
    } on Object {
      // A damaged cache is just an empty one.
    }
  }

  void _save() {
    final f = file;
    if (f == null) return;
    try {
      f.parent.createSync(recursive: true);
      final tmp = File('${f.path}.tmp')
        ..writeAsStringSync(
          jsonEncode({
            'answers': {
              for (final MapEntry(:key, :value) in _answers.entries)
                key: {'at': value.at, 'body': value.body},
            },
            'series': _series,
          }),
        );
      tmp.renameSync(f.path);
    } on FileSystemException {
      // Not being able to cache only costs requests.
    }
  }
}

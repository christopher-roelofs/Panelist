import 'package:path/path.dart' as p;

/// Series, issue number and year guessed from a comic's file or folder
/// name, for comics without ComicInfo.xml.
///
/// Handles the common naming styles:
/// `Locke & Key - Welcome to Lovecraft #001 (2008).cbz`,
/// `Atomic_War_001.cbr`, `Saga 054 (2018) (Digital) (Zone-Empire).cbr`,
/// `If_an_A_Bomb_falls_1951.pdf`, and folders like `Eight Billion Genies
/// (2022)`.
class ComicName {
  const ComicName({this.series, this.number, this.year});

  final String? series;

  /// Issue number without leading zeros (`"1"`, `"12.5"`, `"3a"`).
  final String? number;
  final int? year;

  static final _year = RegExp(r'[(\[]((?:19|20)\d\d)[)\]]');
  static final _groups = RegExp(r'\([^)]*\)|\[[^\]]*\]|\{[^}]*\}');
  static final _hash = RegExp(
    r'#\s*(\d+(?:\.\d+)?[a-z]?)\b',
    caseSensitive: false,
  );
  static final _trailing = RegExp(r'(?:^|\s)(\d{1,4}(?:\.\d+)?)$');
  static final _bareYear = RegExp(r'^(?:19|20)\d\d$');
  static final _spaces = RegExp(r'\s+');
  static final _edgeJunk = RegExp(r'^[\s\-–—:,.]+|[\s\-–—:,.]+$');

  /// Parses a file name (extension is dropped) or folder name.
  static ComicName parse(String name, {bool isFolder = false}) {
    var s = isFolder ? name : p.basenameWithoutExtension(name);
    if (!s.contains(' ')) s = s.replaceAll(RegExp(r'[_.]'), ' ');
    s = s.replaceAll('_', ' ');

    int? year;
    final y = _year.firstMatch(s);
    if (y != null) year = int.parse(y.group(1)!);
    s = s.replaceAll(_groups, ' ').replaceAll(_spaces, ' ').trim();

    String? number;
    final h = _hash.firstMatch(s);
    if (h != null) {
      number = h.group(1);
      s = s.substring(0, h.start);
    } else if (!isFolder) {
      final t = _trailing.firstMatch(s);
      if (t != null) {
        final n = t.group(1)!;
        if (_bareYear.hasMatch(n) && year == null) {
          year = int.parse(n);
        } else if (!_bareYear.hasMatch(n) || year != null) {
          number = n;
        }
        s = s.substring(0, t.start);
      }
    }

    final series = s.replaceAll(_edgeJunk, '');
    return ComicName(
      series: series.isEmpty ? null : series,
      number: number == null ? null : _trimZeros(number),
      year: year,
    );
  }

  static String _trimZeros(String n) {
    final t = n.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    return t.isEmpty ? '0' : t;
  }
}

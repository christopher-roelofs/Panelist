/// Compares strings the way humans expect page files to be ordered:
/// `page2.jpg` < `page10.jpg`, case-insensitive, with numeric runs compared
/// by value (arbitrary length, leading zeros ignored).
int naturalCompare(String a, String b) {
  final ta = _tokenize(a.toLowerCase());
  final tb = _tokenize(b.toLowerCase());
  for (var i = 0; i < ta.length && i < tb.length; i++) {
    final x = ta[i];
    final y = tb[i];
    final xNum = _isDigit(x.codeUnitAt(0));
    final yNum = _isDigit(y.codeUnitAt(0));
    int c;
    if (xNum && yNum) {
      c = _compareNumeric(x, y);
    } else if (xNum != yNum) {
      // Numbers sort before text ("1.jpg" before "a.jpg").
      c = xNum ? -1 : 1;
    } else {
      c = x.compareTo(y);
    }
    if (c != 0) return c;
  }
  final c = ta.length.compareTo(tb.length);
  // Fully equal ignoring case/zeros: fall back to a stable, exact ordering.
  return c != 0 ? c : a.compareTo(b);
}

bool _isDigit(int c) => c >= 0x30 && c <= 0x39;

List<String> _tokenize(String s) {
  final out = <String>[];
  if (s.isEmpty) return out;
  var start = 0;
  var digit = _isDigit(s.codeUnitAt(0));
  for (var i = 1; i < s.length; i++) {
    final d = _isDigit(s.codeUnitAt(i));
    if (d != digit) {
      out.add(s.substring(start, i));
      start = i;
      digit = d;
    }
  }
  out.add(s.substring(start));
  return out;
}

int _compareNumeric(String x, String y) {
  final a = _stripZeros(x);
  final b = _stripZeros(y);
  if (a.length != b.length) return a.length.compareTo(b.length);
  return a.compareTo(b);
}

String _stripZeros(String s) {
  var i = 0;
  while (i < s.length - 1 && s.codeUnitAt(i) == 0x30) {
    i++;
  }
  return s.substring(i);
}

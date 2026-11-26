/// File names from a comic's details, by a template such as
/// `{publisher}/{series} ({volume})/{series} {number:3} ({year})`.
///
/// Fields: `{series}`, `{number}` (`{number:3}` pads it to 3 digits),
/// `{year}`, `{volume}`, `{publisher}`, `{title}` (`{title:40}` shortens it
/// to about 40 characters at a word). A `/` makes folders. A field with no
/// value drops out, with the brackets around it and any separator left
/// dangling; a folder that ends up empty is left out.
library;

const defaultRenameTemplate = '{series} {number:3} ({year})';

const renameFields = [
  'series',
  'number',
  'year',
  'volume',
  'publisher',
  'title',
];

/// Why a template can't be used, or null if it's fine.
String? checkTemplate(String template) {
  if (template.trim().isEmpty) return 'Enter a template';
  for (final m in RegExp(r'\{([^}]*)\}').allMatches(template)) {
    final parts = m[1]!.split(':');
    if (!renameFields.contains(parts.first)) {
      return 'Unknown field {${parts.first}}';
    }
    if (parts.length > 2 ||
        (parts.length == 2 && int.tryParse(parts[1]) == null)) {
      return 'Write {${parts.first}:N} with a number N';
    }
  }
  if (template.replaceAll(RegExp(r'\{[^}]*\}'), '').contains(RegExp('[{}]'))) {
    return 'Unmatched { or }';
  }
  if (!template.split('/').last.contains('{')) {
    return 'The file name part needs at least one field';
  }
  return null;
}

/// [template] filled from [values]: `/`-separated folders and a file name
/// (no extension), or null if none of the file name's fields has a value.
String? renderTemplate(String template, Map<String, String?> values) {
  final field = RegExp(r'\{(\w+)(?::(\d+))?\}');
  String? valueOf(Match m) {
    final v = values[m[1]]?.trim();
    return v == null || v.isEmpty ? null : v;
  }

  final parts = template.split('/');
  if (!field.allMatches(parts.last).any((m) => valueOf(m) != null)) {
    return null;
  }
  final segments = <String>[];
  for (final segment in parts) {
    final fields = field.allMatches(segment).toList();
    // A folder whose fields all have no value is left out.
    if (fields.isNotEmpty && fields.every((m) => valueOf(m) == null)) {
      continue;
    }
    final filled = segment.replaceAllMapped(field, (m) {
      final raw = valueOf(m);
      if (raw == null) return '\u0000';
      final n = m[2] == null ? null : int.parse(m[2]!);
      return _safe(switch (m[1]) {
        'number' when n != null => _pad(raw, n),
        'title' when n != null => _shorten(raw, n),
        _ => raw,
      });
    });
    final out = _tidy(filled);
    if (out.isNotEmpty) segments.add(out);
  }
  return segments.isEmpty ? null : segments.join('/');
}

/// Leading digits padded with zeros: `1` → `001`, `1.5` → `001.5`.
String _pad(String number, int width) => number.replaceFirstMapped(
  RegExp(r'^\d+'),
  (m) => m[0]!.padLeft(width, '0'),
);

/// At most about [max] characters, cut at a word.
String _shorten(String s, int max) {
  if (s.length <= max) return s;
  final cut = s.substring(0, max);
  final space = cut.lastIndexOf(RegExp(r'[\s;,]'));
  return (space > max ~/ 2 ? cut.substring(0, space) : cut).replaceAll(
    RegExp(r'[\s;,:\-]+$'),
    '',
  );
}

/// A value made safe in a file name on Linux, Windows and macOS.
String _safe(String s) => s
    .replaceAll(RegExp(r'\s*:\s*'), ' - ')
    .replaceAll(RegExp(r'[/\\]'), '-')
    .replaceAll(RegExp(r'[*?"<>|\x00-\x1f]'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Removes what missing fields (marked \0) leave behind: empty brackets,
/// doubled spaces, separators at the ends.
String _tidy(String s) {
  var t = s;
  t = t.replaceAll(RegExp(r'\(\s*\u0000\s*\)|\[\s*\u0000\s*\]'), '');
  t = t.replaceAll(RegExp(r'#\s*\u0000'), '');
  t = t.replaceAll('\u0000', '');
  t = t.replaceAll(RegExp(r'\(\s*\)|\[\s*\]'), '');
  t = t.replaceAll(RegExp(r'\s+'), ' ');
  t = t.replaceAllMapped(RegExp(r'\s+([,.)\]])'), (m) => m[1]!);
  t = t.replaceAll(RegExp(r'^[\s\-–,.#]+|[\s\-–,#]+$'), '');
  // Windows refuses names ending in a dot or space.
  t = t.replaceAll(RegExp(r'[.\s]+$'), '');
  if (t.length > 150) t = t.substring(0, 150).trimRight();
  // Names Windows reserves for devices (`CON`, `AUX`, `COM1`…), also with
  // an extension after them.
  if (_reserved.hasMatch(t)) t = '${t}_';
  return t;
}

final _reserved = RegExp(
  r'^(con|prn|aux|nul|com[0-9¹²³]|lpt[0-9¹²³])(\..*)?$',
  caseSensitive: false,
);

/// The fields in [template] that have no value in [values], in order.
List<String> missingFields(String template, Map<String, String?> values) => {
  for (final m in RegExp(r'\{(\w+)(?::\d+)?\}').allMatches(template))
    if ((values[m[1]]?.trim() ?? '').isEmpty) m[1]!,
}.toList();

/// What a template makes of a comic that has every field.
const sampleValues = {
  'series': 'Saga',
  'number': '1',
  'year': '2012',
  'volume': '2012',
  'publisher': 'Image Comics',
  'title': 'Chapter One',
};

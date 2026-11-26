import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../core/metadata/lookup/lookup_provider.dart' show normalizeName;

const publisherAliasesKey = 'publisher.aliases';

/// The user's publisher names: each rule maps a name as written (compared
/// ignoring case and punctuation) to the name to use. None to start with:
/// the user adds them, or accepts [suggestAliases].
class PublisherAliases {
  const PublisherAliases([this.rules = const {}]);

  factory PublisherAliases.decode(String? json) {
    if (json == null || json.isEmpty) return const PublisherAliases();
    try {
      final m = jsonDecode(json);
      if (m is Map) {
        return PublisherAliases({
          for (final e in m.entries)
            if (e.key is String && e.value is String)
              e.key as String: e.value as String,
        });
      }
    } on FormatException {
      // Unreadable: start over.
    }
    return const PublisherAliases();
  }

  /// From → to, as the user wrote them.
  final Map<String, String> rules;

  String encode() => jsonEncode(rules);

  /// The name to use for [name] (null stays null).
  String? apply(String? name) {
    if (name == null) return null;
    final n = normalizeName(name);
    for (final MapEntry(key: from, value: to) in rules.entries) {
      if (normalizeName(from) == n) return to;
    }
    return name;
  }

  PublisherAliases withRule(String from, String to) =>
      PublisherAliases({...rules, from.trim(): to.trim()});

  PublisherAliases without(String from) =>
      PublisherAliases({...rules}..remove(from));
}

/// Rules worth adding, from the names in a library ([counts]: how many
/// comics use each name). Two names are one publisher when they're the same
/// ignoring case and punctuation (`IDW Publishing`, `Idw publishing`), or
/// one is the other with words added (`Image` and `Image Comics`). The name
/// more comics use wins (the longer one on a tie). Names already covered
/// by [existing] aren't suggested.
List<(String from, String to)> suggestAliases(
  Map<String, int> counts, {
  PublisherAliases existing = const PublisherAliases(),
}) {
  final names = [
    for (final n in counts.keys)
      if (existing.apply(n) == n &&
          !existing.rules.keys.any((k) => normalizeName(k) == normalizeName(n)))
        n,
  ];
  List<String> words(String s) => s
      .toLowerCase()
      .replaceAll('&', 'and')
      .split(RegExp(r'[^a-z0-9]+'))
      .where((w) => w.isNotEmpty)
      .toList();
  bool startsWith(List<String> a, List<String> b) {
    if (b.length > a.length) return false;
    for (var i = 0; i < b.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool same(String a, String b) {
    if (normalizeName(a) == normalizeName(b)) return true;
    final wa = words(a), wb = words(b);
    return wa.isNotEmpty &&
        wb.isNotEmpty &&
        (startsWith(wa, wb) || startsWith(wb, wa));
  }

  int better(String a, String b) {
    final c = (counts[b] ?? 0) - (counts[a] ?? 0);
    return c != 0 ? c : b.length - a.length;
  }

  // Join names into groups of the same publisher.
  final groups = <List<String>>[];
  for (final n in names) {
    final g = groups.where((g) => g.any((m) => same(m, n))).firstOrNull;
    g == null ? groups.add([n]) : g.add(n);
  }
  final out = <(String, String)>[];
  for (final g in groups.where((g) => g.length > 1)) {
    g.sort(better);
    for (final from in g.skip(1)) {
      out.add((from, g.first));
    }
  }
  return out;
}

/// The saved rules.
final publisherAliasesProvider = FutureProvider<PublisherAliases>(
  (ref) async => PublisherAliases.decode(
    await ref.watch(databaseProvider).setting(publisherAliasesKey),
  ),
);

Future<void> savePublisherAliases(WidgetRef ref, PublisherAliases a) async {
  await ref.read(databaseProvider).setSetting(publisherAliasesKey, a.encode());
  ref.invalidate(publisherAliasesProvider);
}

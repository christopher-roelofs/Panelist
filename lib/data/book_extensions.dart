import 'dart:convert';
import 'dart:ui' show Size;

import 'package:drift/drift.dart' show Value;

import '../core/metadata/comic_info.dart';
import '../reader/reader_settings.dart';
import 'database.dart';

extension BookX on Book {
  /// "Series #Number" when ComicInfo provides a series, else the file title.
  String get displayTitle {
    final s = series;
    if (s == null) return title;
    final n = number;
    return n == null ? s : '$s #$n';
  }

  /// This book's settings, with unset fields taken from [defaults].
  ReaderSettings settingsOver(ReaderSettings defaults) => ReaderSettings.parse(
    fit: fitMode,
    layout: layoutMode,
    coverAlone: coverAlone,
    fallback: defaults,
  );

  /// Cached page sizes, or null if missing or stale.
  List<Size?>? get cachedPageSizes {
    final json = pageSizes;
    if (json == null) return null;
    try {
      final list = jsonDecode(json) as List<Object?>;
      if (list.length != pageCount) return null;
      return [
        for (final e in list)
          e is List && e.length == 2
              ? Size((e[0]! as num).toDouble(), (e[1]! as num).toDouble())
              : null,
      ];
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }
}

String encodePageSizes(List<Size?> sizes) => jsonEncode([
  for (final s in sizes) s == null ? null : [s.width, s.height],
]);

BooksCompanion metadataFrom(ComicInfo info) => BooksCompanion(
  series: Value(info.series),
  number: Value(info.number),
  year: Value(info.year),
  writer: Value(info.writer),
  artist: Value(info.artist),
  summary: Value(info.summary),
  rightToLeft: Value(info.rightToLeft),
);

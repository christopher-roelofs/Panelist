import 'dart:ui';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panelist/core/metadata/comic_info.dart';
import 'package:panelist/data/book_extensions.dart';
import 'package:panelist/data/database.dart';
import 'package:panelist/reader/fit_mode.dart';
import 'package:panelist/reader/reader_settings.dart';
import 'package:panelist/reader/spreads.dart';

void main() {
  late AppDatabase db;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<Book> book() =>
      db.recordOpened(id: 'b', path: '/b', title: 'file', pageCount: 3);

  test('display title prefers series and number', () async {
    expect((await book()).displayTitle, 'file');
    await db.saveMetadata(
      'b',
      metadataFrom(const ComicInfo(series: 'Atomic War', number: '1')),
    );
    expect((await db.book('b'))!.displayTitle, 'Atomic War #1');
  });

  test('page sizes round-trip and stale caches are ignored', () async {
    await book();
    await db.savePageSizes(
      'b',
      encodePageSizes([const Size(1, 2), null, const Size(3, 4)]),
    );
    expect((await db.book('b'))!.cachedPageSizes, [
      const Size(1, 2),
      null,
      const Size(3, 4),
    ]);
    await db.savePageSizes('b', encodePageSizes([const Size(1, 2)]));
    expect((await db.book('b'))!.cachedPageSizes, isNull); // wrong length
  });

  test('per-book settings override defaults field by field', () async {
    const defaults = ReaderSettings(fit: FitMode.height);
    expect((await book()).settingsOver(defaults), defaults);
    await db.saveBookSettings(
      'b',
      fitMode: 'width',
      layoutMode: 'single',
      coverAlone: false,
    );
    expect(
      (await db.book('b'))!.settingsOver(defaults),
      const ReaderSettings(
        fit: FitMode.width,
        layout: LayoutMode.single,
        coverAlone: false,
      ),
    );
  });
}

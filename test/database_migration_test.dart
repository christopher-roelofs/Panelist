import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panelist/data/database.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  test('v1 database upgrades to v2 keeping books', () async {
    // The exact v1 schema shipped in M1/M2.
    final executor = NativeDatabase.memory(
      setup: (raw) {
        raw.execute('''
          CREATE TABLE books (
            id TEXT NOT NULL, path TEXT NOT NULL, title TEXT NOT NULL,
            page_count INTEGER NOT NULL,
            current_page INTEGER NOT NULL DEFAULT 0,
            last_opened INTEGER NOT NULL, cover BLOB NULL,
            PRIMARY KEY (id));
          CREATE TABLE settings (
            "key" TEXT NOT NULL, value TEXT NOT NULL, PRIMARY KEY ("key"));
          INSERT INTO books VALUES ('b', '/b.cbz', 'B', 10, 4, 0, NULL);
          PRAGMA user_version = 1;
        ''');
      },
    );
    final db = AppDatabase(executor);
    addTearDown(db.close);

    final book = (await db.book('b'))!;
    expect(book.currentPage, 4);
    expect(book.series, isNull);
    expect(book.fitMode, isNull);

    await db.saveBookSettings(
      'b',
      fitMode: 'width',
      layoutMode: 'double',
      coverAlone: false,
    );
    final updated = (await db.book('b'))!;
    expect(updated.fitMode, 'width');
    expect(updated.coverAlone, isFalse);
  });

  test('v2 database upgrades to v3 with an empty library', () async {
    final executor = NativeDatabase.memory(
      setup: (raw) {
        raw.execute('''
          CREATE TABLE books (
            id TEXT NOT NULL, path TEXT NOT NULL, title TEXT NOT NULL,
            page_count INTEGER NOT NULL,
            current_page INTEGER NOT NULL DEFAULT 0,
            last_opened INTEGER NOT NULL, cover BLOB NULL,
            series TEXT NULL, number TEXT NULL, year INTEGER NULL,
            writer TEXT NULL, artist TEXT NULL, summary TEXT NULL,
            right_to_left INTEGER NULL, page_sizes TEXT NULL,
            fit_mode TEXT NULL, layout_mode TEXT NULL, cover_alone INTEGER NULL,
            PRIMARY KEY (id));
          CREATE TABLE settings (
            "key" TEXT NOT NULL, value TEXT NOT NULL, PRIMARY KEY ("key"));
          INSERT INTO books (id, path, title, page_count, current_page,
            last_opened, series) VALUES ('b', '/b.cbz', 'B', 10, 4, 0, 'S');
          PRAGMA user_version = 2;
        ''');
      },
    );
    final db = AppDatabase(executor);
    addTearDown(db.close);

    final book = (await db.book('b'))!;
    expect((book.currentPage, book.series, book.publisher), (4, 'S', null));
    expect(await db.roots(), isEmpty);
    await db.addRoot('/comics', 'comics');
    expect((await db.roots()).single.name, 'comics');
    expect(await db.watchProgress().first, {
      'b': (currentPage: 4, pageCount: 10),
    });
  });
}

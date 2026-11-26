import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panelist/data/database.dart';

void main() {
  late AppDatabase db;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<Book> open(String id, {String path = '/a.cbz', int pages = 20}) =>
      db.recordOpened(id: id, path: path, title: id, pageCount: pages);

  test('reopening keeps progress and cover but updates path', () async {
    await open('book');
    await db.saveProgress('book', 7);
    await db.saveCover('book', Uint8List.fromList([1, 2, 3]));

    final again = await open('book', path: '/moved/a.cbz');
    expect(again.currentPage, 7);
    expect(again.cover, [1, 2, 3]);
    expect(again.path, '/moved/a.cbz');
  });

  test('a comic saved to a new address keeps its entry and progress', () async {
    await db.addRoot('content://tree', 'Comics');
    final root = (await db.roots()).single.id;
    await db.putEntry(
      LibraryEntriesCompanion.insert(
        location: 'content://old',
        rootId: root,
        folder: 'Saga',
        fileName: 'a.cbz',
        size: 1,
        modified: 0,
      ),
    );
    await open('book', path: 'content://old');
    await db.saveProgress('book', 7);

    await db.relocate('content://old', 'content://new');
    expect(await db.entryAt('content://old'), isNull);
    expect((await db.entryAt('content://new'))!.folder, 'Saga');
    final book = (await db.book('book'))!;
    expect((book.path, book.currentPage), ('content://new', 7));
  });

  test('recents are ordered by last opened and can be forgotten', () async {
    await open('first');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await open('second');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await open('first');

    var recents = await db.watchRecent().first;
    expect(recents.map((b) => b.id), ['first', 'second']);

    await db.removeFromRecent('first');
    recents = await db.watchRecent().first;
    expect(recents.map((b) => b.id), ['second']);
  });

  test('settings round-trip', () async {
    expect(await db.setting('k'), isNull);
    await db.setSetting('k', 'a');
    await db.setSetting('k', 'b');
    expect(await db.setting('k'), 'b');
  });
}

import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panelist/data/database.dart';
import 'package:panelist/platform/comic_files.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('comic_files_'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('a rewrite replaces the file and leaves nothing behind', () async {
    final f = File(p.join(dir.path, 'a.cbz'))..writeAsStringSync('old');
    final n = await ComicFiles.rewrite(f.path, (source, target) async {
      expect(File(source).readAsStringSync(), 'old');
      File(target).writeAsStringSync('new');
      return 7;
    });
    expect(n, 7);
    expect(f.readAsStringSync(), 'new');
    expect(dir.listSync(), hasLength(1));
  });

  test('a failed rewrite keeps the original', () async {
    final f = File(p.join(dir.path, 'a.cbz'))..writeAsStringSync('old');
    await expectLater(
      ComicFiles.rewrite(f.path, (source, target) async {
        File(target).writeAsStringSync('half');
        throw StateError('broke');
      }),
      throwsStateError,
    );
    expect(f.readAsStringSync(), 'old');
    expect(dir.listSync(), hasLength(1));
  });

  test('names of Android documents, for messages', () {
    expect(
      ComicFiles.nameOf(
        'content://com.android.externalstorage.documents/tree/primary%3AComics'
        '/document/primary%3AComics%2FSaga%2FSaga%20001.cbz',
      ),
      'Saga 001.cbz',
    );
    expect(ComicFiles.nameOf('/c/Saga/Saga 001.cbz'), 'Saga 001.cbz');
  });

  test('a library comic’s folder and path inside it', () async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.addRoot('content://x/tree/t', 'Comics');
    final root = (await db.roots()).single;
    for (final (loc, folder, name) in [
      ('content://x/tree/t/document/1', 'Saga/2012', 'Saga 001.cbz'),
      ('content://x/tree/t/document/2', '', 'Top.cbz'),
    ]) {
      await db.putEntry(
        LibraryEntriesCompanion.insert(
          location: loc,
          rootId: root.id,
          folder: folder,
          fileName: name,
          size: 1,
          modified: 0,
        ),
      );
    }
    expect(await db.placeInLibrary('content://x/tree/t/document/1'), (
      root: 'content://x/tree/t',
      path: 'Saga/2012/Saga 001.cbz',
    ));
    expect(
      (await db.placeInLibrary('content://x/tree/t/document/2'))?.path,
      'Top.cbz',
    );
    expect(await db.placeInLibrary('content://x/tree/t/document/3'), isNull);
  });
}

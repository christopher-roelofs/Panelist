import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panelist/core/metadata/comic_info.dart';
import 'package:panelist/data/database.dart';
import 'package:panelist/library/bulk_field_editor.dart';
import 'package:panelist/library/library_model.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory dir;
  late AppDatabase db;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  setUp(() {
    dir = Directory.systemTemp.createTempSync('panelist_bulk');
    db = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  LibraryComic cbz(String name, {String? publisher}) {
    final archive = Archive()
      ..addFile(ArchiveFile.bytes('01.jpg', Uint8List(50)));
    if (publisher != null) {
      archive.addFile(
        ArchiveFile.string(
          'ComicInfo.xml',
          '<ComicInfo><Series>S</Series>'
              '<Publisher>$publisher</Publisher></ComicInfo>',
        ),
      );
    }
    final path = p.join(dir.path, name);
    File(path).writeAsBytesSync(ZipEncoder().encodeBytes(archive));
    return LibraryComic(
      LibraryEntry(
        location: path,
        rootId: 1,
        folder: '',
        fileName: name,
        size: 1,
        modified: 0,
        publisher: publisher,
      ),
      null,
    );
  }

  ComicInfo? infoOf(LibraryComic c) {
    final a = ZipDecoder().decodeBytes(File(c.location).readAsBytesSync());
    final f = a.findFile('ComicInfo.xml');
    return f == null
        ? null
        : ComicInfo.parse(String.fromCharCodes(f.readBytes()!));
  }

  test('sets the field in every CBZ, keeping the rest', () async {
    final tagged = cbz('a.cbz', publisher: 'Image');
    final bare = cbz('b.cbz');
    final done = cbz('c.cbz', publisher: 'Image Comics');
    final rar = p.join(dir.path, 'd.cbr');
    File(rar).writeAsBytesSync([0x52, 0x61, 0x72, 0x21]);
    final cbr = LibraryComic(
      LibraryEntry(
        location: rar,
        rootId: 1,
        folder: '',
        fileName: 'd.cbr',
        size: 1,
        modified: 0,
      ),
      null,
    );
    final progress = <int>[];

    final result = await setComicInfoField(
      db,
      [tagged, bare, done, cbr],
      'Publisher',
      ' Image Comics ',
      onProgress: progress.add,
    );

    expect(result, (changed: 2, unchanged: 1, skipped: 1, failed: 0));
    expect(progress, [1, 2, 3, 4]);
    expect(infoOf(tagged)!.publisher, 'Image Comics');
    expect(infoOf(tagged)!.series, 'S');
    expect(infoOf(bare)!.publisher, 'Image Comics');
    expect(File(rar).readAsBytesSync(), [0x52, 0x61, 0x72, 0x21]);
    expect(
      describeBulkResult(result),
      'Updated 2 comics · 1 already set · 1 skipped (only CBZ for now)',
    );
  });

  test('an empty value removes the field', () async {
    final tagged = cbz('a.cbz', publisher: 'Image');
    await setComicInfoField(db, [tagged], 'Publisher', '');
    expect(infoOf(tagged)!.publisher, isNull);
    expect(infoOf(tagged)!.series, 'S');
  });
}

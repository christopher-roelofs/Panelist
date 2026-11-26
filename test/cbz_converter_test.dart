import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panelist/core/metadata/cbz_converter.dart';
import 'package:panelist/core/sources/archive_page_source.dart';
import 'package:panelist/core/sources/cbz_page_source.dart';
import 'package:panelist/data/database.dart';
import 'package:panelist/library/convert_comics.dart';
import 'package:panelist/library/library_model.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory dir;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  setUp(() {
    dir = Directory.systemTemp.createTempSync('panelist_convert');
    ArchivePageSource.cacheRoot = Directory(p.join(dir.path, 'cache'));
  });
  tearDown(() => dir.deleteSync(recursive: true));

  final big = Uint8List.fromList(List.generate(3 << 20, (i) => (i * 31) % 251));

  String writeTar(String name, Map<String, List<int>> entries) {
    final archive = Archive();
    entries.forEach((n, b) => archive.addFile(ArchiveFile.bytes(n, b)));
    final path = p.join(dir.path, name);
    File(path).writeAsBytesSync(TarEncoder().encodeBytes(archive));
    return path;
  }

  Map<String, List<int>> zipContents(String path) {
    final a = ZipDecoder().decodeBytes(File(path).readAsBytesSync());
    return {for (final f in a.files) f.name: f.readBytes()!};
  }

  List<String> visibleFiles() => [
    for (final e in dir.listSync())
      if (e is File) p.basename(e.path),
  ]..sort();

  test('keeps every page and file, in reading order; ids match', () async {
    final path = writeTar('Saga 01.cbt', {
      'Saga/10.jpg': [10],
      'Saga/2.jpg': [2],
      'Saga/1.png': big,
      'Saga/ComicInfo.xml':
          '<ComicInfo><Series>Saga</Series></ComicInfo>'.codeUnits,
      'Saga/credits.txt': [7],
      '__MACOSX/Saga/._1.png': [0],
      '../evil.jpg': [6],
    });
    final before = await ArchivePageSource.open(path);
    final oldId = before.id;
    await before.close();

    final c = await convertToCbz(path);

    expect(c.cbzPath, p.join(dir.path, 'Saga 01.cbz'));
    expect(c.oldId, oldId);
    final entries = zipContents(c.cbzPath);
    expect(entries.keys, [
      'evil.jpg', // made safe
      'Saga/1.png',
      'Saga/2.jpg',
      'Saga/10.jpg',
      'Saga/ComicInfo.xml',
      'Saga/credits.txt',
    ]);
    expect(entries['Saga/1.png'], big);
    final cbz = await CbzPageSource.open(c.cbzPath);
    addTearDown(cbz.close);
    expect(cbz.id, c.newId);
    expect(await cbz.readComicInfo(), contains('<Series>Saga</Series>'));
    // Original untouched; no temp files left.
    expect(File(path).existsSync(), isTrue);
    expect(
      dir.listSync().where((e) => p.basename(e.path).startsWith('.')),
      isEmpty,
    );
  });

  test('a ZIP named .cbr is renamed, keeping its id', () async {
    final archive = Archive()..addFile(ArchiveFile.bytes('1.jpg', [1]));
    final path = p.join(dir.path, 'Misnamed.cbr');
    File(path).writeAsBytesSync(ZipEncoder().encodeBytes(archive));
    final src = await CbzPageSource.open(path);
    final id = src.id;
    await src.close();

    final c = await convertToCbz(path);
    expect((c.oldId, c.newId), (id, id));
    expect(visibleFiles(), ['Misnamed.cbz']);
  });

  test(
    'refuses to overwrite a CBZ, PDFs, and archives with no pages',
    () async {
      final a = writeTar('A.cbt', {
        '1.jpg': [1],
      });
      File(p.join(dir.path, 'A.cbz')).writeAsBytesSync([1]);
      final pdf = p.join(dir.path, 'B.cbr');
      File(pdf).writeAsStringSync('%PDF-1.4');
      final empty = writeTar('C.cbt', {
        'notes.txt': [1],
      });
      for (final path in [a, pdf, empty]) {
        await expectLater(
          convertToCbz(path),
          throwsA(isA<ConversionException>()),
          reason: path,
        );
      }
      expect(visibleFiles(), ['A.cbt', 'A.cbz', 'B.cbr', 'C.cbt']);
      expect(File(p.join(dir.path, 'A.cbz')).readAsBytesSync(), [1]);
    },
  );

  test('progress follows the book; originals go to the trash', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final path = writeTar('Saga 02.cbt', {
      '1.jpg': [1],
      '2.jpg': [2],
      '3.jpg': [3],
    });
    final src = await ArchivePageSource.open(path);
    final oldId = src.id;
    await src.close();
    await db.recordOpened(
      id: oldId,
      path: path,
      title: 'Saga 02',
      pageCount: 3,
    );
    await db.saveProgress(oldId, 1);
    final unopened = writeTar('Saga 03.cbt', {
      '1.jpg': [1],
    });
    final trashed = <String>[];

    LibraryComic comic(String path) => LibraryComic(
      LibraryEntry(
        location: path,
        rootId: 1,
        folder: '',
        fileName: p.basename(path),
        size: 1,
        modified: 0,
      ),
      null,
    );
    final result = await convertComics(
      db,
      [comic(path), comic(unopened)],
      trash: (path) async {
        trashed.add(path);
        File(path).deleteSync();
        return true;
      },
    );

    expect(result.converted, 2);
    expect(result.failed, 0);
    expect(trashed, [path, unopened]);
    expect(visibleFiles(), ['Saga 02.cbz', 'Saga 03.cbz']);
    expect(await db.book(oldId), isNull);
    final cbz = await CbzPageSource.open(p.join(dir.path, 'Saga 02.cbz'));
    addTearDown(cbz.close);
    final moved = (await db.book(cbz.id))!;
    expect(moved.currentPage, 1);
    expect(moved.path, p.join(dir.path, 'Saga 02.cbz'));
  });

  test('stopping finishes the current comic, then stops', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    LibraryComic tar(String name) => LibraryComic(
      LibraryEntry(
        location: writeTar(name, {
          '1.jpg': [1],
        }),
        rootId: 1,
        folder: '',
        fileName: name,
        size: 1,
        modified: 0,
      ),
      null,
    );
    var done = 0;
    final result = await convertComics(
      db,
      [tar('A.cbt'), tar('B.cbt'), tar('C.cbt')],
      onProgress: (n) => done = n,
      shouldStop: () => done >= 1,
      trash: (_) async => true,
    );
    expect(result.converted, 1);
    expect(visibleFiles(), ['A.cbt', 'A.cbz', 'B.cbt', 'C.cbt']);
  });

  test('without a trash, the original is kept and said so', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final path = writeTar('Saga 04.cbt', {
      '1.jpg': [1],
    });
    final result = await convertComics(db, [
      LibraryComic(
        LibraryEntry(
          location: path,
          rootId: 1,
          folder: '',
          fileName: 'Saga 04.cbt',
          size: 1,
          modified: 0,
        ),
        null,
      ),
    ], trash: (_) async => false);
    expect((result.converted, result.kept), (1, 1));
    // Listed, so it can be offered for deleting.
    expect(result.keptFiles, [path]);
    expect(visibleFiles(), ['Saga 04.cbt', 'Saga 04.cbz']);
    expect(
      describeConvertResult(result),
      'Converted 1 comic to CBZ · 1 original kept (no trash)',
    );
  });
}

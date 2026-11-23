import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panelist/core/sources/cbz_page_source.dart';
import 'package:panelist/core/sources/open_source.dart';
import 'package:panelist/core/sources/page_source.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

import 'support.dart';

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('panelist_cbz');
    Pdfrx.cacheDirectoryPath ??= Directory.systemTemp.path;
  });
  tearDown(() => dir.deleteSync(recursive: true));

  String writeZip(String name, Map<String, List<int>> entries) {
    final archive = Archive();
    entries.forEach((n, b) => archive.addFile(ArchiveFile.bytes(n, b)));
    final path = p.join(dir.path, name);
    File(path).writeAsBytesSync(ZipEncoder().encodeBytes(archive));
    return path;
  }

  final big = Uint8List.fromList(List.generate(300000, (i) => i % 7));

  test('reads pages in natural order, skipping junk', () async {
    final path = writeZip('Saga 01.cbz', {
      'Saga/10.jpg': [10],
      'Saga/2.jpg': [2],
      'Saga/1.png': big, // compressible: exercises inflate
      'Saga/ComicInfo.xml': '<ComicInfo/>'.codeUnits,
      '__MACOSX/Saga/._1.png': [0],
      'Saga/.DS_Store': [0],
    });
    final src = await CbzPageSource.open(path);
    addTearDown(src.close);

    expect(src.title, 'Saga 01');
    expect(src.pageNames, ['Saga/1.png', 'Saga/2.jpg', 'Saga/10.jpg']);
    expect(await src.page(0), big);
    expect(await src.page(2), [10]);
    // Pages can be read repeatedly and concurrently.
    final again = await Future.wait([src.page(1), src.page(0), src.page(1)]);
    expect(again[0], [2]);
    expect(again[1], big);
  });

  test('id follows content, not path', () async {
    final path = writeZip('a.cbz', {'1.jpg': big});
    final a = await CbzPageSource.open(path);
    final id = a.id;
    await a.close();

    final moved = p.join(dir.path, 'renamed.cbz');
    File(path).renameSync(moved);
    final b = await CbzPageSource.open(moved);
    addTearDown(b.close);
    expect(b.id, id);

    final other = await CbzPageSource.open(
      writeZip('c.cbz', {
        '1.jpg': [1],
      }),
    );
    addTearDown(other.close);
    expect(other.id, isNot(id));
  });

  test('archive without images is rejected', () {
    final path = writeZip('empty.cbz', {
      'readme.txt': [1],
    });
    expect(
      CbzPageSource.open(path),
      throwsA(isA<UnsupportedSourceException>()),
    );
  });

  test('closed source rejects reads', () async {
    final src = await CbzPageSource.open(
      writeZip('x.cbz', {
        '1.jpg': [1],
      }),
    );
    await src.close();
    expect(src.page(0), throwsStateError);
  });

  group('openSource sniffs content, not extension', () {
    test('a ZIP named .cbr opens as CBZ', () async {
      final src = await openSource(
        writeZip('mislabelled.cbr', {
          '1.jpg': [1],
        }),
      );
      addTearDown(src.close);
      expect(src, isA<CbzPageSource>());
    });

    test('PDF magic routes to the PDF reader', () async {
      final fake = p.join(dir.path, 'fake.cbz');
      File(fake).writeAsBytesSync('%PDF-1.4 not really'.codeUnits);
      expect(
        openSource(fake),
        throwsA(
          isA<UnsupportedSourceException>().having(
            (e) => e.message,
            'message',
            contains('PDF'),
          ),
        ),
      );
    });
  });

  test('probes page sizes and reads ComicInfo.xml', () async {
    final src = await CbzPageSource.open(
      writeZip('meta.cbz', {
        for (var i = 1; i <= 10; i++) '$i.png': pngHeader(i * 10, 20),
        'Sub/ComicInfo.xml':
            '<ComicInfo><Series>Deep</Series></ComicInfo>'.codeUnits,
        'ComicInfo.xml': utf8.encode(comicInfoXml),
      }),
    );
    addTearDown(src.close);
    final sizes = await src.probePageSizes();
    expect(sizes, hasLength(10));
    expect(sizes.first, const Size(10, 20));
    expect(sizes.last, const Size(100, 20));
    // The shallowest ComicInfo wins, and UTF-8 survives.
    expect(await src.readComicInfo(), comicInfoXml);
  });

  test('no ComicInfo.xml gives null', () async {
    final src = await CbzPageSource.open(
      writeZip('n.cbz', {
        '1.jpg': [1],
      }),
    );
    addTearDown(src.close);
    expect(await src.readComicInfo(), isNull);
    expect(await src.probePageSizes(), [null]);
  });
}

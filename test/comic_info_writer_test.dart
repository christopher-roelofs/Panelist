import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panelist/core/metadata/comic_info.dart';
import 'package:panelist/core/metadata/comic_info_writer.dart';
import 'package:panelist/core/sources/cbz_page_source.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('panelist_write'));
  tearDown(() => dir.deleteSync(recursive: true));

  final big = Uint8List.fromList(List.generate(300000, (i) => i % 7));
  const xml =
      '<?xml version="1.0" encoding="utf-8"?>\n'
      '<ComicInfo><Series>Saga</Series><Number>2</Number></ComicInfo>\n';

  String writeZip(Map<String, List<int>> entries, {String? comment}) {
    final archive = Archive()..comment = comment;
    entries.forEach((n, b) => archive.addFile(ArchiveFile.bytes(n, b)));
    final path = p.join(dir.path, 'Saga 02.cbz');
    File(path).writeAsBytesSync(ZipEncoder().encodeBytes(archive));
    return path;
  }

  Map<String, List<int>> contents(String path) {
    final archive = ZipDecoder().decodeBytes(File(path).readAsBytesSync());
    return {for (final f in archive.files) f.name: f.readBytes()!};
  }

  Future<String> idOf(String path) async {
    final src = await CbzPageSource.open(path);
    final id = src.id;
    await src.close();
    return id;
  }

  test('adds ComicInfo.xml, keeping pages, other files and the id', () async {
    final path = writeZip({
      '01.jpg': big,
      '02.jpg': [2],
      'credits.txt': [9],
    }, comment: 'scanned by someone');
    final id = await idOf(path);

    await writeComicInfoToCbz(path, xml);

    final after = contents(path);
    expect(after.keys, ['01.jpg', '02.jpg', 'credits.txt', 'ComicInfo.xml']);
    expect(after['01.jpg'], big);
    expect(String.fromCharCodes(after['ComicInfo.xml']!), xml);
    expect(await idOf(path), id);
    final src = await CbzPageSource.open(path);
    addTearDown(src.close);
    expect(ComicInfo.parse((await src.readComicInfo())!)!.number, '2');
    final decoder = ZipDecoder()..decodeBytes(File(path).readAsBytesSync());
    expect(decoder.directory.zipFileComment, 'scanned by someone');
    expect(dir.listSync().map((e) => p.basename(e.path)), ['Saga 02.cbz']);
  });

  test('replaces an existing ComicInfo.xml where it is, once', () async {
    final path = writeZip({
      'Saga/01.jpg': big,
      'Saga/ComicInfo.xml': '<ComicInfo/>'.codeUnits,
      'Saga/extra/comicinfo.xml': '<ComicInfo/>'.codeUnits,
    });
    await writeComicInfoToCbz(path, xml);
    final after = contents(path);
    expect(after.keys, ['Saga/01.jpg', 'Saga/ComicInfo.xml']);
    expect(String.fromCharCodes(after['Saga/ComicInfo.xml']!), xml);
  });

  test('a file that isn’t a ZIP is left alone', () async {
    final path = p.join(dir.path, 'Saga 03.cbr');
    File(path).writeAsBytesSync([0x52, 0x61, 0x72, 0x21, 1, 2, 3]);
    await expectLater(
      writeComicInfoToCbz(path, xml),
      throwsA(isA<ComicInfoWriteException>()),
    );
    expect(File(path).readAsBytesSync(), [0x52, 0x61, 0x72, 0x21, 1, 2, 3]);
    expect(dir.listSync(), hasLength(1));
  });
}

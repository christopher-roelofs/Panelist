import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:panelist/core/sources/folder_page_source.dart';
import 'package:panelist/core/sources/open_source.dart';
import 'package:panelist/core/sources/page_source.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('panelist_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  void touch(String rel, [List<int> bytes = const [1, 2, 3]]) {
    final f = File(p.join(dir.path, rel));
    f.parent.createSync(recursive: true);
    f.writeAsBytesSync(bytes);
  }

  test('lists images recursively in natural order, skipping junk', () async {
    touch('10.jpg', [10]);
    touch('2.PNG', [2]);
    touch('ch2/1.webp', [21]);
    touch('notes.txt');
    touch('.hidden.jpg');
    touch('__MACOSX/1.jpg');
    touch('Thumbs.db');

    final src = await FolderPageSource.open(dir.path);
    expect(src.pageCount, 3);
    expect(await src.page(0), [2]);
    expect(await src.page(1), [10]);
    expect(await src.page(2), [21]);
    expect(src.title, p.basename(dir.path));
  });

  test('throws for a folder without images', () {
    touch('readme.txt');
    expect(
      FolderPageSource.open(dir.path),
      throwsA(isA<UnsupportedSourceException>()),
    );
  });

  test('openSource dispatches folders and rejects missing paths', () async {
    touch('1.jpg');
    expect(await openSource(dir.path), isA<FolderPageSource>());
    expect(
      openSource(p.join(dir.path, 'nope')),
      throwsA(isA<UnsupportedSourceException>()),
    );
  });
}

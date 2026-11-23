import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panelist/core/sources/archive_page_source.dart';
import 'package:panelist/core/sources/open_source.dart';
import 'package:panelist/core/sources/page_source.dart';
import 'package:path/path.dart' as p;

final _has7z = Process.runSync('which', ['7z']).exitCode == 0;

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('panelist_arc');
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

  List<FileSystemEntity> cacheContents() {
    final root = ArchivePageSource.cacheRoot!;
    return root.existsSync() ? root.listSync() : [];
  }

  test(
    'tar (CBT): natural order, junk skipped, cache removed on close',
    () async {
      final path = writeTar('Book.cbt', {
        'b/10.jpg': [10],
        'b/2.jpg': [2],
        'b/1.png': big, // larger than one 1MB read chunk
        'b/ComicInfo.xml': '<x/>'.codeUnits,
        '__MACOSX/b/._1.png': [0],
      });
      final src = await openSource(path) as ArchivePageSource;
      expect(src.title, 'Book');
      expect(src.pageNames, ['b/1.png', 'b/2.jpg', 'b/10.jpg']);
      // Requests may arrive before extraction finishes; they wait.
      final pages = await Future.wait([src.page(2), src.page(0), src.page(1)]);
      expect(pages[0], [10]);
      expect(pages[1], big);
      expect(pages[2], [2]);
      expect(cacheContents(), hasLength(1));

      await src.close();
      expect(cacheContents(), isEmpty);
    },
  );

  test('id follows content, not path', () async {
    final path = writeTar('a.cbt', {'1.jpg': big});
    final a = await ArchivePageSource.open(path);
    await a.close();
    final moved = p.join(dir.path, 'moved.cbt');
    File(path).renameSync(moved);
    final b = await ArchivePageSource.open(moved);
    addTearDown(b.close);
    expect(b.id, a.id);
  });

  test('closing mid-extraction stops the worker and cleans up', () async {
    final path = writeTar('many.cbt', {
      for (var i = 0; i < 40; i++) '$i.jpg': big,
    });
    final src = await ArchivePageSource.open(path);
    final pending = expectLater(src.page(39), throwsA(anything));
    await src.close();
    await pending;
    expect(cacheContents(), isEmpty);
  });

  test(
    'no images / not an archive give clear errors and leave no cache',
    () async {
      final noImages = writeTar('text.cbt', {
        'readme.txt': [1],
      });
      final junk = p.join(dir.path, 'junk.cbr');
      File(junk).writeAsBytesSync(List.generate(64, (i) => i));
      await expectLater(
        openSource(noImages),
        throwsA(
          isA<UnsupportedSourceException>().having(
            (e) => e.message,
            'message',
            contains('No images'),
          ),
        ),
      );
      await expectLater(
        openSource(junk),
        throwsA(
          isA<UnsupportedSourceException>().having(
            (e) => e.message,
            'message',
            contains('Not a readable'),
          ),
        ),
      );
      expect(cacheContents(), isEmpty);
    },
  );

  test('stale cache from dead processes is removed, live ones kept', () async {
    final root = ArchivePageSource.cacheRoot!..createSync(recursive: true);
    final dead = Directory(p.join(root.path, 'book_999999999_x'))..createSync();
    final mine = Directory(p.join(root.path, 'book_${pid}_y'))..createSync();
    final other = Directory(p.join(root.path, 'unrelated'))..createSync();
    await ArchivePageSource.cleanStaleCache();
    expect(dead.existsSync(), isFalse);
    expect(mine.existsSync(), isTrue);
    expect(other.existsSync(), isTrue);
  });

  test('solid 7z (CB7)', () async {
    final src = Directory(p.join(dir.path, 'src'))..createSync();
    for (final (name, bytes) in [
      ('p10.jpg', [10]),
      ('p9.jpg', [9]),
      ('p1.jpg', big),
    ]) {
      File(p.join(src.path, name)).writeAsBytesSync(bytes);
    }
    final path = p.join(dir.path, 'Solid.cb7');
    final r = Process.runSync('7z', [
      'a',
      '-t7z',
      '-ms=on',
      path,
      '.',
    ], workingDirectory: src.path);
    expect(r.exitCode, 0, reason: '${r.stderr}');

    final s = await openSource(path) as ArchivePageSource;
    addTearDown(s.close);
    expect(s.pageNames, ['p1.jpg', 'p9.jpg', 'p10.jpg']);
    expect(await s.page(2), [10]);
    expect(await s.page(0), big);
  }, skip: _has7z ? false : '7z CLI not installed');
}

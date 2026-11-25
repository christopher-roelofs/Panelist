import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:panelist/library/library_refresh.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late int changes;
  late LibraryWatcher watcher;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('panelist_watch');
    Directory(p.join(root.path, 'Saga')).createSync();
    Directory(p.join(root.path, '.hidden')).createSync();
    changes = 0;
    watcher = LibraryWatcher(
      onChange: () => changes++,
      debounce: const Duration(milliseconds: 100),
    );
  });

  tearDown(() async {
    watcher.dispose();
    await root.delete(recursive: true);
  });

  /// Waits for file events and the debounce to settle.
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 400));

  void write(String relative) =>
      File(p.join(root.path, relative)).writeAsStringSync('x');

  test('watches every folder except hidden ones', () async {
    await watcher.watch([root.path]);
    expect(
      watcher.watched,
      unorderedEquals([p.normalize(root.path), p.join(root.path, 'Saga')]),
    );
  });

  test('comics added in a subfolder cause one change', () async {
    await watcher.watch([root.path]);
    write('Saga/Saga 01.cbz');
    write('Saga/Saga 02.cbr');
    write('Saga/Saga 03.pdf');
    await settle();
    expect(changes, 1);
  });

  test('other files are ignored', () async {
    await watcher.watch([root.path]);
    write('Saga/notes.txt');
    write('Saga/.Saga 01.cbz.part');
    write('.hidden/Saga 01.cbz');
    await settle();
    expect(changes, 0);
  });

  test('new folders are noticed, and watched after the next watch', () async {
    await watcher.watch([root.path]);
    Directory(p.join(root.path, 'Hex11')).createSync();
    await settle();
    expect(changes, 1);

    await watcher.watch([root.path]); // what a finished scan does
    write('Hex11/Hex11 01.cbz');
    await settle();
    expect(changes, 2);
  });

  test('deleted folders and comics are noticed', () async {
    write('Saga/Saga 01.cbz');
    await watcher.watch([root.path]);
    File(p.join(root.path, 'Saga/Saga 01.cbz')).deleteSync();
    await settle();
    expect(changes, 1);

    Directory(p.join(root.path, 'Saga')).deleteSync(recursive: true);
    await settle();
    expect(changes, 2);
    await watcher.watch([root.path]);
    expect(watcher.watched, [p.normalize(root.path)]);
  });

  test('missing folders and Android folders are skipped', () async {
    await watcher.watch([
      p.join(root.path, 'gone'),
      'content://com.android.externalstorage.documents/tree/primary%3AComics',
    ]);
    expect(watcher.watched, isEmpty);
  });
}

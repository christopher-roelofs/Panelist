import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:panelist/app/providers.dart';
import 'package:panelist/core/metadata/comic_info.dart';
import 'package:panelist/data/database.dart';
import 'package:panelist/library/comic_info_editor.dart';
import 'package:panelist/library/library_model.dart';
import 'package:panelist/library/library_scanner.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory dir;
  late AppDatabase db;
  late String path;
  late LibraryComic comic;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  setUp(() {
    dir = Directory.systemTemp.createTempSync('panelist_editor');
    db = AppDatabase(NativeDatabase.memory());
    path = p.join(dir.path, 'Saga', 'Saga 002 (2012).cbz');
    File(path).createSync(recursive: true);
    final archive = Archive()
      ..addFile(ArchiveFile.bytes('01.jpg', Uint8List(100)))
      ..addFile(
        ArchiveFile.string(
          'ComicInfo.xml',
          '<ComicInfo><Writer>Old</Writer><Pages><Page Image="0"/></Pages>'
              '</ComicInfo>',
        ),
      );
    File(path).writeAsBytesSync(ZipEncoder().encodeBytes(archive));
    comic = LibraryComic(
      LibraryEntry(
        location: path,
        rootId: 1,
        folder: 'Saga',
        fileName: 'Saga 002 (2012).cbz',
        size: 1,
        modified: 0,
        bookId: 'b',
        pageCount: 1,
      ),
      null,
    );
  });
  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  /// Lets real file work (isolates, I/O) finish, pumping frames between.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 100; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
      final loaded =
          find.byType(ComicInfoEditor).evaluate().isNotEmpty &&
          find.byType(CircularProgressIndicator).evaluate().isEmpty;
      if (loaded) break;
    }
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          coversDirProvider.overrideWithValue(
            Directory(p.join(dir.path, 'covers')),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => editComicInfo(context, comic),
              child: const Text('edit'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('edit'));
    await settle(tester);
  }

  Finder field(String label) =>
      find.widgetWithText(TextField, label, skipOffstage: false);

  String textOf(WidgetTester tester, String label) =>
      tester.widget<TextField>(field(label)).controller!.text;

  FilledButton saveButton(WidgetTester tester) => tester.widget<FilledButton>(
    find.ancestor(of: find.text('Save'), matching: find.byType(FilledButton)),
  );

  testWidgets('fills from the file name and saves into the CBZ', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 2400);
    addTearDown(tester.view.reset);
    await open(tester);

    expect(textOf(tester, 'Writer'), 'Old');
    expect(textOf(tester, 'Series'), '');
    expect(saveButton(tester).onPressed, isNull); // nothing changed

    await tester.tap(find.text('Fill empty fields from file name'));
    await tester.pump();
    expect(textOf(tester, 'Series'), 'Saga');
    expect(textOf(tester, 'Number'), '2');
    expect(textOf(tester, 'Year'), '2012');

    // A bad value blocks saving.
    await tester.enterText(field('Month'), '13');
    await tester.pump();
    expect(find.text('At most 12'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);
    await tester.enterText(field('Month'), '6');
    await tester.enterText(field('Writer'), 'Brian K. Vaughan');
    await tester.pump();

    await tester.tap(find.text('Save'));
    for (var i = 0; i < 100; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
      if (find.byType(ComicInfoEditor).evaluate().isEmpty) break;
    }
    await tester.pumpAndSettle();
    expect(find.byType(ComicInfoEditor), findsNothing); // closed

    final saved = ZipDecoder().decodeBytes(File(path).readAsBytesSync());
    final xml = String.fromCharCodes(
      saved.findFile('ComicInfo.xml')!.readBytes()!,
    );
    final info = ComicInfo.parse(xml)!;
    expect(info.series, 'Saga');
    expect(info.number, '2');
    expect(info.year, 2012);
    expect(info.writer, 'Brian K. Vaughan');
    expect(xml, contains('<Month>6</Month>'));
    expect(xml, contains('<Page Image="0"/>')); // untouched fields kept
  });

  testWidgets('closing with changes asks first', (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    addTearDown(tester.view.reset);
    await open(tester);
    await tester.enterText(field('Series'), 'Changed');
    await tester.pump();

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.byType(ComicInfoEditor), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.byType(ComicInfoEditor), findsNothing);
    expect(
      ComicInfo.parse(
        String.fromCharCodes(
          ZipDecoder()
              .decodeBytes(File(path).readAsBytesSync())
              .findFile('ComicInfo.xml')!
              .readBytes()!,
        ),
      )!.series,
      isNull,
    );
  });
}

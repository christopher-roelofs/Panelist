import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:panelist/app/providers.dart';
import 'package:panelist/data/database.dart';
import 'package:panelist/library/library_model.dart';
import 'package:panelist/library/library_providers.dart';
import 'package:panelist/library/library_scanner.dart';
import 'package:panelist/library/library_view.dart';

/// Right-click opens the same sheet as long-press (desktop has no
/// long-press habit).
void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  final comic = LibraryComic(
    const LibraryEntry(
      location: '/nowhere/Saga/Saga 001 (2012).cbr',
      rootId: 1,
      folder: 'Saga',
      fileName: 'Saga 001 (2012).cbr',
      size: 1,
      modified: 0,
      bookId: 'b',
      pageCount: 10,
    ),
    null,
  );

  for (final (view, title, button) in [
    (LibraryView.publishers, 'Image', 'Edit publisher'),
    (LibraryView.series, 'Saga', 'Edit series'),
  ]) {
    testWidgets('right-click on a ${view.name} group offers $button', (
      tester,
    ) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final tagged = LibraryComic(
        const LibraryEntry(
          location: '/nowhere/Saga/Saga 001 (2012).cbz',
          rootId: 1,
          folder: 'Saga',
          fileName: 'Saga 001 (2012).cbz',
          size: 1,
          modified: 0,
          bookId: 'b',
          pageCount: 10,
          series: 'Saga',
          publisher: 'Image',
        ),
        null,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            coversDirProvider.overrideWithValue(Directory('/nowhere')),
            libraryRootsProvider.overrideWith(
              (ref) => Stream.value([
                const LibraryRoot(id: 1, location: '/nowhere', name: 'C'),
              ]),
            ),
            libraryComicsProvider.overrideWithValue([tagged]),
            libraryPrefsProvider.overrideWith(
              () => LibraryPrefsNotifier((
                view: view,
                layout: LibraryLayout.grid,
              )),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(body: LibraryBrowser(onOpenFile: () {})),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _rightClick(tester, find.text(title).last);
      await tester.pumpAndSettle();
      expect(find.text('Mark all as read'), findsOneWidget);
      // Desktop only (tests run on the host, which is desktop).
      expect(find.text(button), findsOneWidget);
      await tester.tap(find.text(button));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });
  }

  testWidgets('a folder, or the library folder, covers all subfolders', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    LibraryComic at(String folder, String file) => LibraryComic(
      LibraryEntry(
        location: '/lib/$folder/$file',
        rootId: 1,
        folder: folder,
        fileName: file,
        size: 1,
        modified: 0,
      ),
      null,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          coversDirProvider.overrideWithValue(Directory('/nowhere')),
          libraryRootsProvider.overrideWith(
            (ref) => Stream.value([
              const LibraryRoot(id: 1, location: '/lib', name: 'Comics'),
            ]),
          ),
          libraryComicsProvider.overrideWithValue([
            at('', 'Loose 01.cbr'),
            at('DC', 'Batman 01.cbr'),
            at('DC/Old', 'Batman 1940 01.cb7'),
            at('DC/Old', 'Superman 01.cbz'),
          ]),
          libraryPrefsProvider.overrideWith(
            () => LibraryPrefsNotifier((
              view: LibraryView.folders,
              layout: LibraryLayout.grid,
            )),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(body: LibraryBrowser(onOpenFile: () {})),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _rightClick(tester, find.text('DC'));
    await tester.pumpAndSettle();
    expect(find.text('Convert 2 to CBZ'), findsOneWidget);
    await tester.tapAt(const Offset(5, 5)); // close the sheet
    await tester.pumpAndSettle();

    await _rightClick(tester, find.text('Comics')); // the breadcrumb
    await tester.pumpAndSettle();
    expect(find.text('4 comics · 0 read'), findsOneWidget);
    expect(find.text('Convert 3 to CBZ'), findsOneWidget);
  });

  for (final layout in LibraryLayout.values) {
    for (final (gesture, label) in [
      (_rightClick, 'right-click'),
      (_longPress, 'long-press'),
    ]) {
      testWidgets('$label opens the details sheet (${layout.name})', (
        tester,
      ) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              coversDirProvider.overrideWithValue(Directory('/nowhere')),
              libraryRootsProvider.overrideWith(
                (ref) => Stream.value([
                  const LibraryRoot(id: 1, location: '/nowhere', name: 'C'),
                ]),
              ),
              libraryComicsProvider.overrideWithValue([comic]),
              libraryPrefsProvider.overrideWith(
                () => LibraryPrefsNotifier((
                  view: LibraryView.series,
                  layout: layout,
                )),
              ),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: LibraryBrowser(onOpenFile: () {}, query: 'Saga'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await gesture(tester, find.text('Saga #1 (2012)').first);
        await tester.pumpAndSettle();
        expect(find.text('Mark as read'), findsOneWidget);
        // A CBR on desktop (the test host) offers conversion.
        expect(find.text('Convert to CBZ'), findsOneWidget);
      });
    }
  }
}

Future<void> _rightClick(WidgetTester tester, Finder target) => tester.tap(
  target,
  buttons: kSecondaryMouseButton,
  kind: PointerDeviceKind.mouse,
);

Future<void> _longPress(WidgetTester tester, Finder target) =>
    tester.longPress(target);

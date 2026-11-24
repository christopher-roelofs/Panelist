import 'dart:ui' show ImageByteFormat, PictureRecorder;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:panelist/app/providers.dart';
import 'package:panelist/core/sources/page_source.dart';
import 'package:panelist/data/book_extensions.dart';
import 'package:panelist/data/database.dart';
import 'package:panelist/reader/fit_mode.dart';
import 'package:panelist/reader/reader_screen.dart';
import 'package:panelist/reader/reader_settings.dart';
import 'package:panelist/reader/spreads.dart';

const _portrait = Size(1000, 1500);
const _wide = Size(2000, 1500);

class _FakeSource implements EncodedPageSource {
  _FakeSource(this.sizes, [this.bytes]);

  final List<Size?> sizes;

  /// Encoded bytes for every page; null means undecodable pages.
  final Uint8List? bytes;
  bool closed = false;

  @override
  String get id => 'fake';
  @override
  String get title => 'Fake Comic';
  @override
  int get pageCount => sizes.length;
  // Empty bytes: every page is undecodable, which must not crash the reader.
  @override
  Future<Uint8List> page(int index) async => bytes ?? Uint8List(0);
  @override
  Future<List<Size?>> probePageSizes() async => sizes;
  @override
  Future<String?> readComicInfo() async => null;
  @override
  Future<void> close() async => closed = true;
}

void main() {
  late AppDatabase db;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// Opens the reader on a fake book whose page sizes are already cached
  /// (so pairing is deterministic). The test viewport is 800x600, i.e.
  /// landscape.
  Future<(_FakeSource, ProviderContainer)> pump(
    WidgetTester tester, {
    List<Size?> sizes = const [
      _portrait,
      _portrait,
      _portrait,
      _portrait,
      _portrait,
    ],
    int initialPage = 0,
    ReaderSettings defaults = const ReaderSettings(layout: LayoutMode.single),
    Uint8List? bytes,
  }) async {
    final src = _FakeSource(sizes, bytes);
    final book = (await tester.runAsync(() async {
      await db.recordOpened(
        id: 'fake',
        path: '/x',
        title: 'x',
        pageCount: sizes.length,
      );
      await db.savePageSizes('fake', encodePageSizes(sizes));
      return db.book('fake');
    }))!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          readerDefaultsProvider.overrideWith(
            () => ReaderDefaultsNotifier(defaults),
          ),
        ],
        child: MaterialApp(
          home: ReaderScreen(source: src, book: book, initialPage: initialPage),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ReaderScreen)),
    );
    return (src, container);
  }

  Future<void> key(WidgetTester tester, LogicalKeyboardKey k) async {
    await tester.sendKeyEvent(k);
    await tester.pumpAndSettle();
  }

  Future<Book> stored(WidgetTester tester) async =>
      (await tester.runAsync(() => db.book('fake')))!;

  testWidgets('keyboard navigation moves between pages', (tester) async {
    await pump(tester);
    expect(find.text('1 / 5'), findsOneWidget);

    await key(tester, LogicalKeyboardKey.arrowRight);
    await key(tester, LogicalKeyboardKey.space);
    expect(find.text('3 / 5'), findsOneWidget);

    await key(tester, LogicalKeyboardKey.arrowLeft);
    expect(find.text('2 / 5'), findsOneWidget);

    await key(tester, LogicalKeyboardKey.end);
    expect(find.text('5 / 5'), findsOneWidget);
    await key(tester, LogicalKeyboardKey.arrowRight); // clamps at end
    expect(find.text('5 / 5'), findsOneWidget);

    await key(tester, LogicalKeyboardKey.home);
    expect(find.text('1 / 5'), findsOneWidget);
  });

  testWidgets('edge taps turn pages without delay', (tester) async {
    await pump(tester);
    final size = tester.getSize(find.byType(ReaderScreen));
    await tester.tapAt(Offset(size.width * 0.9, size.height / 2));
    await tester.pumpAndSettle();
    expect(find.text('2 / 5'), findsOneWidget);
    await tester.tapAt(Offset(size.width * 0.1, size.height / 2));
    await tester.pumpAndSettle();
    expect(find.text('1 / 5'), findsOneWidget);
  });

  testWidgets('a fast flick turns the page even over a zoomable page', (
    tester,
  ) async {
    // Real, decodable pages, so the zoomable InteractiveViewer is built.
    final png = (await tester.runAsync(() async {
      final recorder = PictureRecorder();
      Canvas(recorder).drawRect(
        const Rect.fromLTWH(0, 0, 100, 150),
        Paint()..color = const Color(0xFF336699),
      );
      final image = await recorder.endRecording().toImage(100, 150);
      final data = await image.toByteData(format: ImageByteFormat.png);
      return data!.buffer.asUint8List();
    }))!;
    await pump(tester, sizes: List.filled(5, const Size(100, 150)), bytes: png);
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(Durations.short2));
      await tester.pump();
    }
    expect(find.byType(InteractiveViewer), findsWidgets);

    // A drag whose first move crosses every recognizer's slop at once (as
    // fast flicks do), ending past halfway.
    final g = await tester.startGesture(const Offset(600, 300));
    for (final dx in const <double>[-120, -120, -120, -120, -120]) {
      await tester.pump(const Duration(milliseconds: 8));
      await g.moveBy(Offset(dx, 0));
    }
    await g.up();
    await tester.pumpAndSettle();
    expect(find.text('2 / 5'), findsOneWidget);
  });

  testWidgets('centre tap toggles the overlay', (tester) async {
    await pump(tester);
    final size = tester.getSize(find.byType(ReaderScreen));
    double opacity() =>
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity;
    expect(opacity(), 0);
    await tester.tapAt(size.center(Offset.zero));
    await tester.pump(const Duration(milliseconds: 300)); // double-tap window
    await tester.pumpAndSettle();
    expect(opacity(), 1);
  });

  testWidgets('opens at the saved page and saves progress', (tester) async {
    await pump(tester, initialPage: 3);
    expect(find.text('4 / 5'), findsOneWidget);
    await key(tester, LogicalKeyboardKey.arrowRight);
    expect((await stored(tester)).currentPage, 4);
  });

  testWidgets('two-page layout: cover alone, then spreads', (tester) async {
    await pump(
      tester,
      defaults: const ReaderSettings(layout: LayoutMode.double),
    );
    expect(find.text('1 / 5'), findsOneWidget);
    await key(tester, LogicalKeyboardKey.arrowRight);
    expect(find.text('2–3 / 5'), findsOneWidget);
    await key(tester, LogicalKeyboardKey.arrowRight);
    expect(find.text('4–5 / 5'), findsOneWidget);
    // Progress is the first page of the spread.
    expect((await stored(tester)).currentPage, 3);
  });

  testWidgets('wide pages are never paired', (tester) async {
    await pump(
      tester,
      sizes: const [_portrait, _portrait, _wide, _portrait, _portrait],
      defaults: const ReaderSettings(layout: LayoutMode.double),
    );
    await key(tester, LogicalKeyboardKey.arrowRight);
    expect(find.text('2 / 5'), findsOneWidget); // can't pair with the wide 3
    await key(tester, LogicalKeyboardKey.arrowRight);
    expect(find.text('3 / 5'), findsOneWidget);
    await key(tester, LogicalKeyboardKey.arrowRight);
    expect(find.text('4–5 / 5'), findsOneWidget);
  });

  testWidgets('auto layout uses spreads in landscape', (tester) async {
    await pump(tester, defaults: const ReaderSettings());
    await key(tester, LogicalKeyboardKey.arrowRight);
    expect(find.text('2–3 / 5'), findsOneWidget);
  });

  testWidgets('changing layout keeps the reading position', (tester) async {
    await pump(tester, initialPage: 3); // single layout, page 4
    await key(tester, LogicalKeyboardKey.keyD); // -> two pages
    expect(find.text('4–5 / 5'), findsOneWidget);
    await key(tester, LogicalKeyboardKey.keyD); // -> auto (landscape)
    expect(find.text('4–5 / 5'), findsOneWidget);
    await key(tester, LogicalKeyboardKey.keyD); // -> single
    expect(find.text('4 / 5'), findsOneWidget);
  });

  testWidgets('cover toggle re-pairs pages', (tester) async {
    await pump(
      tester,
      defaults: const ReaderSettings(layout: LayoutMode.double),
    );
    await key(tester, LogicalKeyboardKey.keyO);
    expect(find.text('1–2 / 5'), findsOneWidget);
  });

  testWidgets('settings are saved per book and become the default', (
    tester,
  ) async {
    final (_, container) = await pump(tester);
    await key(tester, LogicalKeyboardKey.keyM); // fit: screen -> width
    await key(tester, LogicalKeyboardKey.keyD); // layout: single -> double
    final book = await stored(tester);
    expect(book.fitMode, 'width');
    expect(book.layoutMode, 'double');
    expect(container.read(readerDefaultsProvider).fit, FitMode.width);
    expect(container.read(readerDefaultsProvider).layout, LayoutMode.double);
  });

  testWidgets('closes the source when disposed', (tester) async {
    final (src, _) = await pump(tester);
    await tester.pumpWidget(const SizedBox());
    expect(src.closed, isTrue);
  });
}

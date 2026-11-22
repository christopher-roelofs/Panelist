import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:panelist/app/providers.dart';
import 'package:panelist/core/sources/page_source.dart';
import 'package:panelist/data/database.dart';
import 'package:panelist/reader/fit_mode.dart';
import 'package:panelist/reader/reader_screen.dart';

class _FakeSource implements PageSource {
  bool closed = false;
  @override
  String get id => 'fake';
  @override
  String get title => 'Fake Comic';
  @override
  int get pageCount => 5;
  // Empty bytes: every page is undecodable, which must not crash the reader.
  @override
  Future<Uint8List> page(int index) async => Uint8List(0);
  @override
  Future<void> close() async => closed = true;
}

void main() {
  late AppDatabase db;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.recordOpened(id: 'fake', path: '/x', title: 'x', pageCount: 5);
  });
  tearDown(() => db.close());

  Future<(_FakeSource, ProviderContainer)> pump(
    WidgetTester tester, {
    int initialPage = 0,
  }) async {
    final src = _FakeSource();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: ReaderScreen(source: src, initialPage: initialPage),
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
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    expect((await tester.runAsync(() => db.book('fake')))!.currentPage, 4);
  });

  testWidgets('M cycles the fit mode', (tester) async {
    final (_, container) = await pump(tester);
    expect(container.read(fitModeProvider), FitMode.screen);
    await key(tester, LogicalKeyboardKey.keyM);
    expect(container.read(fitModeProvider), FitMode.width);
  });

  testWidgets('closes the source when disposed', (tester) async {
    final (src, _) = await pump(tester);
    await tester.pumpWidget(const SizedBox());
    expect(src.closed, isTrue);
  });
}

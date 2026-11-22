import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:panelist/core/sources/page_source.dart';
import 'package:panelist/reader/reader_screen.dart';

class _FakeSource implements PageSource {
  bool closed = false;
  @override
  String get id => 'fake';
  @override
  String get title => 'Fake Comic';
  @override
  int get pageCount => 5;
  @override
  // Empty bytes: every page is undecodable, which must not crash the reader.
  Future<Uint8List> page(int index) async => Uint8List(0);
  @override
  Future<void> close() async => closed = true;
}

void main() {
  Future<_FakeSource> pump(WidgetTester tester) async {
    final src = _FakeSource();
    await tester.pumpWidget(MaterialApp(home: ReaderScreen(source: src)));
    await tester.pumpAndSettle();
    return src;
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

  testWidgets('tap zones turn pages', (tester) async {
    await pump(tester);
    final size = tester.getSize(find.byType(ReaderScreen));
    await tester.tapAt(Offset(size.width * 0.9, size.height / 2));
    await tester.pumpAndSettle();
    expect(find.text('2 / 5'), findsOneWidget);
    await tester.tapAt(Offset(size.width * 0.1, size.height / 2));
    await tester.pumpAndSettle();
    expect(find.text('1 / 5'), findsOneWidget);
  });

  testWidgets('closes the source when disposed', (tester) async {
    final src = await pump(tester);
    await tester.pumpWidget(const SizedBox());
    expect(src.closed, isTrue);
  });
}

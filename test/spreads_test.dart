import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:panelist/reader/reader_settings.dart';
import 'package:panelist/reader/spreads.dart';

const p = Size(1000, 1500); // portrait
const w = Size(2000, 1500); // wide (pre-joined spread)

void main() {
  test('single layout: one page per unit', () {
    expect(buildSpreads([p, p, p], twoPages: false, coverAlone: true), [
      [0],
      [1],
      [2],
    ]);
  });

  test('cover alone, then pairs', () {
    expect(buildSpreads([p, p, p, p, p], twoPages: true, coverAlone: true), [
      [0],
      [1, 2],
      [3, 4],
    ]);
  });

  test('without cover offset the cover is paired', () {
    expect(buildSpreads([p, p, p], twoPages: true, coverAlone: false), [
      [0, 1],
      [2],
    ]);
  });

  test('wide pages stand alone and re-align pairing after them', () {
    expect(buildSpreads([p, p, w, p, p, p], twoPages: true, coverAlone: true), [
      [0],
      [1],
      [2],
      [3, 4],
      [5],
    ]);
  });

  test('unknown sizes count as portrait', () {
    expect(
      buildSpreads([null, null, null], twoPages: true, coverAlone: false),
      [
        [0, 1],
        [2],
      ],
    );
  });

  test('unitOfPage finds the unit holding a page', () {
    final units = [
      [0],
      [1, 2],
      [3],
    ];
    expect(unitOfPage(units, 2), 1);
    expect(unitOfPage(units, 3), 2);
    expect(unitOfPage(units, 99), 2);
  });

  test('auto layout follows orientation', () {
    const s = ReaderSettings();
    expect(s.showsTwoPages(const Size(1600, 900)), isTrue);
    expect(s.showsTwoPages(const Size(900, 1600)), isFalse);
    expect(
      s.copyWith(layout: LayoutMode.double).showsTwoPages(const Size(9, 16)),
      isTrue,
    );
  });
}

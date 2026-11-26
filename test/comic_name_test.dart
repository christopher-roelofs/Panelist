import 'package:flutter_test/flutter_test.dart';
import 'package:panelist/library/comic_name.dart';

void main() {
  (String?, String?, int?) parse(String name, {bool folder = false}) {
    final n = ComicName.parse(name, isFolder: folder);
    return (n.series, n.number, n.year);
  }

  test('series #number (year)', () {
    expect(parse('Locke & Key - Welcome to Lovecraft #001 (2008).cbz'), (
      'Locke & Key - Welcome to Lovecraft',
      '1',
      2008,
    ));
    expect(parse("Jupiter's Legacy - Requiem #006 (2021).cbz"), (
      "Jupiter's Legacy - Requiem",
      '6',
      2021,
    ));
  });

  test('underscores and a trailing number', () {
    expect(parse('Atomic_War_001.cbr'), ('Atomic War', '1', null));
    expect(parse('World_War_III_01.cbz'), ('World War III', '1', null));
  });

  test('a trailing four-digit year is a year, not an issue', () {
    expect(parse('If_an_A_Bomb_falls_1951.pdf'), (
      'If an A Bomb falls',
      null,
      1951,
    ));
  });

  test('scene tags are dropped', () {
    expect(parse('Saga 054 (2018) (Digital) (Zone-Empire).cbr'), (
      'Saga',
      '54',
      2018,
    ));
    expect(parse('Saga #12.5 [HD].cbz'), ('Saga', '12.5', null));
  });

  test('dots as separators', () {
    expect(parse('Black.Hammer.003.cbz'), ('Black Hammer', '3', null));
  });

  test('folders keep trailing numbers in the series', () {
    expect(parse('Eight Billion Genies (2022)', folder: true), (
      'Eight Billion Genies',
      null,
      2022,
    ));
    expect(parse('2000 AD', folder: true), ('2000 AD', null, null));
    // Words are kept as written; Metron lookup works out what fits.
    expect(parse('2000AD prog 2509 (2026) (4320p juvecube).cbz'), (
      '2000AD prog',
      '2509',
      2026,
    ));
  });

  test('nothing but a number', () {
    expect(parse('001.cbz'), (null, '1', null));
  });
}

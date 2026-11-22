import 'package:flutter_test/flutter_test.dart';
import 'package:panelist/core/util/natural_sort.dart';

void main() {
  List<String> sorted(List<String> xs) => [...xs]..sort(naturalCompare);

  test('orders numeric runs by value', () {
    expect(sorted(['page10.jpg', 'page2.jpg', 'page1.jpg']), [
      'page1.jpg',
      'page2.jpg',
      'page10.jpg',
    ]);
  });

  test('ignores leading zeros and case', () {
    expect(sorted(['P003.png', 'p2.png', 'p001.png']), [
      'p001.png',
      'p2.png',
      'P003.png',
    ]);
  });

  test('handles very long numbers', () {
    expect(sorted(['a99999999999999999999', 'a100000000000000000000']), [
      'a99999999999999999999',
      'a100000000000000000000',
    ]);
  });

  test('sorts by chapter folder, then page', () {
    expect(sorted(['ch10/01.jpg', 'ch2/10.jpg', 'ch2/2.jpg']), [
      'ch2/2.jpg',
      'ch2/10.jpg',
      'ch10/01.jpg',
    ]);
  });

  test('is deterministic for equal-ignoring-case names', () {
    expect(naturalCompare('A.jpg', 'a.jpg'), isNot(0));
  });
}

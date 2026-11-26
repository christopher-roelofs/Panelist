import 'package:flutter_test/flutter_test.dart';
import 'package:panelist/library/publisher_aliases.dart';

void main() {
  test('rules match ignoring case and punctuation', () {
    final a = const PublisherAliases().withRule('Image', 'Image Comics');
    expect(a.apply('Image'), 'Image Comics');
    expect(a.apply('image'), 'Image Comics');
    expect(a.apply('Marvel'), 'Marvel');
    expect(a.apply(null), isNull);
    expect(PublisherAliases.decode(a.encode()).rules, a.rules);
    expect(PublisherAliases.decode('not json').rules, isEmpty);
    expect(a.without('Image').apply('Image'), 'Image');
  });

  test('suggestions come from the library\'s own names', () {
    final s = suggestAliases({
      'Image': 3,
      'Image Comics': 10,
      'IDW Publishing': 4,
      'Idw publishing': 1,
      'DC Comics': 2,
      'DC': 2,
      'Marvel': 5,
      'Dark Horse': 1,
    });
    expect(
      s,
      unorderedEquals([
        ('Image', 'Image Comics'),
        ('Idw publishing', 'IDW Publishing'),
        ('DC', 'DC Comics'), // a tie: the fuller name
      ]),
    );
  });

  test('names a rule already covers aren\'t suggested', () {
    final existing = const PublisherAliases().withRule('Image', 'Image Comics');
    expect(
      suggestAliases({'Image': 3, 'Image Comics': 10}, existing: existing),
      isEmpty,
    );
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:panelist/core/metadata/comic_info.dart';
import 'package:panelist/core/metadata/comic_info_document.dart';

const _existing = '''<?xml version="1.0" encoding="utf-8"?>
<ComicInfo xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <Series>Saga</Series>
  <Number>1</Number>
  <Summary>Line one.
Line two.</Summary>
  <Year>2012</Year>
  <Publisher>Image</Publisher>
  <FutureField attr="x">kept</FutureField>
  <Pages>
    <Page Image="0" Type="FrontCover" />
    <Page Image="1" />
  </Pages>
</ComicInfo>''';

void main() {
  test('reads fields; blank and missing are null', () {
    final doc = ComicInfoDocument.parse(_existing);
    expect(doc['Series'], 'Saga');
    expect(doc['Year'], '2012');
    expect(doc['Writer'], isNull);
  });

  test('edits keep everything else, and new fields go in schema order', () {
    final doc = ComicInfoDocument.parse(_existing)
      ..['Series'] = 'Saga Deluxe'
      ..['Title'] =
          'Chapter One' // first in the schema
      ..['Writer'] =
          'Brian K. Vaughan' // between Year and Publisher
      ..['Number'] = null; // removed
    final xml = doc.toXmlString();

    expect(xml, startsWith('<?xml version="1.0" encoding="utf-8"?>\n'));
    final names = RegExp(r'<(\w+)[ >]')
        .allMatches(xml)
        .map((m) => m[1])
        .where((n) => n != 'Page')
        .toList();
    expect(names, [
      'ComicInfo',
      'Title',
      'Series',
      'Summary',
      'Year',
      'Writer',
      'Publisher',
      'FutureField',
      'Pages',
    ]);
    expect(xml, contains('<FutureField attr="x">kept</FutureField>'));
    expect(xml, contains('<Page Image="0" Type="FrontCover"/>'));
    expect(xml, contains('<Summary>Line one.\nLine two.</Summary>'));
    expect(xml, contains('xmlns:xsi='));

    // What Panelist reads back.
    final info = ComicInfo.parse(xml)!;
    expect(info.series, 'Saga Deluxe');
    expect(info.number, isNull);
    expect(info.writer, 'Brian K. Vaughan');
  });

  test('missing or broken XML starts an empty document', () {
    for (final xml in [null, 'not xml', '<Other/>']) {
      final doc = ComicInfoDocument.parse(xml);
      expect(doc.isEmpty, isTrue, reason: '$xml');
      doc['Series'] = 'New';
      expect(ComicInfo.parse(doc.toXmlString())!.series, 'New');
    }
  });

  test('values are trimmed; blank removes', () {
    final doc = ComicInfoDocument.parse(_existing)
      ..['Series'] = '  Saga  '
      ..['Publisher'] = '   ';
    expect(doc['Series'], 'Saga');
    expect(doc['Publisher'], isNull);
    expect(doc.toXmlString(), isNot(contains('Publisher')));
  });
}

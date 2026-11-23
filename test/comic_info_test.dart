import 'package:flutter_test/flutter_test.dart';
import 'package:panelist/core/metadata/comic_info.dart';

void main() {
  test('parses common fields', () {
    final info = ComicInfo.parse('''<?xml version="1.0" encoding="utf-8"?>
<ComicInfo xmlns:xsd="http://www.w3.org/2001/XMLSchema"
           xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <Title>The Long Night</Title>
  <Series>Atomic War</Series>
  <Number>1</Number>
  <Volume>1952</Volume>
  <Year>1952</Year>
  <Writer>Unknown</Writer>
  <Penciller>Lou Cameron</Penciller>
  <Summary>  Cities fall.  </Summary>
  <Manga>YesAndRightToLeft</Manga>
  <Pages><Page Image="0" Type="FrontCover"/></Pages>
</ComicInfo>''')!;
    expect(info.title, 'The Long Night');
    expect(info.series, 'Atomic War');
    expect(info.number, '1');
    expect(info.volume, 1952);
    expect(info.year, 1952);
    expect(info.artist, 'Lou Cameron');
    expect(info.summary, 'Cities fall.');
    expect(info.rightToLeft, isTrue);
  });

  test('missing, empty and invalid fields are null', () {
    final info = ComicInfo.parse(
      '<ComicInfo><Series></Series><Year>-1</Year><Manga>Yes</Manga>'
      '<Artist>A</Artist></ComicInfo>',
    )!;
    expect(info.series, isNull);
    expect(info.year, isNull);
    expect(info.rightToLeft, isNull);
    expect(info.artist, 'A');
  });

  test('rejects non-ComicInfo and malformed XML', () {
    expect(ComicInfo.parse('<Other/>'), isNull);
    expect(ComicInfo.parse('<ComicInfo><Series>'), isNull);
  });

  test('recognises the file name anywhere in an archive', () {
    expect(ComicInfo.isComicInfoName('ComicInfo.xml'), isTrue);
    expect(ComicInfo.isComicInfoName('Book/comicinfo.XML'), isTrue);
    expect(ComicInfo.isComicInfoName(r'Book\ComicInfo.xml'), isTrue);
    expect(ComicInfo.isComicInfoName('ComicInfo.xml.bak'), isFalse);
  });
}

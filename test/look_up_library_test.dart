import 'package:flutter_test/flutter_test.dart';
import 'package:panelist/data/database.dart';
import 'package:panelist/library/info_lookup.dart';
import 'package:panelist/library/library_model.dart';

LibraryComic comic({
  String? series,
  String? number,
  int? year,
  String? publisher,
}) => LibraryComic(
  LibraryEntry(
    location: '/c/Saga 001 (2012).cbz',
    rootId: 1,
    folder: '',
    fileName: 'Saga 001 (2012).cbz',
    size: 1,
    modified: 0,
    series: series,
    number: number,
    year: year,
    publisher: publisher,
  ),
  null,
);

void main() {
  test('a comic is missing details unless ComicInfo has series, number, '
      'year and publisher', () {
    expect(
      isMissingDetails(
        comic(series: 'Saga', number: '1', year: 2012, publisher: 'Image'),
      ),
      isFalse,
    );
    // Names in the file name don't count: they're guesses.
    expect(isMissingDetails(comic()), isTrue);
    expect(
      isMissingDetails(comic(series: 'Saga', number: '1', year: 2012)),
      isTrue,
    );
    expect(
      isMissingDetails(
        comic(series: 'Saga', number: ' ', year: 2012, publisher: 'Image'),
      ),
      isTrue,
    );
  });
}

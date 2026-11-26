import 'package:flutter_test/flutter_test.dart';
import 'package:panelist/core/util/file_names.dart';

void main() {
  test('book IDs as file names on Windows, and back', () {
    const id = 'pages:9f86d081884c7d659a2feaa0c55ad015a3bf4f1b';
    final name = idFileName(id, windows: true);
    expect(name, isNot(contains(':')));
    expect(idFromFileName(name, windows: true), id);
    expect(idFileName(id, windows: false), id);
  });

  test('file names from another computer, made valid on Windows', () {
    expect(
      localFileName('Batman: Year One 001 (1987).cbz', windows: true),
      'Batman - Year One 001 (1987).cbz',
    );
    expect(
      localFileName('What? "Really" <1>.cbz', windows: true),
      'What- -Really- -1-.cbz',
    );
    expect(localFileName('Odd name. ', windows: true), 'Odd name');
    expect(localFileName('a:b.cbz', windows: false), 'a:b.cbz');
  });
}

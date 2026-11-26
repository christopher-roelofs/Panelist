import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:panelist/library/convert_comics.dart';
import 'package:path/path.dart' as p;

void main() {
  test('deleteFile removes the original', () async {
    final dir = Directory.systemTemp.createTempSync('panelist_orig');
    addTearDown(() => dir.deleteSync(recursive: true));
    final f = File(p.join(dir.path, 'a.cbr'))..writeAsStringSync('x');
    expect(await deleteFile(f.path), isTrue);
    expect(f.existsSync(), isFalse);
    // Already gone counts as done.
    expect(await deleteFile(f.path), isTrue);
  });
}

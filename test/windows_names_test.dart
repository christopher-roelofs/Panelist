import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:panelist/core/util/file_errors.dart';
import 'package:panelist/library/rename_template.dart';

void main() {
  test('names Windows reserves get a mark', () {
    String? r(String series) => renderTemplate('{series}/{series} {number}', {
      'series': series,
      'number': '1',
    });
    expect(r('Con'), 'Con_/Con 1');
    expect(r('aux'), 'aux_/aux 1');
    expect(r('COM1'), 'COM1_/COM1 1');
    expect(r('Console'), 'Console/Console 1');
    // Windows reads 'NUL.' plus anything as the device too.
    expect(r('Nul.Hypothesis'), 'Nul.Hypothesis_/Nul.Hypothesis 1_');
  });

  test('a locked file says to close it', () {
    expect(
      describeFileError(
        const FileSystemException(
          'Cannot rename file',
          'C:/Comics/a.cbz',
          OSError(
            'The process cannot access the file because it is being used by '
            'another process.',
            32,
          ),
        ),
      ),
      contains('Close it and try again'),
    );
    expect(describeFileError(Exception('disk full')), 'Exception: disk full');
  });
}

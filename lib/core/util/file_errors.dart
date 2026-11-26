import 'dart:io';

/// [error] for people. On Windows a file open in Panelist's reader or
/// another app can't be changed (error 32 or 33): say to close it.
String describeFileError(Object error) {
  if (_isLocked(error)) {
    return 'The file is open in Panelist’s reader or another app. Close it '
        'and try again.';
  }
  return '$error';
}

bool _isLocked(Object error) {
  if (error is FileSystemException) {
    final code = error.osError?.errorCode;
    if (Platform.isWindows && (code == 32 || code == 33)) return true;
  }
  // Wrapped in another error: Windows' own words.
  final text = '$error';
  return text.contains('being used by another process') ||
      text.contains('another process has locked a portion of the file');
}

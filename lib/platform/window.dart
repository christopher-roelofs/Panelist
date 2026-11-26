import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Desktop window controls, implemented by the Linux runner
/// (`linux/runner/my_application.cc`) and the Windows runner
/// (`windows/runner/flutter_window.cpp`); no-ops on others (macOS) until
/// their runners implement the same channel.
const _channel = MethodChannel('panelist/window');

bool get isDesktop =>
    !kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS);

Future<bool> isFullScreen() async {
  if (!isDesktop) return false;
  try {
    return await _channel.invokeMethod<bool>('isFullScreen') ?? false;
  } on Exception {
    return false; // channel not implemented (e.g. tests, other runners)
  }
}

Future<void> setFullScreen(bool value) => _invoke('setFullScreen', value);

Future<void> toggleFullScreen() async => setFullScreen(!await isFullScreen());

Future<void> setWindowTitle(String title) => _invoke('setTitle', title);

Future<void> _invoke(String method, Object? args) async {
  if (!isDesktop) return;
  try {
    await _channel.invokeMethod<void>(method, args);
  } on Exception {
    // Window controls are conveniences; ignore when unavailable.
  }
}

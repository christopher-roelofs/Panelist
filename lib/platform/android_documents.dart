import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android Storage Access Framework access, implemented by
/// `android/app/src/main/kotlin/dev/panelist/panelist/MainActivity.kt`.
///
/// Documents are addressed by `content://` URIs, which are what the recent
/// list stores on Android. Reading goes through a file descriptor exposed as
/// `/proc/self/fd/<n>`, so every format reader keeps working on plain paths.
abstract final class AndroidDocuments {
  static const _channel = MethodChannel('panelist/android');

  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  /// Whether [location] is a content URI rather than a file path.
  static bool isContentUri(String location) =>
      location.startsWith('content://');

  /// Shows the system document picker. Returns the chosen document's URI,
  /// with read access persisted across restarts where the provider allows.
  static Future<String?> pick() =>
      _channel.invokeMethod<String>('pickDocument');

  /// The URI this launch was asked to view ("Open with"), once.
  static Future<String?> takeInitialUri() async {
    if (!isSupported) return null;
    return _channel.invokeMethod<String>('takeInitialUri');
  }

  /// Calls [onOpen] for URIs viewed while the app is already running.
  static void listen(void Function(String location) onOpen) {
    if (!isSupported) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openUri') onOpen(call.arguments as String);
    });
  }

  /// Opens [uri] for reading.
  static Future<OpenedDocument> open(String uri) async {
    final Map<Object?, Object?> r;
    try {
      r = (await _channel.invokeMapMethod<Object?, Object?>('open', uri))!;
    } on PlatformException catch (e) {
      throw FileSystemException(e.message ?? 'Could not open document', uri);
    }
    final name = r['name'] as String?;
    if (r['fd'] case final int fd) {
      return OpenedDocument(
        '/proc/self/fd/$fd',
        name,
        () => _channel.invokeMethod<void>('closeFd', fd),
      );
    }
    return OpenedDocument(r['path']! as String, name, null);
  }

  /// Whether [uri] can still be opened (not deleted, permission intact).
  static Future<bool> exists(String uri) async =>
      await _channel.invokeMethod<bool>('exists', uri) ?? false;

  /// Gives up the persisted permission for [uri] (e.g. removed from recents).
  static Future<void> release(String uri) async {
    if (!isSupported || !isContentUri(uri)) return;
    await _channel.invokeMethod<void>('release', uri);
  }
}

/// A document opened for reading: a [path] usable by file APIs, its display
/// [name], and a [release] callback for when reading is done.
class OpenedDocument {
  OpenedDocument(this.path, this.name, this.release);

  final String path;
  final String? name;
  final Future<void> Function()? release;
}

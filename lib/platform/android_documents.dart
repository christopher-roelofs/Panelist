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

  /// Shows the system folder picker. Returns the folder's tree URI (with
  /// read access persisted) and display name.
  static Future<({String uri, String name})?> pickTree() async {
    final r = await _channel.invokeMapMethod<String, Object?>('pickTree');
    if (r == null) return null;
    return (uri: r['uri']! as String, name: r['name']! as String);
  }

  /// Every file under the folder [treeUri], recursively (hidden ones
  /// skipped).
  static Future<List<TreeFile>> listTree(String treeUri) async {
    final List<Object?> list;
    try {
      list = (await _channel.invokeListMethod<Object?>('listTree', treeUri))!;
    } on PlatformException catch (e) {
      throw FileSystemException(e.message ?? 'Could not list folder', treeUri);
    }
    return [
      for (final m in list.cast<Map<Object?, Object?>>())
        TreeFile(
          uri: m['uri']! as String,
          folder: m['folder']! as String,
          name: m['name']! as String,
          size: (m['size']! as num).toInt(),
          modified: (m['modified']! as num).toInt(),
        ),
    ];
  }

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
    // A temporary copy (the provider only offers a stream): delete it once
    // reading is done.
    final copy = r['path']! as String;
    return OpenedDocument(
      copy,
      name,
      () => _channel.invokeMethod<void>('deleteCopy', copy),
    );
  }

  /// A private copy of [uri] to read for an edit (deleted on release).
  static Future<OpenedDocument> copy(String uri) async {
    final String path;
    try {
      path = (await _channel.invokeMethod<String>('copy', uri))!;
    } on PlatformException catch (e) {
      throw FileSystemException(e.message ?? 'Could not read document', uri);
    }
    return OpenedDocument(
      path,
      null,
      () => _channel.invokeMethod<void>('deleteCopy', path),
    );
  }

  /// Whether [uri] can still be opened (not deleted, permission intact).
  static Future<bool> exists(String uri) async =>
      await _channel.invokeMethod<bool>('exists', uri) ?? false;

  /// Whether Panelist may change files in the library folder [treeUri]
  /// (folders added before editing came only allowed reading).
  static Future<bool> canWrite(String treeUri) async =>
      await _channel.invokeMethod<bool>('canWrite', treeUri) ?? false;

  // Edits in a library folder: [tree] is its URI, paths are `/`-separated
  // inside it. Failures are FileSystemExceptions.

  static Future<T?> _edit<T>(String method, Map<String, String> args) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      throw FileSystemException(
        e.message ?? 'Couldn’t change the file',
        args['path'] ?? args['from'],
      );
    }
  }

  /// Whether something is at [path].
  static Future<bool> existsAt(String tree, String path) async =>
      await _edit<bool>('docExists', {'tree': tree, 'path': path}) ?? false;

  /// Replaces the file at [path] with the local [file]'s bytes, safely (the
  /// original stays if anything fails). Returns its URI.
  static Future<String> replace(String tree, String path, String file) async =>
      (await _edit<String>('docReplace', {
        'tree': tree,
        'path': path,
        'file': file,
      }))!;

  /// A new file at [path] (folders created) with the local [file]'s bytes;
  /// fails if one is there. Returns its URI.
  static Future<String> create(String tree, String path, String file) async =>
      (await _edit<String>('docCreate', {
        'tree': tree,
        'path': path,
        'file': file,
      }))!;

  /// Moves or renames [from] to [to] (folders created); never overwrites.
  /// Returns its new URI.
  static Future<String> move(String tree, String from, String to) async =>
      (await _edit<String>('docMove', {'tree': tree, 'from': from, 'to': to}))!;

  static Future<void> delete(String tree, String path) =>
      _edit<void>('docDelete', {'tree': tree, 'path': path});

  /// Deletes the folder at [path] if it's empty; whether it did.
  static Future<bool> removeEmptyFolder(String tree, String path) async =>
      await _edit<bool>('docRemoveEmptyFolder', {'tree': tree, 'path': path}) ??
      false;

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

/// A file found by [AndroidDocuments.listTree].
class TreeFile {
  const TreeFile({
    required this.uri,
    required this.folder,
    required this.name,
    required this.size,
    required this.modified,
  });

  final String uri;

  /// `/`-separated folder inside the tree; empty at its top.
  final String folder;
  final String name;
  final int size;

  /// ms since the epoch, 0 if unknown.
  final int modified;
}

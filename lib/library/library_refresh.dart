import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../app/providers.dart';
import '../platform/android_documents.dart';
import 'library_providers.dart';
import 'library_scanner.dart';

/// Watches library folders on disk and calls [onChange] (debounced) when
/// comics or folders inside them appear, change or go away.
///
/// Dart's recursive watching doesn't cover subfolders on Linux, so there
/// every folder is watched on its own; [watch] is called again after each
/// scan to pick up new folders. Windows and macOS watch each library folder
/// once, subfolders included ([recursive]): on a network drive a watch per
/// folder would be hundreds of requests to the file server. Android
/// `content://` folders can't be watched (see [LibraryRefresh.onResumed]).
class LibraryWatcher {
  LibraryWatcher({
    required this.onChange,
    this.debounce = const Duration(seconds: 2),
    bool? recursive,
  }) : recursive = recursive ?? (Platform.isWindows || Platform.isMacOS);

  final void Function() onChange;

  /// One watch per library folder, covering its subfolders.
  final bool recursive;

  /// Quiet time after the last change before [onChange], so copying in a
  /// whole series causes one scan.
  final Duration debounce;

  final _subscriptions = <String, StreamSubscription<FileSystemEvent>>{};
  Timer? _timer;
  bool _disposed = false;

  /// The folders being watched (for tests).
  Iterable<String> get watched => _subscriptions.keys;

  /// Watches [roots] and every folder inside them, replacing what was
  /// watched before.
  Future<void> watch(Iterable<String> roots) async {
    final folders = <String>{};
    for (final root in roots) {
      if (AndroidDocuments.isContentUri(root)) continue;
      if (recursive) {
        if (Directory(root).existsSync()) folders.add(p.normalize(root));
      } else {
        folders.addAll(await _foldersIn(root));
      }
    }
    if (_disposed) return;
    for (final gone in _subscriptions.keys.toSet().difference(folders)) {
      unawaited(_subscriptions.remove(gone)!.cancel());
    }
    for (final folder in folders.difference(_subscriptions.keys.toSet())) {
      try {
        _subscriptions[folder] = Directory(folder)
            .watch(recursive: recursive)
            .listen(
              _onEvent,
              // A folder deleted while watched ends its stream with an error;
              // the next scan drops it.
              onError: (Object _) {},
            );
      } on FileSystemException {
        // Gone already, or out of watches: the next scan still finds it.
      }
    }
  }

  static Future<List<String>> _foldersIn(String root) async {
    final dir = Directory(root);
    if (!dir.existsSync()) return const [];
    final folders = [p.normalize(root)];
    await for (final e
        in dir
            .list(recursive: true, followLinks: false)
            .handleError((Object _) {})) {
      if (e is Directory && !_hidden(p.relative(e.path, from: root))) {
        folders.add(p.normalize(e.path));
      }
    }
    return folders;
  }

  bool _inHiddenFolder(String path) => _subscriptions.keys.any(
    (root) => p.isWithin(root, path) && _hidden(p.relative(path, from: root)),
  );

  static bool _hidden(String relative) =>
      p.split(relative).any((part) => part.startsWith('.'));

  void _onEvent(FileSystemEvent e) {
    final name = p.basename(e.path);
    if (name.startsWith('.')) return;
    // Watching a whole tree: something in a hidden folder.
    if (recursive && _inHiddenFolder(e.path)) return;
    // Folders matter (new series, removed folders); files only if comics.
    // Deleted folders aren't reported as folders, so also match the
    // folders being watched.
    final folder =
        e.isDirectory ||
        _subscriptions.containsKey(e.path) ||
        // Watching a whole tree, a deleted or moved folder isn't marked as
        // one: a name without an extension is taken for a folder.
        (recursive && e is! FileSystemCreateEvent && p.extension(name).isEmpty);
    if (!folder && !isComicFileName(name)) return;
    _timer?.cancel();
    _timer = Timer(debounce, onChange);
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    for (final s in _subscriptions.values) {
      unawaited(s.cancel());
    }
    _subscriptions.clear();
  }
}

/// Keeps the library up to date without pressing refresh: watches folders
/// on disk ([LibraryWatcher]) and rescans when the app comes back to the
/// foreground ([onResumed]), which covers Android's `content://` folders.
class LibraryRefresh {
  LibraryRefresh(this._ref) {
    _watcher = LibraryWatcher(onChange: _scan);
    // Re-watch after every scan (folders may have come or gone) and when
    // the library folders change.
    _ref
      ..listen(libraryScanProvider, (previous, next) {
        if (previous?.running == true && !next.running) {
          _lastScan = DateTime.now();
          unawaited(_rewatch());
        }
      })
      ..listen(libraryRootsProvider, (_, _) => unawaited(_rewatch()));
    unawaited(_rewatch());
  }

  /// Coming back to the app rescans at most this often.
  static const resumeInterval = Duration(seconds: 30);

  final Ref _ref;
  late final LibraryWatcher _watcher;
  DateTime? _lastScan;

  void _scan() => unawaited(_ref.read(libraryScanProvider.notifier).scan());

  Future<void> _rewatch() async {
    final roots = await _ref.read(databaseProvider).roots();
    await _watcher.watch(roots.map((r) => r.location));
  }

  /// The app is in the foreground again: files may have been added
  /// elsewhere (another app, a USB transfer, a sync client).
  void onResumed() {
    final last = _lastScan;
    if (last != null && DateTime.now().difference(last) < resumeInterval) {
      return;
    }
    _scan();
  }

  void dispose() => _watcher.dispose();
}

final libraryRefreshProvider = Provider<LibraryRefresh>((ref) {
  final refresh = LibraryRefresh(ref);
  ref.onDispose(refresh.dispose);
  return refresh;
});

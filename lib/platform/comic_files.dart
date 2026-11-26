import 'dart:io';

import 'package:path/path.dart' as p;

import 'android_documents.dart';

/// Where an Android library comic lives, for edits: its library folder's
/// tree URI and its `/`-separated path inside.
typedef DocumentPlace = ({String tree, String path});

/// Changes comic files wherever they are: a path, or an Android document in
/// a library folder.
abstract final class ComicFiles {
  /// Finds a library comic's [DocumentPlace] from its location. Set at
  /// startup (it reads the library tables).
  static Future<DocumentPlace?> Function(String location)? placeOf;

  /// Where Android's new versions are written before they replace the
  /// original. Set at startup; the system temp folder otherwise.
  static Directory? workDir;

  /// Rewrites the comic at [location]: [write] reads `source` and writes
  /// the new version, checked, to `target`; only then does it replace the
  /// original. If anything fails the original is left as it was.
  ///
  /// On desktop `target` is beside the original (a hidden name), so the
  /// swap is a rename. On Android it's in app storage and then copied in.
  static Future<T> rewrite<T>(
    String location,
    Future<T> Function(String source, String target) write,
  ) async {
    if (!AndroidDocuments.isContentUri(location)) {
      final target = File(
        p.join(p.dirname(location), '.${p.basename(location)}.panelist-saving'),
      );
      try {
        final result = await write(location, target.path);
        await target.rename(location);
        return result;
      } finally {
        if (target.existsSync()) await target.delete();
      }
    }
    final place = await _place(location);
    final work = workDir ?? Directory.systemTemp;
    await work.create(recursive: true);
    final target = File(
      p.join(work.path, 'saving-${DateTime.now().microsecondsSinceEpoch}'),
    );
    try {
      // A copy, not the document itself: Android can refuse reopening it
      // through /proc/self/fd.
      final doc = await AndroidDocuments.copy(location);
      final T result;
      try {
        result = await write(doc.path, target.path);
      } finally {
        await doc.release?.call();
      }
      final uri = await AndroidDocuments.replace(
        place.tree,
        place.path,
        target.path,
      );
      // Some storage (cards, cloud folders) gives the saved file a new
      // address: the old one is dead.
      if (uri != location) {
        _movedTo[location] = uri;
        await moved?.call(location, uri);
      }
      return result;
    } finally {
      if (target.existsSync()) await target.delete();
    }
  }

  /// Told when saving gave a comic a new address (set in `main`): the
  /// library and reading progress follow it.
  static Future<void> Function(String from, String to)? moved;

  static final _movedTo = <String, String>{};

  /// Where the comic once at [location] is now (see [moved]).
  static String now(String location) {
    var at = location;
    for (var next = _movedTo[at]; next != null; next = _movedTo[at]) {
      at = next;
    }
    return at;
  }

  /// [location]'s file name, for messages (a content URI's last part).
  static String nameOf(String location) =>
      AndroidDocuments.isContentUri(location)
      ? Uri.decodeComponent(location).split(RegExp('[/:]')).last
      : p.basename(location);

  static Future<DocumentPlace> _place(String location) async {
    final place = await placeOf?.call(location);
    if (place == null) {
      throw FileSystemException(
        'Only comics in a library folder can be changed here',
        location,
      );
    }
    if (!await AndroidDocuments.canWrite(place.tree)) {
      throw FileSystemException(
        'Panelist may only read this library folder. Allow editing in '
        'Settings → Library folder.',
        location,
      );
    }
    return place;
  }
}

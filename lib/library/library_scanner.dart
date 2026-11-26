import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../app/providers.dart';
import '../core/imaging/thumbnail.dart';
import '../core/metadata/comic_info.dart';
import '../core/sources/open_source.dart';
import '../core/sources/page_source.dart';
import '../core/util/file_names.dart';
import '../data/database.dart';
import '../platform/android_documents.dart';

/// A comic file found in a library folder.
typedef FoundFile = ({
  String location,
  String folder,
  String name,
  int size,
  int modified,
});

/// What scanning learns by opening a comic.
typedef ScannedComic = ({
  String bookId,
  int pageCount,
  ComicInfo? info,
  Uint8List? cover,

  /// Why its pages can't be read, when it opens but they can't.
  String? problem,
});

bool isComicFileName(String name) {
  final ext = p.extension(name).toLowerCase();
  return ext.length > 1 && comicFileExtensions.contains(ext.substring(1));
}

/// Every comic file under [location] (a path, or an Android tree URI),
/// skipping hidden files and folders.
Future<List<FoundFile>> listLibraryFolder(String location) async {
  if (AndroidDocuments.isContentUri(location)) {
    return [
      for (final f in await AndroidDocuments.listTree(location))
        if (isComicFileName(f.name))
          (
            location: f.uri,
            folder: f.folder,
            name: f.name,
            size: f.size,
            modified: f.modified,
          ),
    ];
  }
  final root = Directory(location);
  if (!await root.exists()) {
    throw FileSystemException('Folder not found', location);
  }
  final found = <FoundFile>[];
  final entities = root
      .list(recursive: true, followLinks: false)
      // An unreadable subfolder shouldn't hide the rest.
      .handleError((Object _) {});
  await for (final e in entities) {
    if (e is! File) continue;
    final parts = p.split(p.relative(e.path, from: location));
    if (parts.any((s) => s.startsWith('.'))) continue;
    if (!isComicFileName(parts.last)) continue;
    final FileStat stat;
    try {
      stat = await e.stat();
    } on FileSystemException {
      continue;
    }
    found.add((
      location: e.path,
      folder: parts.sublist(0, parts.length - 1).join('/'),
      name: parts.last,
      size: stat.size,
      modified: stat.modified.millisecondsSinceEpoch,
    ));
  }
  return found;
}

/// Opens [location] to learn its identity, page count, ComicInfo and cover.
Future<ScannedComic> readComic(String location) async {
  final source = await openSource(location);
  try {
    ComicInfo? info;
    try {
      final xml = await source.readComicInfo();
      info = xml == null ? null : ComicInfo.parse(xml);
    } on Object {
      // Metadata is optional.
    }
    Uint8List? cover;
    String? problem;
    try {
      cover = await renderThumbnail(source);
    } on UnsupportedSourceException catch (e) {
      // It lists but can't be unpacked: still in the list, with the reason.
      problem = e.message;
    } on Object {
      // A comic without a renderable first page still belongs in the list.
    }
    return (
      bookId: source.id,
      pageCount: source.pageCount,
      info: info,
      cover: cover,
      problem: problem,
    );
  } finally {
    await source.close();
  }
}

class ScanStatus {
  const ScanStatus({this.running = false, this.done = 0, this.total = 0});

  final bool running;

  /// Comics read so far in this scan, of [total] new or changed ones.
  final int done;
  final int total;
}

/// Where cover thumbnails are stored, as `<bookId>.png`. Overridden in
/// `main` (and tests).
final coversDirProvider = Provider<Directory>(
  (ref) => throw UnimplementedError('coversDirProvider must be overridden'),
);

/// Opens a comic during scanning; replaced in tests.
final comicReaderProvider = Provider<Future<ScannedComic> Function(String)>(
  (ref) => readComic,
);

final libraryScanProvider = NotifierProvider<LibraryScanner, ScanStatus>(
  LibraryScanner.new,
);

/// Keeps the library tables in step with the library folders. Files whose
/// size and modification time haven't changed are not reopened.
class LibraryScanner extends Notifier<ScanStatus> {
  Future<void>? _running;
  bool _again = false;

  @override
  ScanStatus build() => const ScanStatus();

  /// Scans every library folder. If a scan is already running, another one
  /// follows it (so folders added meanwhile are picked up).
  Future<void> scan() {
    if (_running case final running?) {
      _again = true;
      return running;
    }
    return _running = _loop();
  }

  Future<void> _loop() async {
    try {
      do {
        _again = false;
        await _scanOnce();
      } while (_again);
    } finally {
      _running = null;
      state = const ScanStatus();
    }
  }

  Future<void> _scanOnce() async {
    final db = ref.read(databaseProvider);
    state = const ScanStatus(running: true);

    for (final root in await db.roots()) {
      final List<FoundFile> found;
      try {
        found = await listLibraryFolder(root.location);
      } on Object {
        // Unavailable for now (e.g. storage unmounted): keep what we had.
        continue;
      }
      final existing = {
        for (final e in await db.entriesOf(root.id)) e.location: e,
      };
      final seen = <String>{};
      for (final f in found) {
        seen.add(f.location);
        final old = existing[f.location];
        if (old != null && old.size == f.size && old.modified == f.modified) {
          continue;
        }
        await db.putEntry(
          LibraryEntriesCompanion.insert(
            location: f.location,
            rootId: root.id,
            folder: f.folder,
            fileName: f.name,
            size: f.size,
            modified: f.modified,
            bookId: const Value(null),
            error: const Value(null),
          ),
        );
      }
      final gone = existing.keys.where((l) => !seen.contains(l)).toList();
      if (gone.isNotEmpty) await db.deleteEntries(gone);
    }

    final pending = [
      for (final root in await db.roots())
        for (final e in await db.entriesOf(root.id))
          if (e.bookId == null && e.error == null) e,
    ];
    final read = ref.read(comicReaderProvider);
    final covers = ref.read(coversDirProvider);
    await covers.create(recursive: true);
    for (final (i, e) in pending.indexed) {
      if (!ref.mounted) return;
      state = ScanStatus(running: true, done: i, total: pending.length);
      try {
        final c = await read(e.location);
        if (c.cover case final png?) {
          await File(p.join(covers.path, '${idFileName(c.bookId)}.png'))
              .writeAsBytes(png);
        }
        final info = c.info;
        await db.updateEntry(
          e.location,
          LibraryEntriesCompanion(
            bookId: Value(c.bookId),
            pageCount: Value(c.pageCount),
            series: Value(info?.series),
            number: Value(info?.number),
            volume: Value(info?.volume),
            year: Value(info?.year),
            publisher: Value(info?.publisher),
            title: Value(info?.title),
            error: Value(c.problem),
          ),
        );
      } on Object catch (error) {
        await db.updateEntry(
          e.location,
          LibraryEntriesCompanion(error: Value('$error')),
        );
      }
    }
    if (ref.mounted) await _removeUnusedCovers(db, covers);
  }

  /// Deletes covers of comics no longer in the library.
  Future<void> _removeUnusedCovers(AppDatabase db, Directory covers) async {
    final used = {
      for (final root in await db.roots())
        for (final e in await db.entriesOf(root.id))
          if (e.bookId case final id?) '${idFileName(id)}.png',
    };
    await for (final f in covers.list()) {
      if (f is File && !used.contains(p.basename(f.path))) {
        try {
          await f.delete();
        } on FileSystemException {
          // Try again next scan.
        }
      }
    }
  }
}

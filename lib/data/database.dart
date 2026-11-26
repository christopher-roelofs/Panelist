import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../share/share_protocol.dart';

part 'database.g.dart';

/// Every book the user has opened, keyed by [PageSource.id].
class Books extends Table {
  TextColumn get id => text()();
  TextColumn get path => text()();
  TextColumn get title => text()();
  IntColumn get pageCount => integer()();
  IntColumn get currentPage => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastOpened => dateTime()();
  BlobColumn get cover => blob().nullable()();

  // ComicInfo.xml metadata
  TextColumn get series => text().nullable()();
  TextColumn get number => text().nullable()();
  IntColumn get year => integer().nullable()();
  TextColumn get writer => text().nullable()();
  TextColumn get artist => text().nullable()();
  TextColumn get summary => text().nullable()();
  BoolColumn get rightToLeft => boolean().nullable()();
  TextColumn get publisher => text().nullable()();

  /// Read to the end (or marked read). Stays set when paging back or
  /// re-reading, until the book is marked unread.
  BoolColumn get finished => boolean().withDefault(const Constant(false))();

  /// When the reading position or finished flag last changed (here or by
  /// sync); null if never. Syncing compares these: the latest wins.
  DateTimeColumn get progressUpdated => dateTime().nullable()();

  /// Cached page sizes, JSON `[[w,h] | null, ...]`.
  TextColumn get pageSizes => text().nullable()();

  // Per-book reader settings (null = use the global default).
  TextColumn get fitMode => text().nullable()();
  TextColumn get layoutMode => text().nullable()();
  BoolColumn get coverAlone => boolean().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Simple key/value app settings.
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// A folder the library is built from: a path, or on Android a
/// `content://` tree URI with persisted read access.
class LibraryRoots extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get location => text().unique()();
  TextColumn get name => text()();
}

/// A comic file found in a library folder. Metadata here is what the file's
/// ComicInfo.xml says (null when absent); names parsed from file and folder
/// names are derived at display time so parser fixes need no rescan.
class LibraryEntries extends Table {
  /// File path, or on Android the document URI.
  TextColumn get location => text()();
  IntColumn get rootId => integer()();

  /// Folder inside the root, `/`-separated; empty at the root itself.
  TextColumn get folder => text()();
  TextColumn get fileName => text()();
  IntColumn get size => integer()();

  /// Modification time, ms since the epoch (0 if unknown).
  IntColumn get modified => integer()();

  /// The book's [Books.id] (content fingerprint), once scanned.
  TextColumn get bookId => text().nullable()();
  IntColumn get pageCount => integer().nullable()();
  TextColumn get series => text().nullable()();
  TextColumn get number => text().nullable()();
  IntColumn get volume => integer().nullable()();
  IntColumn get year => integer().nullable()();
  TextColumn get publisher => text().nullable()();
  TextColumn get title => text().nullable()();

  /// Why the last scan couldn't read this file, if it couldn't.
  TextColumn get error => text().nullable()();

  @override
  Set<Column> get primaryKey => {location};
}

/// Reading position of a book, without the heavier columns.
typedef BookProgress = ({int currentPage, int pageCount, bool finished});

/// [Books.lastOpened] of a book that isn't in recent books: marked read
/// without being opened, marked unread, or removed from recent.
final notRecent = DateTime.fromMillisecondsSinceEpoch(0);

/// A device paired with this computer's shared library.
class PairedDevices extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();

  /// SHA-256 of the device's token (the token itself isn't kept).
  TextColumn get tokenHash => text().unique()();
  DateTimeColumn get added => dateTime()();
  DateTimeColumn get lastSeen => dateTime().nullable()();
}

/// A computer's shared library this device has paired with.
class RemoteLibraries extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// The computer's library ID (it stays when the address changes).
  TextColumn get serverId => text().unique()();
  TextColumn get name => text()();

  /// `host:port` last reached at.
  TextColumn get address => text()();
  TextColumn get token => text()();

  /// The server's time of the last sync (changes after it are fetched
  /// next), or null before the first.
  DateTimeColumn get syncedUntil => dateTime().nullable()();

  /// This device's time when it last sent its changes (changes after it go
  /// next), or null before the first.
  DateTimeColumn get sentUntil => dateTime().nullable()();
}

@DriftDatabase(
  tables: [
    Books,
    Settings,
    LibraryRoots,
    LibraryEntries,
    PairedDevices,
    RemoteLibraries,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(
        executor ??
            driftDatabase(
              name: 'panelist',
              // Not the default documents dir (~/Documents on Linux).
              native: const DriftNativeOptions(
                databaseDirectory: getApplicationSupportDirectory,
              ),
            ),
      );

  @override
  int get schemaVersion => 1;

  Future<Book?> book(String id) =>
      (select(books)..where((b) => b.id.equals(id))).getSingleOrNull();

  /// Records that a book was opened (from [path]), keeping its saved
  /// progress and cover. Returns the stored row.
  Future<Book> recordOpened({
    required String id,
    required String path,
    required String title,
    required int pageCount,
  }) async {
    final now = DateTime.now();
    await into(books).insert(
      BooksCompanion.insert(
        id: id,
        path: path,
        title: title,
        pageCount: pageCount,
        lastOpened: now,
      ),
      onConflict: DoUpdate(
        (_) => BooksCompanion(
          path: Value(path),
          title: Value(title),
          pageCount: Value(pageCount),
          lastOpened: Value(now),
        ),
      ),
    );
    return (await book(id))!;
  }

  /// Saves the reading position; reaching the last page finishes the book.
  Future<void> saveProgress(String id, int page) =>
      (update(books)..where((b) => b.id.equals(id))).write(
        BooksCompanion.custom(
          currentPage: Variable(page),
          progressUpdated: Variable(DateTime.now()),
          finished:
              books.finished |
              Variable(page)
                  .isBiggerOrEqual(books.pageCount - const Constant(1)),
        ),
      );

  Future<void> saveCover(String id, Uint8List png) => (update(
    books,
  )..where((b) => b.id.equals(id))).write(BooksCompanion(cover: Value(png)));

  /// Stores ComicInfo-derived metadata. Pass the fields to set.
  Future<void> saveMetadata(String id, BooksCompanion metadata) =>
      (update(books)..where((b) => b.id.equals(id))).write(metadata);

  Future<void> savePageSizes(String id, String json) =>
      (update(books)..where((b) => b.id.equals(id))).write(
        BooksCompanion(pageSizes: Value(json)),
      );

  Future<void> saveBookSettings(
    String id, {
    required String fitMode,
    required String layoutMode,
    required bool coverAlone,
  }) => (update(books)..where((b) => b.id.equals(id))).write(
    BooksCompanion(
      fitMode: Value(fitMode),
      layoutMode: Value(layoutMode),
      coverAlone: Value(coverAlone),
    ),
  );

  /// Marks books read, keeping their place. Books never opened get a row
  /// that isn't in recent books.
  Future<void> markRead(
    Iterable<({String id, String path, String title, int pageCount})> items,
  ) => transaction(() async {
    final now = DateTime.now();
    for (final b in items) {
      await into(books).insert(
        BooksCompanion.insert(
          id: b.id,
          path: b.path,
          title: b.title,
          pageCount: b.pageCount,
          lastOpened: notRecent,
          finished: const Value(true),
          progressUpdated: Value(now),
        ),
        onConflict: DoUpdate(
          (_) => BooksCompanion(
            finished: const Value(true),
            progressUpdated: Value(now),
          ),
        ),
      );
    }
  });

  /// Marks books unread: back to the first page and out of recent books.
  /// Their reader settings and cached page sizes are kept.
  Future<void> markUnread(Iterable<String> ids) =>
      (update(books)..where((b) => b.id.isIn(ids))).write(
        BooksCompanion(
          finished: const Value(false),
          currentPage: const Value(0),
          lastOpened: Value(notRecent),
          progressUpdated: Value(DateTime.now()),
        ),
      );

  // --- Sharing (M7) ----------------------------------------------------

  Future<PairedDevice?> pairedDevice(String tokenHash) => (select(
    pairedDevices,
  )..where((d) => d.tokenHash.equals(tokenHash))).getSingleOrNull();

  Future<int> addPairedDevice({
    required String name,
    required String tokenHash,
    required DateTime added,
  }) => into(pairedDevices).insert(
    PairedDevicesCompanion.insert(
      name: name,
      tokenHash: tokenHash,
      added: added,
    ),
  );

  Future<void> devicePresent(int id, DateTime when) =>
      (update(pairedDevices)..where((d) => d.id.equals(id))).write(
        PairedDevicesCompanion(lastSeen: Value(when)),
      );

  Future<void> removePairedDevice(int id) =>
      (delete(pairedDevices)..where((d) => d.id.equals(id))).go();

  Stream<List<PairedDevice>> watchPairedDevices() => (select(
    pairedDevices,
  )..orderBy([(d) => OrderingTerm(expression: d.added)])).watch();

  Stream<List<RemoteLibrary>> watchRemoteLibraries() => (select(
    remoteLibraries,
  )..orderBy([(r) => OrderingTerm(expression: r.name)])).watch();

  Future<List<RemoteLibrary>> remoteLibraryList() =>
      select(remoteLibraries).get();

  /// Adds a paired library, or updates the one with the same [serverId]
  /// (paired again). Returns its row ID.
  Future<int> saveRemoteLibrary({
    required String serverId,
    required String name,
    required String address,
    required String token,
  }) async {
    await into(remoteLibraries).insert(
      RemoteLibrariesCompanion.insert(
        serverId: serverId,
        name: name,
        address: address,
        token: token,
      ),
      onConflict: DoUpdate(
        (_) => RemoteLibrariesCompanion(
          name: Value(name),
          address: Value(address),
          token: Value(token),
        ),
        target: [remoteLibraries.serverId],
      ),
    );
    return (await (select(
      remoteLibraries,
    )..where((r) => r.serverId.equals(serverId))).getSingle()).id;
  }

  Future<void> updateRemoteLibrary(int id, RemoteLibrariesCompanion data) =>
      (update(remoteLibraries)..where((r) => r.id.equals(id))).write(data);

  Future<void> removeRemoteLibrary(int id) =>
      (delete(remoteLibraries)..where((r) => r.id.equals(id))).go();

  /// Names books that synced before their library's list was here (so
  /// were titled by their ID): [titles] maps book ID to title.
  Future<void> nameUntitledBooks(Map<String, String> titles) =>
      transaction(() async {
        for (final MapEntry(key: id, value: title) in titles.entries) {
          await (update(books)
                ..where((b) => b.id.equals(id) & b.title.equals(id)))
              .write(BooksCompanion(title: Value(title)));
        }
      });

  /// Applies a reading position from another device if it's newer than
  /// what's here (the latest change wins). A book never opened here gets a
  /// row at [path]; one being read (not finished, past the first page)
  /// shows in Continue reading.
  Future<bool> applyProgress(
    ProgressChange c, {
    required String path,
    required String title,
  }) => transaction(() async {
    final old = await book(c.id);
    final mine = old?.progressUpdated;
    if (mine != null && !c.updated.isAfter(mine)) return false;
    final reading = !c.finished && c.page > 0;
    if (old == null) {
      await into(books).insert(
        BooksCompanion.insert(
          id: c.id,
          path: path,
          title: title,
          pageCount: c.pageCount,
          currentPage: Value(c.page),
          finished: Value(c.finished),
          progressUpdated: Value(c.updated),
          lastOpened: reading ? c.updated : notRecent,
        ),
      );
    } else {
      await (update(books)..where((b) => b.id.equals(c.id))).write(
        BooksCompanion(
          currentPage: Value(c.page),
          finished: Value(c.finished),
          progressUpdated: Value(c.updated),
          lastOpened: reading && c.updated.isAfter(old.lastOpened)
              ? Value(c.updated)
              : const Value.absent(),
        ),
      );
    }
    return true;
  });

  /// Reading positions changed since [since] (all of them when null). Times
  /// are stored to the second, so one in the same second is included: a
  /// change sent twice is harmless, one never sent isn't.
  Future<List<ProgressChange>> progressChangedSince(DateTime? since) async {
    final q = select(books)
      ..where(
        (b) => since == null
            ? b.progressUpdated.isNotNull()
            : b.progressUpdated.isBiggerOrEqualValue(since),
      );
    return [
      for (final b in await q.get())
        ProgressChange(
          id: b.id,
          page: b.currentPage,
          pageCount: b.pageCount,
          finished: b.finished,
          updated: b.progressUpdated!.toUtc(),
        ),
    ];
  }

  /// A book's file was converted or moved: its progress, settings and place
  /// in recent books now belong to [newId] at [path]. If [newId] already
  /// has a row (it was opened too), the one opened last wins.
  Future<void> moveBook(String oldId, String newId, String path) =>
      transaction(() async {
        final old = await book(oldId);
        if (old == null) return;
        final existing = oldId == newId ? null : await book(newId);
        final keep =
            existing != null && existing.lastOpened.isAfter(old.lastOpened)
            ? existing
            : old;
        await (delete(books)..where((b) => b.id.isIn({oldId, newId}))).go();
        await into(books).insert(keep.copyWith(id: newId, path: path));
      });

  /// Takes a book out of recent books, keeping its progress and settings.
  Future<void> removeFromRecent(String id) =>
      (update(books)..where((b) => b.id.equals(id))).write(
        BooksCompanion(lastOpened: Value(notRecent)),
      );

  Stream<List<Book>> watchRecent({int limit = 30}) =>
      (select(books)
            ..where((b) => b.lastOpened.isBiggerThanValue(notRecent))
            ..orderBy([(b) => OrderingTerm.desc(b.lastOpened)])
            ..limit(limit))
          .watch();

  Future<String?> setting(String key) async => (await (select(
    settings,
  )..where((s) => s.key.equals(key))).getSingleOrNull())?.value;

  Future<void> setSetting(String key, String value) => into(settings)
      .insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));

  // --- Library ---

  Stream<List<LibraryRoot>> watchRoots() => (select(
    libraryRoots,
  )..orderBy([(r) => OrderingTerm.asc(r.name)])).watch();

  Future<List<LibraryRoot>> roots() => select(libraryRoots).get();

  /// Adds a library folder (no-op if it's already there).
  Future<void> addRoot(String location, String name) =>
      into(libraryRoots).insert(
        LibraryRootsCompanion.insert(location: location, name: name),
        mode: InsertMode.insertOrIgnore,
      );

  /// Makes [location] the one library folder: other folders leave the
  /// library (their files and reading progress are kept).
  Future<void> setLibraryFolder(String location, String name) =>
      transaction(() async {
        final others = await (select(
          libraryRoots,
        )..where((r) => r.location.equals(location).not())).get();
        for (final r in others) {
          await removeRoot(r.id);
        }
        await addRoot(location, name);
      });

  Future<void> removeRoot(int id) => transaction(() async {
    await (delete(libraryEntries)..where((e) => e.rootId.equals(id))).go();
    await (delete(libraryRoots)..where((r) => r.id.equals(id))).go();
  });

  Stream<List<LibraryEntry>> watchEntries() => select(libraryEntries).watch();

  Future<List<LibraryEntry>> entriesOf(int rootId) =>
      (select(libraryEntries)..where((e) => e.rootId.equals(rootId))).get();

  Future<void> putEntry(LibraryEntriesCompanion entry) =>
      into(libraryEntries).insertOnConflictUpdate(entry);

  Future<void> updateEntry(String location, LibraryEntriesCompanion data) =>
      (update(
        libraryEntries,
      )..where((e) => e.location.equals(location))).write(data);

  Future<void> deleteEntries(Iterable<String> locations) =>
      (delete(libraryEntries)..where((e) => e.location.isIn(locations))).go();

  /// Progress of every book that has been opened, by [Books.id].
  Stream<Map<String, BookProgress>> watchProgress() {
    final q = selectOnly(books)
      ..addColumns([
        books.id,
        books.currentPage,
        books.pageCount,
        books.finished,
      ]);
    return q.watch().map(
      (rows) => {
        for (final r in rows)
          r.read(books.id)!: (
            currentPage: r.read(books.currentPage)!,
            pageCount: r.read(books.pageCount)!,
            finished: r.read(books.finished)!,
          ),
      },
    );
  }
}

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

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

  // --- v2: ComicInfo.xml metadata ---
  TextColumn get series => text().nullable()();
  TextColumn get number => text().nullable()();
  IntColumn get year => integer().nullable()();
  TextColumn get writer => text().nullable()();
  TextColumn get artist => text().nullable()();
  TextColumn get summary => text().nullable()();
  BoolColumn get rightToLeft => boolean().nullable()();

  // --- v2: cached page sizes, JSON `[[w,h] | null, ...]` ---
  TextColumn get pageSizes => text().nullable()();

  // --- v2: per-book reader settings (null = use the global default) ---
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

@DriftDatabase(tables: [Books, Settings])
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
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        for (final column in [
          books.series,
          books.number,
          books.year,
          books.writer,
          books.artist,
          books.summary,
          books.rightToLeft,
          books.pageSizes,
          books.fitMode,
          books.layoutMode,
          books.coverAlone,
        ]) {
          await m.addColumn(books, column);
        }
      }
    },
  );

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

  Future<void> saveProgress(String id, int page) =>
      (update(books)..where((b) => b.id.equals(id))).write(
        BooksCompanion(currentPage: Value(page)),
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

  Future<void> forget(String id) =>
      (delete(books)..where((b) => b.id.equals(id))).go();

  Stream<List<Book>> watchRecent({int limit = 30}) =>
      (select(books)
            ..orderBy([(b) => OrderingTerm.desc(b.lastOpened)])
            ..limit(limit))
          .watch();

  Future<String?> setting(String key) async => (await (select(
    settings,
  )..where((s) => s.key.equals(key))).getSingleOrNull())?.value;

  Future<void> setSetting(String key, String value) => into(settings)
      .insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));
}

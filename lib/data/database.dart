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

  Future<void> saveProgress(String id, int page) =>
      (update(books)..where((b) => b.id.equals(id))).write(
        BooksCompanion(currentPage: Value(page)),
      );

  Future<void> saveCover(String id, Uint8List png) => (update(
    books,
  )..where((b) => b.id.equals(id))).write(BooksCompanion(cover: Value(png)));

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

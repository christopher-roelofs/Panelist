import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../data/database.dart';
import 'library_model.dart';
import 'publisher_aliases.dart';

final libraryRootsProvider = StreamProvider<List<LibraryRoot>>(
  (ref) => ref.watch(databaseProvider).watchRoots(),
);

final _entriesProvider = StreamProvider<List<LibraryEntry>>(
  (ref) => ref.watch(databaseProvider).watchEntries(),
);

/// Every book's reading progress, by book ID.
final bookProgressProvider = StreamProvider<Map<String, BookProgress>>(
  (ref) => ref.watch(databaseProvider).watchProgress(),
);

/// Every comic in the library, with reading progress, and publishers named
/// by the user's rules.
final libraryComicsProvider = Provider<List<LibraryComic>>((ref) {
  final entries = ref.watch(_entriesProvider).value ?? const [];
  final progress = ref.watch(bookProgressProvider).value ?? const {};
  final aliases =
      ref.watch(publisherAliasesProvider).value ?? const PublisherAliases();
  return [
    for (final e in entries)
      LibraryComic(
        e,
        e.bookId == null ? null : progress[e.bookId],
        publisher: aliases.apply(e.publisher),
      ),
  ];
});

enum LibraryView { folders, series, publishers }

enum LibraryLayout { grid, list }

typedef LibraryPrefs = ({LibraryView view, LibraryLayout layout});

final libraryPrefsProvider =
    NotifierProvider<LibraryPrefsNotifier, LibraryPrefs>(
      LibraryPrefsNotifier.new,
    );

/// The library's last-used view and layout.
class LibraryPrefsNotifier extends Notifier<LibraryPrefs> {
  LibraryPrefsNotifier([
    this._initial = (view: LibraryView.series, layout: LibraryLayout.grid),
  ]);

  static const _viewKey = 'library.view';
  static const _layoutKey = 'library.layout';

  static Future<LibraryPrefs> load(AppDatabase db) async {
    T pick<T extends Enum>(List<T> values, String? name, T fallback) =>
        values.where((v) => v.name == name).firstOrNull ?? fallback;
    return (
      view: pick(
        LibraryView.values,
        await db.setting(_viewKey),
        LibraryView.series,
      ),
      layout: pick(
        LibraryLayout.values,
        await db.setting(_layoutKey),
        LibraryLayout.grid,
      ),
    );
  }

  final LibraryPrefs _initial;

  @override
  LibraryPrefs build() => _initial;

  void setView(LibraryView view) {
    state = (view: view, layout: state.layout);
    unawaited(ref.read(databaseProvider).setSetting(_viewKey, view.name));
  }

  void setLayout(LibraryLayout layout) {
    state = (view: state.view, layout: layout);
    unawaited(ref.read(databaseProvider).setSetting(_layoutKey, layout.name));
  }
}

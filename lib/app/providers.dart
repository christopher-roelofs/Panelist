import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../reader/reader_settings.dart';

/// Overridden in `main` (and in tests) with a real database.
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden'),
);

final recentBooksProvider = StreamProvider<List<Book>>(
  (ref) => ref.watch(databaseProvider).watchRecent(),
);

final readerDefaultsProvider =
    NotifierProvider<ReaderDefaultsNotifier, ReaderSettings>(
      ReaderDefaultsNotifier.new,
    );

/// Reader settings for books that haven't been customised. Follows the
/// user's most recent choice in the reader.
class ReaderDefaultsNotifier extends Notifier<ReaderSettings> {
  ReaderDefaultsNotifier([this._initial = const ReaderSettings()]);

  static const _fitKey = 'reader.fitMode';
  static const _layoutKey = 'reader.layoutMode';
  static const _coverKey = 'reader.coverAlone';

  /// Loads the stored defaults (call before building the app).
  static Future<ReaderSettings> load(AppDatabase db) async =>
      ReaderSettings.parse(
        fit: await db.setting(_fitKey),
        layout: await db.setting(_layoutKey),
        coverAlone: switch (await db.setting(_coverKey)) {
          'true' => true,
          'false' => false,
          _ => null,
        },
      );

  final ReaderSettings _initial;

  @override
  ReaderSettings build() => _initial;

  void set(ReaderSettings settings) {
    state = settings;
    final db = ref.read(databaseProvider);
    unawaited(db.setSetting(_fitKey, settings.fit.name));
    unawaited(db.setSetting(_layoutKey, settings.layout.name));
    unawaited(db.setSetting(_coverKey, '${settings.coverAlone}'));
  }
}

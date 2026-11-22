import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../reader/fit_mode.dart';

/// Overridden in `main` (and in tests) with a real database.
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden'),
);

final recentBooksProvider = StreamProvider<List<Book>>(
  (ref) => ref.watch(databaseProvider).watchRecent(),
);

final fitModeProvider = NotifierProvider<FitModeNotifier, FitMode>(
  FitModeNotifier.new,
);

/// The reader's fit mode, persisted as a global setting.
class FitModeNotifier extends Notifier<FitMode> {
  FitModeNotifier([this._initial = FitMode.screen]);

  static const settingKey = 'reader.fitMode';

  static FitMode parse(String? name) =>
      FitMode.values.asNameMap()[name] ?? FitMode.screen;

  final FitMode _initial;

  @override
  FitMode build() => _initial;

  void set(FitMode mode) {
    state = mode;
    unawaited(ref.read(databaseProvider).setSetting(settingKey, mode.name));
  }
}

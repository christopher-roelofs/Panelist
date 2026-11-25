import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:panelist/app/providers.dart';
import 'package:panelist/app/theme.dart';
import 'package:panelist/data/database.dart';

/// How far a colour is from grey (0 = no tint).
int tint(Color c) {
  final rgb = [c.r, c.g, c.b].map((v) => (v * 255).round()).toList();
  return rgb.reduce((a, b) => a > b ? a : b) -
      rgb.reduce((a, b) => a < b ? a : b);
}

void main() {
  test('backgrounds stay neutral whatever the accent', () {
    for (final accent in AppAccent.values) {
      for (final b in Brightness.values) {
        final s = buildColorScheme(accent, b);
        for (final c in [
          s.surface,
          s.surfaceContainer,
          s.surfaceContainerHighest,
        ]) {
          expect(tint(c), lessThanOrEqualTo(2), reason: '$accent $b $c');
        }
        if (accent != AppAccent.grey) {
          expect(tint(s.primary), greaterThan(20), reason: '$accent $b');
        }
      }
    }
  });

  test('accents are distinguishable', () {
    final fills = {
      for (final a in AppAccent.values.where((a) => a.seed != null))
        a: buildColorScheme(a, Brightness.dark).secondaryContainer,
    };
    for (final a in fills.keys) {
      for (final b in fills.keys) {
        if (a.index >= b.index) continue;
        final d = [
          (fills[a]!.r - fills[b]!.r).abs(),
          (fills[a]!.g - fills[b]!.g).abs(),
          (fills[a]!.b - fills[b]!.b).abs(),
        ].reduce((x, y) => x + y);
        expect(d * 255, greaterThan(30), reason: '$a vs $b');
      }
    }
  });

  test('black mode uses true black', () {
    final s = buildColorScheme(AppAccent.blue, Brightness.dark, black: true);
    expect(s.surface, Colors.black);
  });

  test('wallpaper colours are used when available, else slate', () {
    final system = ColorScheme.fromSeed(
      seedColor: Colors.green,
      brightness: Brightness.dark,
    );
    expect(
      buildColorScheme(
        AppAccent.wallpaper,
        Brightness.dark,
        system: system,
      ).primary,
      system.primary,
    );
    expect(
      buildColorScheme(AppAccent.wallpaper, Brightness.dark).primary,
      buildColorScheme(AppAccent.blue, Brightness.dark).primary,
    );
  });

  test('the choice is saved', () async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(await AppThemeNotifier.load(db), defaultAppTheme);
    final c = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(c.dispose);
    c.read(appThemeProvider.notifier)
      ..setMode(AppThemeMode.black)
      ..setAccent(AppAccent.teal);
    await Future<void>.delayed(Duration.zero);
    expect(await AppThemeNotifier.load(db), (
      mode: AppThemeMode.black,
      accent: AppAccent.teal,
    ));
  });
}

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../data/database.dart';
import 'providers.dart';

/// Light/dark choice. [black] is dark with true-black backgrounds (OLED).
enum AppThemeMode { system, light, dark, black }

/// Accent colours. [wallpaper] uses the Android 12+ system palette and
/// falls back to [blue] where there isn't one; [grey] has no colour at all.
enum AppAccent {
  wallpaper('Wallpaper', null),
  grey('Grey', Color(0xFF808080)),
  blue('Blue', Color(0xFF2F6FED)),
  teal('Teal', Color(0xFF00897B)),
  green('Green', Color(0xFF3E8E41)),
  purple('Purple', Color(0xFF7E57C2)),
  pink('Pink', Color(0xFFD81B60)),
  amber('Amber', Color(0xFFF2A900)),
  orange('Orange', Color(0xFFE65100));

  const AppAccent(this.label, this.seed);

  final String label;
  final Color? seed;
}

typedef AppTheme = ({AppThemeMode mode, AppAccent accent});

const defaultAppTheme = (mode: AppThemeMode.dark, accent: AppAccent.blue);

final appThemeProvider = NotifierProvider<AppThemeNotifier, AppTheme>(
  AppThemeNotifier.new,
);

class AppThemeNotifier extends Notifier<AppTheme> {
  AppThemeNotifier([this._initial = defaultAppTheme]);

  static const _modeKey = 'theme.mode';
  static const _accentKey = 'theme.accent';

  static Future<AppTheme> load(AppDatabase db) async {
    T pick<T extends Enum>(List<T> values, String? name, T fallback) =>
        values.where((v) => v.name == name).firstOrNull ?? fallback;
    return (
      mode: pick(
        AppThemeMode.values,
        await db.setting(_modeKey),
        defaultAppTheme.mode,
      ),
      accent: pick(
        AppAccent.values,
        await db.setting(_accentKey),
        defaultAppTheme.accent,
      ),
    );
  }

  final AppTheme _initial;

  @override
  AppTheme build() => _initial;

  void setMode(AppThemeMode mode) {
    state = (mode: mode, accent: state.accent);
    unawaited(ref.read(databaseProvider).setSetting(_modeKey, mode.name));
  }

  void setAccent(AppAccent accent) {
    state = (mode: state.mode, accent: accent);
    unawaited(ref.read(databaseProvider).setSetting(_accentKey, accent.name));
  }
}

ThemeMode themeModeOf(AppThemeMode mode) => switch (mode) {
  AppThemeMode.system => ThemeMode.system,
  AppThemeMode.light => ThemeMode.light,
  AppThemeMode.dark || AppThemeMode.black => ThemeMode.dark,
};

/// A colour scheme with the accent's colours on buttons and highlights but
/// neutral grey backgrounds (Material's default tints every surface with the
/// accent, which turns a warm accent brown).
///
/// [system] is the wallpaper palette, used for [AppAccent.wallpaper].
ColorScheme buildColorScheme(
  AppAccent accent,
  Brightness brightness, {
  bool black = false,
  ColorScheme? system,
}) {
  final accented =
      (accent == AppAccent.wallpaper ? system : null) ??
      ColorScheme.fromSeed(
        seedColor: accent.seed ?? AppAccent.blue.seed!,
        brightness: brightness,
        // Keeps the seed's saturation (the default evens it out, which made
        // similar hues look identical).
        dynamicSchemeVariant: accent == AppAccent.grey
            ? DynamicSchemeVariant.monochrome
            : DynamicSchemeVariant.fidelity,
      );
  final neutral = ColorScheme.fromSeed(
    seedColor: const Color(0xFF808080),
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.monochrome,
  );
  var scheme = accented.copyWith(
    surface: neutral.surface,
    onSurface: neutral.onSurface,
    onSurfaceVariant: neutral.onSurfaceVariant,
    surfaceDim: neutral.surfaceDim,
    surfaceBright: neutral.surfaceBright,
    surfaceContainerLowest: neutral.surfaceContainerLowest,
    surfaceContainerLow: neutral.surfaceContainerLow,
    surfaceContainer: neutral.surfaceContainer,
    surfaceContainerHigh: neutral.surfaceContainerHigh,
    surfaceContainerHighest: neutral.surfaceContainerHighest,
    outline: neutral.outline,
    outlineVariant: neutral.outlineVariant,
    inverseSurface: neutral.inverseSurface,
    onInverseSurface: neutral.onInverseSurface,
  );
  if (black) {
    scheme = scheme.copyWith(
      surface: Colors.black,
      surfaceDim: Colors.black,
      surfaceContainerLowest: Colors.black,
      surfaceContainerLow: const Color(0xFF0C0C0C),
      surfaceContainer: const Color(0xFF141414),
      surfaceContainerHigh: const Color(0xFF1C1C1C),
      surfaceContainerHighest: const Color(0xFF262626),
    );
  }
  return scheme;
}

ThemeData buildTheme(ColorScheme scheme) => ThemeData(colorScheme: scheme);

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../data/database.dart';
import 'providers.dart';

/// Light/dark choice. [black] is dark with true-black backgrounds (OLED).
enum AppThemeMode { system, light, dark, black }

/// Accent colours. [system] uses the system's colour (Android 12+ from the
/// wallpaper, the accent colour on Windows and macOS) and
/// falls back to [blue] where there isn't one; [grey] has no colour at all.
enum AppAccent {
  system('System', null),
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

/// Background colours: [accent] a tint of the accent colour, [grey]
/// neutral (the default), the rest a fixed tint whatever the accent. Black
/// mode stays black.
enum AppBackground {
  accent('Accent', null),
  grey('Grey', null),
  warm('Warm', Color(0xFFC08040)),
  cool('Cool', Color(0xFF4070C0)),
  green('Green', Color(0xFF4C8C5A)),
  rose('Rose', Color(0xFFC0607A));

  const AppBackground(this.label, this.seed);

  final String label;
  final Color? seed;
}

typedef AppTheme = ({
  AppThemeMode mode,
  AppAccent accent,
  AppBackground background,
});

const AppTheme defaultAppTheme = (
  mode: AppThemeMode.dark,
  accent: AppAccent.blue,
  background: AppBackground.grey,
);

final appThemeProvider = NotifierProvider<AppThemeNotifier, AppTheme>(
  AppThemeNotifier.new,
);

class AppThemeNotifier extends Notifier<AppTheme> {
  AppThemeNotifier([this._initial = defaultAppTheme]);

  static const _modeKey = 'theme.mode';
  static const _accentKey = 'theme.accent';
  static const _backgroundKey = 'theme.background';

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
      background: pick(
        AppBackground.values,
        await db.setting(_backgroundKey),
        defaultAppTheme.background,
      ),
    );
  }

  final AppTheme _initial;

  @override
  AppTheme build() => _initial;

  void setMode(AppThemeMode mode) {
    state = (mode: mode, accent: state.accent, background: state.background);
    unawaited(ref.read(databaseProvider).setSetting(_modeKey, mode.name));
  }

  void setAccent(AppAccent accent) {
    state = (mode: state.mode, accent: accent, background: state.background);
    unawaited(ref.read(databaseProvider).setSetting(_accentKey, accent.name));
  }

  void setBackground(AppBackground background) {
    state = (mode: state.mode, accent: state.accent, background: background);
    unawaited(
      ref.read(databaseProvider).setSetting(_backgroundKey, background.name),
    );
  }
}

ThemeMode themeModeOf(AppThemeMode mode) => switch (mode) {
  AppThemeMode.system => ThemeMode.system,
  AppThemeMode.light => ThemeMode.light,
  AppThemeMode.dark || AppThemeMode.black => ThemeMode.dark,
};

/// A colour scheme with the accent's colours on buttons and highlights and
/// [background]'s on surfaces: neutral grey by default (Material's default
/// tints every surface with the accent, which turns a warm accent brown).
///
/// [system] is the system's palette, used for [AppAccent.system].
ColorScheme buildColorScheme(
  AppAccent accent,
  Brightness brightness, {
  AppBackground background = AppBackground.grey,
  bool black = false,
  ColorScheme? system,
}) {
  final accented =
      (accent == AppAccent.system ? system : null) ??
      ColorScheme.fromSeed(
        seedColor: accent.seed ?? AppAccent.blue.seed!,
        brightness: brightness,
        // Keeps the seed's saturation (the default evens it out, which made
        // similar hues look identical).
        dynamicSchemeVariant: accent == AppAccent.grey
            ? DynamicSchemeVariant.monochrome
            : DynamicSchemeVariant.fidelity,
      );
  final tint = switch (background) {
    AppBackground.grey => null,
    AppBackground.accent => accent == AppAccent.grey ? null : accented.primary,
    _ => background.seed,
  };
  final neutral = ColorScheme.fromSeed(
    seedColor: tint ?? const Color(0xFF808080),
    brightness: brightness,
    // A visible tint, still quiet enough to read on.
    dynamicSchemeVariant: tint == null
        ? DynamicSchemeVariant.monochrome
        : DynamicSchemeVariant.vibrant,
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

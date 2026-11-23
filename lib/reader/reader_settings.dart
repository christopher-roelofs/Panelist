import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart' show Size;

import 'fit_mode.dart';
import 'spreads.dart';

/// How a book is displayed. Stored per book, with a global default that
/// follows the user's most recent choice.
@immutable
class ReaderSettings {
  const ReaderSettings({
    this.fit = FitMode.screen,
    this.layout = LayoutMode.auto,
    this.coverAlone = true,
  });

  /// Builds settings from stored values, falling back field by field.
  factory ReaderSettings.parse({
    String? fit,
    String? layout,
    bool? coverAlone,
    ReaderSettings fallback = const ReaderSettings(),
  }) => ReaderSettings(
    fit: FitMode.values.asNameMap()[fit] ?? fallback.fit,
    layout: LayoutMode.values.asNameMap()[layout] ?? fallback.layout,
    coverAlone: coverAlone ?? fallback.coverAlone,
  );

  final FitMode fit;
  final LayoutMode layout;

  /// Show the first page on its own in two-page layouts.
  final bool coverAlone;

  /// Whether to pair pages on a viewport of this size.
  bool showsTwoPages(Size viewport) => switch (layout) {
    LayoutMode.single => false,
    LayoutMode.double => true,
    LayoutMode.auto => viewport.width > viewport.height,
  };

  ReaderSettings copyWith({
    FitMode? fit,
    LayoutMode? layout,
    bool? coverAlone,
  }) => ReaderSettings(
    fit: fit ?? this.fit,
    layout: layout ?? this.layout,
    coverAlone: coverAlone ?? this.coverAlone,
  );

  @override
  bool operator ==(Object other) =>
      other is ReaderSettings &&
      other.fit == fit &&
      other.layout == layout &&
      other.coverAlone == coverAlone;

  @override
  int get hashCode => Object.hash(fit, layout, coverAlone);
}

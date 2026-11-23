import 'package:material_ui/material_ui.dart';

import '../platform/window.dart';
import 'fit_mode.dart';
import 'reader_settings.dart';
import 'spreads.dart';

/// The reader overlay: title bar with display controls and a bottom
/// scrubber. Fades in and out; ignores input while hidden.
class ReaderChrome extends StatelessWidget {
  const ReaderChrome({
    super.key,
    required this.visible,
    required this.title,
    required this.pages,
    required this.pageCount,
    required this.unit,
    required this.unitCount,
    required this.settings,
    required this.onSeek,
    required this.onSettingsChanged,
    required this.onBack,
    this.onInfo,
  });

  final bool visible;
  final String title;

  /// Pages in the current unit.
  final List<int> pages;
  final int pageCount;
  final int unit;
  final int unitCount;
  final ReaderSettings settings;
  final ValueChanged<int> onSeek;
  final ValueChanged<ReaderSettings> onSettingsChanged;
  final VoidCallback onBack;
  final VoidCallback? onInfo;

  String get _pageLabel {
    final first = pages.first + 1;
    final range = pages.length == 1 ? '$first' : '$first–${pages.last + 1}';
    return '$range / $pageCount';
  }

  @override
  Widget build(BuildContext context) {
    final bar = Colors.black.withValues(alpha: 0.78);
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 150),
        child: Column(
          children: [
            Material(
              color: bar,
              child: SafeArea(
                bottom: false,
                child: SizedBox(
                  height: 56,
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Back (Esc)',
                        icon: const Icon(Icons.arrow_back),
                        onPressed: onBack,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      _LayoutMenu(
                        settings: settings,
                        onChanged: onSettingsChanged,
                      ),
                      PopupMenuButton<FitMode>(
                        tooltip: 'Fit (M)',
                        icon: Icon(settings.fit.icon),
                        initialValue: settings.fit,
                        onSelected: (f) =>
                            onSettingsChanged(settings.copyWith(fit: f)),
                        itemBuilder: (_) => [
                          for (final m in FitMode.values)
                            PopupMenuItem(
                              value: m,
                              child: ListTile(
                                leading: Icon(m.icon),
                                title: Text(m.label),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                        ],
                      ),
                      if (onInfo != null)
                        IconButton(
                          tooltip: 'Book info (I)',
                          icon: const Icon(Icons.info_outline),
                          onPressed: onInfo,
                        ),
                      if (isDesktop)
                        const IconButton(
                          tooltip: 'Fullscreen (F)',
                          icon: Icon(Icons.fullscreen),
                          onPressed: toggleFullScreen,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const Spacer(),
            Material(
              color: bar,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: unitCount > 1
                            ? Slider(
                                value: unit.toDouble(),
                                max: (unitCount - 1).toDouble(),
                                divisions: unitCount - 1,
                                onChanged: (v) => onSeek(v.round()),
                              )
                            : const SizedBox(height: 48),
                      ),
                      Text(_pageLabel),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Page layout choice plus the "cover on its own" toggle.
class _LayoutMenu extends StatelessWidget {
  const _LayoutMenu({required this.settings, required this.onChanged});

  final ReaderSettings settings;
  final ValueChanged<ReaderSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<Object>(
      tooltip: 'Page layout (D)',
      icon: Icon(settings.layout.icon),
      onSelected: (v) => onChanged(
        v is LayoutMode
            ? settings.copyWith(layout: v)
            : settings.copyWith(coverAlone: !settings.coverAlone),
      ),
      itemBuilder: (_) => [
        for (final m in LayoutMode.values)
          PopupMenuItem<Object>(
            value: m,
            child: ListTile(
              leading: Icon(m.icon),
              title: Text(m.label),
              trailing: m == settings.layout ? const Icon(Icons.check) : null,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        const PopupMenuDivider(),
        CheckedPopupMenuItem<Object>(
          value: #cover,
          checked: settings.coverAlone,
          child: const Text('Show cover on its own (O)'),
        ),
      ],
    );
  }
}

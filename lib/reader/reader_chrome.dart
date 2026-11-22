import 'package:material_ui/material_ui.dart';

import '../platform/window.dart';
import 'fit_mode.dart';

/// The reader overlay: title bar with fit-mode / fullscreen controls and a
/// bottom page scrubber. Fades in and out; ignores input while hidden.
class ReaderChrome extends StatelessWidget {
  const ReaderChrome({
    super.key,
    required this.visible,
    required this.title,
    required this.page,
    required this.pageCount,
    required this.fit,
    required this.onSeek,
    required this.onFitChanged,
    required this.onBack,
  });

  final bool visible;
  final String title;
  final int page;
  final int pageCount;
  final FitMode fit;
  final ValueChanged<int> onSeek;
  final ValueChanged<FitMode> onFitChanged;
  final VoidCallback onBack;

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
                      PopupMenuButton<FitMode>(
                        tooltip: 'Fit (M)',
                        icon: Icon(fit.icon),
                        initialValue: fit,
                        onSelected: onFitChanged,
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
                        child: pageCount > 1
                            ? Slider(
                                value: page.toDouble(),
                                max: (pageCount - 1).toDouble(),
                                divisions: pageCount - 1,
                                label: '${page + 1}',
                                onChanged: (v) => onSeek(v.round()),
                              )
                            : const SizedBox(height: 48),
                      ),
                      Text('${page + 1} / $pageCount'),
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

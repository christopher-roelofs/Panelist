import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../app/theme.dart';
import '../library/comic_info_editor.dart';
import '../library/convert_comics.dart';
import '../library/info_lookup.dart';
import '../library/library_providers.dart';
import '../library/library_settings_screen.dart';
import '../library/publisher_names_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(appThemeProvider);
    final notifier = ref.read(appThemeProvider.notifier);
    final roots = ref.watch(libraryRootsProvider).value ?? const [];
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    Widget heading(String label) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        label,
        style: text.titleSmall?.copyWith(color: scheme.primary),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          heading('Appearance'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<AppThemeMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: AppThemeMode.system,
                  label: Text('System'),
                ),
                ButtonSegment(value: AppThemeMode.light, label: Text('Light')),
                ButtonSegment(value: AppThemeMode.dark, label: Text('Dark')),
                ButtonSegment(value: AppThemeMode.black, label: Text('Black')),
              ],
              selected: {theme.mode},
              onSelectionChanged: (s) => notifier.setMode(s.single),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Accent colour', style: text.bodyMedium),
          ),
          const SizedBox(height: 12),
          DynamicColorBuilder(
            builder: (light, dark) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 4,
                runSpacing: 8,
                children: [
                  for (final a in AppAccent.values)
                    if (a != AppAccent.wallpaper || dark != null)
                      _Swatch(
                        accent: a,
                        color: a.seed ?? dark!.primary,
                        selected: theme.accent == a,
                        onTap: () => notifier.setAccent(a),
                      ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Text(
              'Comics are always shown on black.',
              style: text.bodySmall,
            ),
          ),
          if (canEditMetadata) ...[
            heading('Comic details'),
            const LookupSettings(),
            const ConvertedOriginalsTile(),
            ListTile(
              leading: const Icon(Icons.business_outlined),
              title: const Text('Publisher names'),
              subtitle: const Text(
                'Show one name for a publisher written several ways',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PublisherNamesScreen(),
                ),
              ),
            ),
          ],
          heading('Library'),
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: const Text('Library folder'),
            subtitle: Text(switch (roots.length) {
              0 => 'None yet',
              1 => roots.single.name,
              final n => '$n folders',
            }),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const LibrarySettingsScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.accent,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final AppAccent accent;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      label: accent.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 76,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    border: Border.all(
                      color: selected ? scheme.onSurface : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  child: selected
                      ? const Icon(Icons.check, color: Colors.white)
                      : accent == AppAccent.wallpaper
                      ? const Icon(Icons.wallpaper, color: Colors.white)
                      : null,
                ),
                const SizedBox(height: 6),
                Text(
                  accent.label,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

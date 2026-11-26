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
import '../share/remote_settings.dart';
import '../share/share_settings.dart';

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
                    if (a != AppAccent.system || dark != null)
                      _Swatch(
                        label: a.label,
                        color: a.seed ?? dark!.primary,
                        selected: theme.accent == a,
                        icon: a == AppAccent.system
                            ? Icons.palette_outlined
                            : null,
                        onTap: () => notifier.setAccent(a),
                      ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Background', style: text.bodyMedium),
          ),
          const SizedBox(height: 12),
          DynamicColorBuilder(
            builder: (light, dark) {
              final brightness = Theme.of(context).brightness;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 8,
                  children: [
                    for (final b in AppBackground.values)
                      _Swatch(
                        label: b.label,
                        // The background itself, as it would look now.
                        color: buildColorScheme(
                          theme.accent,
                          brightness,
                          background: b,
                          system: brightness == Brightness.dark ? dark : light,
                        ).surfaceContainerHigh,
                        selected: theme.background == b,
                        outlined: true,
                        onTap: () => notifier.setBackground(b),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Text(
              theme.mode == AppThemeMode.black
                  ? 'The Black theme keeps backgrounds black. Comics are '
                        'always shown on black.'
                  : 'Comics are always shown on black.',
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
            leading: const Icon(Icons.lan_outlined),
            title: const Text('Libraries on this network'),
            subtitle: const Text('Read from a computer sharing its library'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const RemoteLibrariesScreen(),
              ),
            ),
          ),
          if (canShareLibrary)
            ListTile(
              leading: const Icon(Icons.wifi_tethering),
              title: const Text('Share library'),
              subtitle: Text(
                ref.watch(librarySharingProvider).running
                    ? 'On · devices can read from this computer'
                    : 'Let devices on this network read from this computer',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ShareLibraryScreen(),
                ),
              ),
            ),
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
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
    this.icon,
    this.outlined = false,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  /// A thin ring when not selected, for colours close to the page's own.
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
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
                      color: selected
                          ? scheme.onSurface
                          : outlined
                          ? scheme.outlineVariant
                          : Colors.transparent,
                      width: selected || !outlined ? 3 : 1,
                    ),
                  ),
                  child: selected
                      ? Icon(
                          Icons.check,
                          color:
                              ThemeData.estimateBrightnessForColor(color) ==
                                  Brightness.dark
                              ? Colors.white
                              : Colors.black,
                        )
                      : icon != null
                      ? Icon(icon, color: Colors.white)
                      : null,
                ),
                const SizedBox(height: 6),
                Text(label, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

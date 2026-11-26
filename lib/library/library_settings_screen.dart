import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../app/providers.dart';
import '../data/database.dart';
import '../platform/android_documents.dart';
import 'comic_info_editor.dart';
import 'library_providers.dart';
import 'library_scanner.dart';
import 'rename_comics.dart';

/// Asks for a folder and makes it the library folder, then scans. When one
/// is set already, asks first.
Future<void> chooseLibraryFolder(BuildContext context, WidgetRef ref) async {
  final db = ref.read(databaseProvider);
  final current = await db.roots();
  if (current.isNotEmpty && context.mounted) {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change the library folder?'),
        content: Text(
          'Comics in ${current.map((r) => r.name).join(', ')} leave the '
          'library. Their files aren’t touched, and reading progress is kept '
          'for when they’re opened again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Choose folder'),
          ),
        ],
      ),
    );
    if (ok != true) return;
  }
  final String location;
  final String name;
  if (AndroidDocuments.isSupported) {
    final tree = await AndroidDocuments.pickTree();
    if (tree == null) return;
    (location, name) = (tree.uri, tree.name);
  } else {
    final dir = await getDirectoryPath(confirmButtonText: 'Use this folder');
    if (dir == null) return;
    location = p.absolute(dir);
    name = p.basename(location);
  }
  await db.setLibraryFolder(location, name);
  for (final r in current) {
    if (r.location != location) await AndroidDocuments.release(r.location);
  }
  unawaited(ref.read(libraryScanProvider.notifier).scan());
}

/// Whether Panelist may change files in the Android library folder
/// [location] (always true for desktop folders).
final canWriteFolderProvider = FutureProvider.family<bool, String>(
  (ref, location) => AndroidDocuments.isContentUri(location)
      ? AndroidDocuments.canWrite(location)
      : Future.value(true),
);

/// Asks Android again for [root] with write access (folders added before
/// editing came were read-only). Choosing it again keeps the library.
Future<void> allowEditing(
  BuildContext context,
  WidgetRef ref,
  LibraryRoot root,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final tree = await AndroidDocuments.pickTree();
  if (tree == null) return;
  ref.invalidate(canWriteFolderProvider(root.location));
  if (tree.uri != root.location) {
    // A different folder: its permission isn't needed.
    await AndroidDocuments.release(tree.uri);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'That’s a different folder. Choose ${root.name} to allow editing '
          'it, or use Change folder.',
        ),
      ),
    );
    return;
  }
  if (!await ref.read(canWriteFolderProvider(root.location).future)) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Android didn’t allow changes to that folder.'),
      ),
    );
  }
}

/// The library folder: which it is, change it, organise it.
class LibrarySettingsScreen extends ConsumerWidget {
  const LibrarySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roots = ref.watch(libraryRootsProvider).value ?? const [];
    final comics = ref.watch(libraryComicsProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Library folder')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Text(
              'Panelist looks for comics in this folder and its subfolders '
              'when it starts and when you tap rescan. Files that haven’t '
              'changed are not read again.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          if (roots.isEmpty)
            const ListTile(
              leading: Icon(Icons.folder_off_outlined),
              title: Text('No folder chosen yet'),
            ),
          for (final r in roots) ...[
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(r.name),
              subtitle: Text(
                '${AndroidDocuments.isContentUri(r.location) ? '' : '${r.location} · '}'
                '${comics.where((c) => c.entry.rootId == r.id).length} comics',
              ),
            ),
            if (canEditMetadata &&
                ref.watch(canWriteFolderProvider(r.location)).value == false)
              ListTile(
                leading: const Icon(Icons.edit_off_outlined),
                title: const Text('Panelist can only read this folder'),
                subtitle: const Text(
                  'To save comic details, allow editing: choose the same '
                  'folder again in the next screen.',
                ),
                trailing: FilledButton.tonal(
                  onPressed: () => allowEditing(context, ref, r),
                  child: const Text('Allow editing'),
                ),
              ),
          ],
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: () => chooseLibraryFolder(context, ref),
                  icon: const Icon(Icons.folder_open_outlined),
                  label: Text(
                    roots.isEmpty ? 'Choose folder' : 'Change folder',
                  ),
                ),
                if (canEditMetadata && roots.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => organizeLibrary(context, ref),
                    icon: const Icon(Icons.account_tree_outlined),
                    label: const Text('Organize library…'),
                  ),
              ],
            ),
          ),
          if (canEditMetadata) const KeepOrganizedTile(),
        ],
      ),
    );
  }
}

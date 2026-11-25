import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../app/providers.dart';
import '../platform/android_documents.dart';
import 'library_providers.dart';
import 'library_scanner.dart';

/// Asks for a folder and adds it to the library, then scans.
Future<void> addLibraryFolder(WidgetRef ref) async {
  final String location;
  final String name;
  if (AndroidDocuments.isSupported) {
    final tree = await AndroidDocuments.pickTree();
    if (tree == null) return;
    (location, name) = (tree.uri, tree.name);
  } else {
    final dir = await getDirectoryPath(confirmButtonText: 'Add');
    if (dir == null) return;
    location = p.absolute(dir);
    name = p.basename(location);
  }
  await ref.read(databaseProvider).addRoot(location, name);
  unawaited(ref.read(libraryScanProvider.notifier).scan());
}

/// The library folders, with add and remove.
class LibrarySettingsScreen extends ConsumerWidget {
  const LibrarySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roots = ref.watch(libraryRootsProvider).value ?? const [];
    final comics = ref.watch(libraryComicsProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Library folders')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Text(
              'Panelist looks for comics in these folders and their '
              'subfolders when it starts and when you tap rescan. Files that '
              'haven’t changed are not read again.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          for (final r in roots)
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(r.name),
              subtitle: Text(
                '${AndroidDocuments.isContentUri(r.location) ? '' : '${r.location} · '}'
                '${comics.where((c) => c.entry.rootId == r.id).length} comics',
              ),
              trailing: IconButton(
                tooltip: 'Remove',
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () async {
                  await ref.read(databaseProvider).removeRoot(r.id);
                  await AndroidDocuments.release(r.location);
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: () => addLibraryFolder(ref),
                icon: const Icon(Icons.create_new_folder_outlined),
                label: const Text('Add folder'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

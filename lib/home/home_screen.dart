import 'package:file_selector/file_selector.dart';
import 'package:material_ui/material_ui.dart';

import '../core/sources/open_source.dart';
import '../reader/reader_screen.dart';

/// Opens [path] in the reader, showing an error message on failure.
Future<void> openInReader(BuildContext context, String path) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final navigator = Navigator.of(context);
  try {
    final source = await openSource(path);
    await navigator.push(
      MaterialPageRoute<void>(builder: (_) => ReaderScreen(source: source)),
    );
  } on Exception catch (e) {
    messenger?.showSnackBar(SnackBar(content: Text('$e')));
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _pickFolder(BuildContext context) async {
    final dir = await getDirectoryPath(confirmButtonText: 'Open');
    if (dir == null || !context.mounted) return;
    await openInReader(context, dir);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_stories,
              size: 72,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text('Panelist', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => _pickFolder(context),
              icon: const Icon(Icons.folder_open),
              label: const Text('Open folder'),
            ),
          ],
        ),
      ),
    );
  }
}

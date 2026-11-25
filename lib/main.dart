import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app/providers.dart';
import 'core/sources/archive_page_source.dart';
import 'data/database.dart';
import 'home/home_screen.dart';
import 'library/library_providers.dart';
import 'library/library_scanner.dart';
import 'platform/android_documents.dart';

/// `panelist [path]` opens [path] directly in the reader.
Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  ArchivePageSource.cacheRoot = Directory(
    p.join((await getApplicationCacheDirectory()).path, 'extracted'),
  );
  unawaited(ArchivePageSource.cleanStaleCache());
  final db = AppDatabase();
  final defaults = await ReaderDefaultsNotifier.load(db);
  final libraryPrefs = await LibraryPrefsNotifier.load(db);
  final covers = Directory(
    p.join((await getApplicationSupportDirectory()).path, 'covers'),
  );

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        readerDefaultsProvider.overrideWith(
          () => ReaderDefaultsNotifier(defaults),
        ),
        libraryPrefsProvider.overrideWith(
          () => LibraryPrefsNotifier(libraryPrefs),
        ),
        coversDirProvider.overrideWithValue(covers),
      ],
      child: PanelistApp(initialPath: args.isEmpty ? null : args.first),
    ),
  );
}

class PanelistApp extends StatelessWidget {
  const PanelistApp({super.key, this.initialPath});

  final String? initialPath;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Panelist',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepOrange,
          brightness: Brightness.dark,
        ),
      ),
      home: _Launcher(initialPath: initialPath),
    );
  }
}

/// Shows the home screen and, if a path was passed on the command line,
/// immediately opens it in the reader on top.
class _Launcher extends ConsumerStatefulWidget {
  const _Launcher({this.initialPath});

  final String? initialPath;

  @override
  ConsumerState<_Launcher> createState() => _LauncherState();
}

class _LauncherState extends ConsumerState<_Launcher> {
  @override
  void initState() {
    super.initState();
    // Android "Open with": the launch intent, then any later ones.
    AndroidDocuments.listen(_open);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final path =
          widget.initialPath ?? await AndroidDocuments.takeInitialUri();
      if (path != null) _open(path);
    });
  }

  void _open(String path) {
    if (!mounted) return;
    // A new book replaces whatever is being read.
    Navigator.of(context).popUntil((route) => route.isFirst);
    unawaited(openInReader(context, ref, path));
  }

  @override
  Widget build(BuildContext context) => const HomeScreen();
}

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app/providers.dart';
import 'app/theme.dart';
import 'core/sources/archive_page_source.dart';
import 'data/database.dart';
import 'home/home_screen.dart';
import 'library/library_providers.dart';
import 'library/library_scanner.dart';
import 'platform/android_documents.dart';
import 'reader/open_book.dart';

/// `panelist [path]` opens [path] directly in the reader.
Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  _sizeImageCache();

  ArchivePageSource.cacheRoot = Directory(
    p.join((await getApplicationCacheDirectory()).path, 'extracted'),
  );
  unawaited(ArchivePageSource.cleanStaleCache());
  final db = AppDatabase();
  final defaults = await ReaderDefaultsNotifier.load(db);
  final libraryPrefs = await LibraryPrefsNotifier.load(db);
  final appTheme = await AppThemeNotifier.load(db);
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
        appThemeProvider.overrideWith(() => AppThemeNotifier(appTheme)),
      ],
      child: PanelistApp(initialPath: args.isEmpty ? null : args.first),
    ),
  );
}

/// On phones and tablets, keeps decoded images to about what the reader
/// needs (the visible page and the preloaded ones, at screen size) instead
/// of Flutter's flat 100 MB, which is a lot on a 3–4 GB device.
void _sizeImageCache() {
  if (!AndroidDocuments.isSupported) return;
  final views = WidgetsBinding.instance.platformDispatcher.views;
  if (views.isEmpty) return;
  final size = views.first.physicalSize;
  final pageBytes = (size.width * size.height * 4).round();
  final cache = PaintingBinding.instance.imageCache;
  cache.maximumSizeBytes = math.max(48 << 20, pageBytes * 6);
}

class PanelistApp extends ConsumerWidget {
  const PanelistApp({super.key, this.initialPath});

  final String? initialPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(appThemeProvider);
    return DynamicColorBuilder(
      builder: (systemLight, systemDark) => MaterialApp(
        title: 'Panelist',
        debugShowCheckedModeBanner: false,
        themeMode: themeModeOf(theme.mode),
        theme: buildTheme(
          buildColorScheme(theme.accent, Brightness.light, system: systemLight),
        ),
        darkTheme: buildTheme(
          buildColorScheme(
            theme.accent,
            Brightness.dark,
            black: theme.mode == AppThemeMode.black,
            system: systemDark,
          ),
        ),
        home: _Launcher(initialPath: initialPath),
      ),
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

import 'dart:async';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../app/providers.dart';
import '../core/imaging/thumbnail.dart';
import '../core/metadata/comic_info.dart';
import '../core/sources/open_source.dart';
import '../core/sources/page_source.dart';
import '../data/book_extensions.dart';
import '../data/database.dart';
import '../library/library_providers.dart';
import '../library/library_scanner.dart';
import '../library/library_settings_screen.dart';
import '../library/library_view.dart';
import '../platform/android_documents.dart';
import '../reader/reader_screen.dart';

/// Opens [path] in the reader at its saved page, recording it in recents.
Future<void> openInReader(
  BuildContext context,
  WidgetRef ref,
  String path,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final navigator = Navigator.of(context);
  final db = ref.read(databaseProvider);
  final PageSource source;
  try {
    source = await openSource(path);
  } on Exception catch (e) {
    messenger?.showSnackBar(SnackBar(content: Text('$e')));
    return;
  }
  var book = await db.recordOpened(
    id: source.id,
    path: AndroidDocuments.isContentUri(path) ? path : p.absolute(path),
    title: source.title,
    pageCount: source.pageCount,
  );
  // Refresh ComicInfo metadata on every open (it's small and may change).
  try {
    final xml = await source.readComicInfo();
    final info = xml == null ? null : ComicInfo.parse(xml);
    if (info != null) {
      await db.saveMetadata(source.id, metadataFrom(info));
      book = (await db.book(source.id))!;
    }
  } on Object {
    // Metadata is optional.
  }
  if (book.cover == null) unawaited(_saveCover(db, source));
  await navigator.push(
    MaterialPageRoute<void>(
      builder: (_) => ReaderScreen(
        source: source,
        book: book,
        initialPage: book.currentPage,
      ),
    ),
  );
}

Future<void> _saveCover(AppDatabase db, PageSource source) async {
  try {
    final png = await renderThumbnail(source);
    if (png != null) await db.saveCover(source.id, png);
  } on Object {
    // A missing cover is cosmetic; the reader reports real page errors.
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _dragging = false;

  /// Null when not searching.
  String? _query;

  Future<void> _pickFile() async {
    if (AndroidDocuments.isSupported) {
      final uri = await AndroidDocuments.pick();
      if (uri != null && mounted) await openInReader(context, ref, uri);
      return;
    }
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Comics', extensions: comicFileExtensions),
      ],
    );
    if (file != null && mounted) await openInReader(context, ref, file.path);
  }

  Future<void> _pickFolder() async {
    final dir = await getDirectoryPath(confirmButtonText: 'Open');
    if (dir != null && mounted) await openInReader(context, ref, dir);
  }

  Future<void> _openRecent(Book book) async {
    final exists = AndroidDocuments.isContentUri(book.path)
        ? await AndroidDocuments.exists(book.path)
        : await FileSystemEntity.type(book.path) !=
              FileSystemEntityType.notFound;
    if (!mounted) return;
    if (!exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${book.displayTitle}" was moved or deleted.'),
          action: SnackBarAction(
            label: 'Remove',
            onPressed: () => _forget(book),
          ),
        ),
      );
      return;
    }
    await openInReader(context, ref, book.path);
  }

  Future<void> _forget(Book book) async {
    await ref.read(databaseProvider).forget(book.id);
    await AndroidDocuments.release(book.path);
  }

  @override
  void initState() {
    super.initState();
    // Pick up comics added or changed since the last run.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(ref.read(libraryScanProvider.notifier).scan());
    });
  }

  @override
  Widget build(BuildContext context) {
    final recents = ref.watch(recentBooksProvider).value ?? const <Book>[];
    final unfinished = [
      for (final b in recents)
        if (b.currentPage < b.pageCount - 1) b,
    ];
    final hasLibrary =
        ref.watch(libraryRootsProvider).value?.isNotEmpty ?? false;
    final scan = ref.watch(libraryScanProvider);
    final scheme = Theme.of(context).colorScheme;

    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (details) {
        setState(() => _dragging = false);
        if (details.files.isNotEmpty) {
          unawaited(openInReader(context, ref, details.files.first.path));
        }
      },
      child: PopScope(
        canPop: _query == null,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) setState(() => _query = null);
        },
        child: Scaffold(
          appBar: AppBar(
            leading: _query == null
                ? null
                : IconButton(
                    tooltip: 'Close search',
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => setState(() => _query = null),
                  ),
            title: _query == null
                ? const Text('Panelist')
                : TextField(
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Search series, titles, publishers',
                      border: InputBorder.none,
                    ),
                    onChanged: (q) => setState(() => _query = q),
                  ),
            bottom: scan.running
                ? PreferredSize(
                    preferredSize: const Size.fromHeight(3),
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      value: scan.total == 0 ? null : scan.done / scan.total,
                    ),
                  )
                : null,
            actions: [
              if (hasLibrary && _query == null)
                IconButton(
                  tooltip: 'Search library',
                  icon: const Icon(Icons.search),
                  onPressed: () => setState(() => _query = ''),
                ),
              if (hasLibrary && _query == null)
                IconButton(
                  tooltip: scan.running
                      ? 'Scanning (${scan.done} of ${scan.total})'
                      : 'Rescan library',
                  icon: const Icon(Icons.refresh),
                  onPressed: () =>
                      ref.read(libraryScanProvider.notifier).scan(),
                ),
              IconButton(
                tooltip: 'Open file',
                icon: const Icon(Icons.file_open_outlined),
                onPressed: _pickFile,
              ),
              // Folders of images need SAF tree access on Android (later).
              if (!AndroidDocuments.isSupported)
                IconButton(
                  tooltip: 'Open folder of images',
                  icon: const Icon(Icons.folder_open_outlined),
                  onPressed: _pickFolder,
                ),
              IconButton(
                tooltip: 'Library folders',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const LibrarySettingsScreen(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              border: _dragging
                  ? Border.all(color: scheme.primary, width: 3)
                  : null,
            ),
            child: LibraryBrowser(
              onOpenFile: _pickFile,
              query: _query ?? '',
              leading: [
                if (unfinished.isNotEmpty && _query == null)
                  SliverToBoxAdapter(
                    child: _ContinueReading(
                      books: unfinished,
                      onOpen: _openRecent,
                      onRemove: _forget,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContinueReading extends StatelessWidget {
  const _ContinueReading({
    required this.books,
    required this.onOpen,
    required this.onRemove,
  });

  final List<Book> books;
  final ValueChanged<Book> onOpen;
  final ValueChanged<Book> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(
            'Continue reading',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        SizedBox(
          height: 250,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: books.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, i) => SizedBox(
              width: 124,
              child: _BookTile(
                book: books[i],
                onOpen: () => onOpen(books[i]),
                onRemove: () => onRemove(books[i]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BookTile extends StatelessWidget {
  const _BookTile({
    required this.book,
    required this.onOpen,
    required this.onRemove,
  });

  final Book book;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = book.pageCount <= 1
        ? 1.0
        : book.currentPage / (book.pageCount - 1);
    final cover = book.cover;
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: ColoredBox(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: cover == null
                        ? const Icon(Icons.menu_book, size: 40)
                        : Image.memory(
                            cover,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                          ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: PopupMenuButton<void>(
                    tooltip: 'More',
                    icon: const Icon(
                      Icons.more_vert,
                      color: Colors.white,
                      shadows: [Shadow(blurRadius: 4)],
                    ),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        onTap: onRemove,
                        child: const Text('Remove from recent'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(value: progress, minHeight: 3),
          const SizedBox(height: 6),
          Text(
            book.displayTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
          Text(
            'Page ${book.currentPage + 1} of ${book.pageCount}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

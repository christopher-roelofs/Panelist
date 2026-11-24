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
  Widget build(BuildContext context) {
    final recents = ref.watch(recentBooksProvider).value ?? const <Book>[];
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
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Panelist'),
          actions: [
            IconButton(
              tooltip: 'Open file',
              icon: const Icon(Icons.file_open_outlined),
              onPressed: _pickFile,
            ),
            // Folders of images need SAF tree access on Android (later).
            if (!AndroidDocuments.isSupported)
              IconButton(
                tooltip: 'Open folder',
                icon: const Icon(Icons.folder_open_outlined),
                onPressed: _pickFolder,
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
          child: recents.isEmpty
              ? _EmptyState(
                  onOpenFile: _pickFile,
                  onOpenFolder: AndroidDocuments.isSupported
                      ? null
                      : _pickFolder,
                )
              : _RecentGrid(
                  books: recents,
                  onOpen: _openRecent,
                  onRemove: _forget,
                ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onOpenFile, this.onOpenFolder});

  final VoidCallback onOpenFile;
  final VoidCallback? onOpenFolder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_stories, size: 72, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            'Open a comic to start reading',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            onOpenFolder == null
                ? 'CBZ, CBR, CB7, CBT or PDF.'
                : 'CBZ, CBR, CB7, CBT, PDF or a folder of images. '
                      'Or drop one here.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: onOpenFile,
                icon: const Icon(Icons.file_open),
                label: const Text('Open file'),
              ),
              if (onOpenFolder != null)
                OutlinedButton.icon(
                  onPressed: onOpenFolder,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Open folder'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentGrid extends StatelessWidget {
  const _RecentGrid({
    required this.books,
    required this.onOpen,
    required this.onRemove,
  });

  final List<Book> books;
  final ValueChanged<Book> onOpen;
  final ValueChanged<Book> onRemove;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Continue reading',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 170,
              childAspectRatio: 0.52,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: books.length,
            itemBuilder: (context, i) => _BookTile(
              book: books[i],
              onOpen: () => onOpen(books[i]),
              onRemove: () => onRemove(books[i]),
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

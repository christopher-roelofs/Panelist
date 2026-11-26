import 'dart:async';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../app/providers.dart';
import '../core/sources/open_source.dart';
import '../data/book_extensions.dart';
import '../data/database.dart';
import '../library/library_providers.dart';
import '../library/library_refresh.dart';
import '../library/library_scanner.dart';
import '../library/library_view.dart';
import '../platform/android_documents.dart';
import '../reader/open_book.dart';
import '../settings/settings_screen.dart';

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

  Future<void> _openRecent(Book book) async {
    // A shared library's comic opens over the network (or its download);
    // the reader says if that fails.
    final exists = isRemoteLocation(book.path)
        ? true
        : AndroidDocuments.isContentUri(book.path)
        ? await AndroidDocuments.exists(book.path)
        : await FileSystemEntity.type(book.path) !=
              FileSystemEntityType.notFound;
    if (!mounted) return;
    if (!exists) {
      // In a library folder that's gone as a whole (a network drive not
      // connected, a card not inserted): the comic is likely fine.
      final away = (await ref.read(databaseProvider).roots())
          .where(
            (r) =>
                !AndroidDocuments.isContentUri(r.location) &&
                p.isWithin(r.location, book.path) &&
                !Directory(r.location).existsSync(),
          )
          .firstOrNull;
      if (!mounted) return;
      if (away != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${away.location} can’t be reached right now. If it’s a '
              'network drive, check it’s connected.',
            ),
          ),
        );
        return;
      }
      final remove = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Comic not found'),
          content: Text(
            '"${book.displayTitle}" was moved or deleted. Remove it from '
            'Continue reading?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialog).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialog).pop(true),
              child: const Text('Remove from recent'),
            ),
          ],
        ),
      );
      if (remove ?? false) await _forget(book);
      return;
    }
    await openInReader(context, ref, book.path);
  }

  Future<void> _forget(Book book) async {
    await ref.read(databaseProvider).removeFromRecent(book.id);
    await AndroidDocuments.release(book.path);
  }

  @override
  void initState() {
    super.initState();
    // Pick up comics added or changed since the last run, then keep up
    // with changes (folder watching, and rescans on coming back).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(libraryScanProvider.notifier).scan());
      final refresh = ref.read(libraryRefreshProvider);
      _lifecycle = AppLifecycleListener(onResume: refresh.onResumed);
    });
  }

  AppLifecycleListener? _lifecycle;

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recents = ref.watch(recentBooksProvider).value ?? const <Book>[];
    final unfinished = [
      for (final b in recents)
        if (!b.finished) b,
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
              IconButton(
                tooltip: 'Settings',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsScreen(),
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
                      onMarkRead: (b) => unawaited(
                        ref.read(databaseProvider).markRead([
                          (
                            id: b.id,
                            path: b.path,
                            title: b.title,
                            pageCount: b.pageCount,
                          ),
                        ]),
                      ),
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
    required this.onMarkRead,
  });

  final List<Book> books;
  final ValueChanged<Book> onOpen;
  final ValueChanged<Book> onRemove;
  final ValueChanged<Book> onMarkRead;

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
                onMarkRead: () => onMarkRead(books[i]),
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
    required this.onMarkRead,
  });

  final Book book;
  final VoidCallback onOpen;
  final VoidCallback onRemove;
  final VoidCallback onMarkRead;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = book.pageCount <= 1
        ? 1.0
        : book.currentPage / (book.pageCount - 1);
    final cover = book.cover;
    return InkWell(
      onTap: onOpen,
      onLongPress: () => _showActions(context),
      onSecondaryTap: () => _showActions(context),
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
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

  /// Long-press (or right-click): what else to do with this book.
  void _showActions(BuildContext context) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (sheet) {
          final theme = Theme.of(sheet);
          void run(VoidCallback action) {
            Navigator.of(sheet).pop();
            action();
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(book.displayTitle, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    'Page ${book.currentPage + 1} of ${book.pageCount}',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: () => run(onMarkRead),
                        icon: const Icon(Icons.done_all),
                        label: const Text('Mark as read'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => run(onRemove),
                        icon: const Icon(Icons.history_toggle_off),
                        label: const Text('Remove from recent'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

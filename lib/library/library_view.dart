import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../app/providers.dart';
import '../core/sources/open_source.dart';
import '../data/database.dart';
import '../reader/open_book.dart';
import '../share/remote_library.dart';
import '../share/remote_widgets.dart';
import 'bulk_field_editor.dart';
import 'comic_info_editor.dart';
import 'convert_comics.dart';
import 'info_lookup.dart';
import 'library_model.dart';
import 'library_providers.dart';
import 'library_scanner.dart';
import 'library_settings_screen.dart';
import 'promo_cleanup.dart';
import 'rename_comics.dart';

/// The home screen's scrolling body: [leading] slivers (Continue reading),
/// then the library, browsable by folder, series or publisher. Back goes
/// up a level.
class LibraryBrowser extends ConsumerStatefulWidget {
  const LibraryBrowser({
    super.key,
    this.leading = const [],
    required this.onOpenFile,
    this.query = '',
  });

  /// When not empty, shows matching comics instead of browsing.
  final String query;

  final List<Widget> leading;

  /// Opens a single comic from outside the library.
  final VoidCallback onOpenFile;

  @override
  ConsumerState<LibraryBrowser> createState() => _LibraryBrowserState();
}

const _unknownPublisher = '\u0000unknown';

enum _Kind { folder, group, issue }

class _Item {
  _Item({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.comic,
    this.trailing,
    this.count,
    this.members = const [],
    this.field,
  });

  final _Kind kind;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// The comic shown (an issue) or whose cover represents a group.
  final LibraryComic? comic;
  final String? trailing;

  /// Comics inside a folder.
  final int? count;

  /// Every comic in a group or folder (for marking them all read).
  final List<LibraryComic> members;

  /// The ComicInfo field this group is named by, editable for all members
  /// at once: (element, label, current value or null if unknown).
  final (String, String, String?)? field;
}

class _LibraryBrowserState extends ConsumerState<LibraryBrowser> {
  /// Drill-down within the current view: folder names, or a publisher
  /// and/or series name.
  final _path = <String>[];

  void _push(String key) => setState(() => _path.add(key));

  void _goTo(int depth) => setState(() => _path.length = depth);

  /// Every comic at breadcrumb [depth] (a library folder or folder with all
  /// its subfolders, a publisher, a series, or the whole library).
  List<LibraryComic> _comicsAt(
    int depth,
    LibraryView view,
    List<LibraryRoot> roots,
    List<LibraryComic> comics,
  ) {
    final saved = [..._path];
    try {
      _path.length = depth;
      final (_, items) = _level(view, roots, comics);
      final seen = <String>{};
      return [
        for (final item in items)
          for (final c
              in item.kind == _Kind.issue ? [?item.comic] : item.members)
            if (seen.add(c.location)) c,
      ];
    } finally {
      _path
        ..clear()
        ..addAll(saved);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(libraryPrefsProvider);
    final roots = ref.watch(shownRootsProvider);
    final comics = ref.watch(shownComicsProvider);
    final remote = ref.watch(shownLibraryProvider) != null;
    final remoteState = remote
        ? ref.watch(remoteComicsProvider(ref.watch(shownLibraryProvider)!))
        : null;
    final scan = ref.watch(libraryScanProvider);

    final slivers = <Widget>[...widget.leading];
    if (roots == null) {
      // Still loading.
    } else if (roots.isEmpty) {
      slivers.add(
        SliverToBoxAdapter(child: _SetUpLibrary(onOpenFile: widget.onOpenFile)),
      );
    } else {
      final query = widget.query.trim();
      final (crumbs, items) = query.isEmpty
          ? _level(prefs.view, roots, comics)
          : (
              ['Results for “$query”'],
              [
                for (final c in searchComics(comics, query))
                  _issueItem(c, title: '${c.series} ${c.issueLabel}'),
              ],
            );
      slivers
        ..add(
          SliverToBoxAdapter(
            child: query.isEmpty
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Header(prefs: prefs, onView: _onView, remote: remote),
                      const RemoteStatusBar(),
                    ],
                  )
                : const SizedBox(height: 8),
          ),
        )
        ..add(
          SliverToBoxAdapter(
            child: _Breadcrumbs(
              crumbs: crumbs,
              onTap: _goTo,
              onMenu: query.isNotEmpty
                  ? null
                  : (depth) => _detailsFor(
                      _Item(
                        kind: _Kind.folder,
                        title: crumbs[depth],
                        subtitle: '',
                        onTap: () {},
                        members: _comicsAt(depth, prefs.view, roots, comics),
                      ),
                    ),
            ),
          ),
        );
      if (items.isEmpty) {
        slivers.add(
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  query.isNotEmpty
                      ? 'No comics match “$query”.'
                      : remoteState != null
                      ? (remoteState.loading
                            ? 'Connecting…'
                            : remoteState.error != null
                            ? 'Nothing here yet.'
                            : 'No comics in this library.')
                      : scan.running
                      ? 'Looking for comics…'
                      : comics.isEmpty
                      ? 'No comics found in your library folders.'
                      : 'Nothing here.',
                ),
              ),
            ),
          ),
        );
      } else if (prefs.layout == LibraryLayout.grid) {
        slivers.add(
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 160,
                childAspectRatio: 0.5,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: items.length,
              itemBuilder: (context, i) =>
                  _Tile(item: items[i], onLongPress: _detailsFor(items[i])),
            ),
          ),
        );
      } else {
        slivers.add(
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 24),
            sliver: SliverList.builder(
              itemCount: items.length,
              itemBuilder: (context, i) =>
                  _Row(item: items[i], onLongPress: _detailsFor(items[i])),
            ),
          ),
        );
      }
    }

    return PopScope(
      canPop: _path.isEmpty || widget.query.trim().isNotEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _path.isNotEmpty) _goTo(_path.length - 1);
      },
      child: CustomScrollView(slivers: slivers),
    );
  }

  void _onView(LibraryView view) {
    ref.read(libraryPrefsProvider.notifier).setView(view);
    setState(_path.clear);
  }

  VoidCallback? _detailsFor(_Item item) {
    final c = item.comic;
    if (item.kind == _Kind.issue && c != null) {
      return () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (sheet) => _DetailsSheet(
          comic: c,
          onMark: _mark,
          onEdit: isEditableComic(c.location)
              ? () {
                  Navigator.of(sheet).pop();
                  unawaited(editComicInfo(context, c));
                }
              : null,
          onConvert: isConvertibleComic(c)
              ? () {
                  Navigator.of(sheet).pop();
                  unawaited(convertWithProgress(context, ref, [c]));
                }
              : null,
          onLookUp: isEditableComic(c.location) || isConvertibleComic(c)
              ? () {
                  Navigator.of(sheet).pop();
                  unawaited(lookUpOne(context, ref, c));
                }
              : null,
          onClean: canCleanComic(c)
              ? () {
                  Navigator.of(sheet).pop();
                  unawaited(cleanPromosWithReview(context, ref, [c]));
                }
              : null,
          onRename: canRenameComic(c)
              ? () {
                  Navigator.of(sheet).pop();
                  unawaited(renameWithPreview(context, ref, [c]));
                }
              : null,
          download: isRemoteLocation(c.location)
              ? DownloadButton(comic: c)
              : null,
        ),
      );
    }
    if (item.members.isEmpty) return null;
    return () => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => _GroupSheet(
        item: item,
        onMark: _mark,
        download: item.members.any((c) => isRemoteLocation(c.location))
            ? DownloadAllButton(comics: item.members)
            : null,
        onConvert: (comics) {
          Navigator.of(sheet).pop();
          unawaited(convertWithProgress(context, ref, comics));
        },
        onLookUp: (comics) {
          Navigator.of(sheet).pop();
          unawaited(tagWithProgress(context, ref, comics));
        },
        onClean: (comics) {
          Navigator.of(sheet).pop();
          unawaited(cleanPromosWithReview(context, ref, comics));
        },
        onRename: (comics) {
          Navigator.of(sheet).pop();
          unawaited(renameWithPreview(context, ref, comics));
        },
        onEdit:
            canEditMetadata &&
                item.field != null &&
                !item.members.any((c) => isRemoteLocation(c.location))
            ? () {
                Navigator.of(sheet).pop();
                final (field, label, current) = item.field!;
                unawaited(
                  editFieldForAll(
                    context,
                    ref,
                    comics: item.members,
                    field: field,
                    label: label,
                    current: current,
                  ),
                );
              }
            : null,
      ),
    );
  }

  void _mark(List<LibraryComic> comics, {required bool read}) =>
      unawaited(markComics(ref.read(databaseProvider), comics, read: read));

  void _open(LibraryComic c) =>
      unawaited(openInReader(context, ref, c.location));

  /// The breadcrumb labels and items at the current [_path].
  (List<String>, List<_Item>) _level(
    LibraryView view,
    List<LibraryRoot> roots,
    List<LibraryComic> comics,
  ) {
    switch (view) {
      case LibraryView.series:
        if (_path.isEmpty) {
          return (
            ['All series'],
            groupBySeries(comics).map(_seriesItem).toList(),
          );
        }
        final issues = comics.where((c) => c.series == _path[0]).toList()
          ..sort(compareIssues);
        return (['All series', _path[0]], issues.map(_issueItem).toList());

      case LibraryView.publishers:
        final publishers = groupByPublisher(comics);
        String label(String key) =>
            key == _unknownPublisher ? 'Unknown publisher' : key;
        if (_path.isEmpty) {
          return (
            ['All publishers'],
            [
              for (final g in publishers)
                _Item(
                  kind: _Kind.group,
                  title: g.name ?? 'Unknown publisher',
                  subtitle:
                      '${_plural(g.series.length, 'series', 'series')} · '
                      '${_plural(g.issueCount, 'issue', 'issues')}',
                  trailing: _plural(g.series.length, 'series', 'series'),
                  comic: g.first,
                  members: [for (final s in g.series) ...s.comics],
                  field: ('Publisher', 'Publisher', g.name),
                  onTap: () => _push(g.name ?? _unknownPublisher),
                ),
            ],
          );
        }
        final g = publishers
            .where((g) => (g.name ?? _unknownPublisher) == _path[0])
            .firstOrNull;
        final series = g?.series ?? const <SeriesGroup>[];
        if (_path.length == 1) {
          return (
            ['All publishers', label(_path[0])],
            series.map(_seriesItem).toList(),
          );
        }
        final s = series.where((s) => s.name == _path[1]).firstOrNull;
        return (
          ['All publishers', label(_path[0]), _path[1]],
          (s?.comics ?? const []).map(_issueItem).toList(),
        );

      case LibraryView.folders:
        // With one library folder, start inside it.
        final single = roots.length == 1;
        if (!single && _path.isEmpty) {
          return (
            ['All folders'],
            [
              for (final r in roots)
                if (comics.where((c) => c.entry.rootId == r.id).toList()
                    case final inside)
                  _Item(
                    kind: _Kind.folder,
                    title: r.name,
                    subtitle: _plural(inside.length, 'comic', 'comics'),
                    trailing: '${inside.length}',
                    count: inside.length,
                    comic: inside.isEmpty
                        ? null
                        : FolderGroup('', inside).first,
                    members: inside,
                    onTap: () => _push('${r.id}'),
                  ),
            ],
          );
        }
        final root = single
            ? roots.single
            : roots.where((r) => '${r.id}' == _path[0]).firstOrNull;
        if (root == null) return (['All folders'], const []);
        final names = single ? _path : _path.sublist(1);
        final (folders, files) = folderContents(
          comics,
          root.id,
          names.join('/'),
        );
        return (
          [if (!single) 'All folders', root.name, ...names],
          [
            for (final f in folders)
              _Item(
                kind: _Kind.folder,
                title: f.name,
                subtitle: _plural(f.comics.length, 'comic', 'comics'),
                trailing: '${f.comics.length}',
                count: f.comics.length,
                comic: f.first,
                members: f.comics,
                onTap: () => _push(f.name),
              ),
            for (final c in files)
              _issueItem(
                c,
                title: p.basenameWithoutExtension(c.entry.fileName),
              ),
          ],
        );
    }
  }

  _Item _seriesItem(SeriesGroup s) => _Item(
    kind: _Kind.group,
    title: s.name,
    subtitle:
        '${_plural(s.comics.length, 'issue', 'issues')} · ${s.readCount} read',
    trailing: '${s.readCount}/${s.comics.length}',
    comic: s.first,
    members: s.comics,
    field: ('Series', 'Series', s.name),
    onTap: () => _push(s.name),
  );

  _Item _issueItem(LibraryComic c, {String? title}) {
    final pr = c.progress;
    final String subtitle;
    final String trailing;
    if (c.entry.error != null) {
      subtitle = trailing = 'Couldn’t be read';
    } else if (c.entry.bookId == null) {
      subtitle = trailing = 'Scanning…';
    } else {
      switch (c.readState) {
        case ReadState.read:
          subtitle = trailing = 'Read';
        case ReadState.reading:
          subtitle = 'Page ${pr!.currentPage + 1} of ${pr.pageCount}';
          trailing = '${(c.progressFraction * 100).round()}%';
        case ReadState.unread:
          final pages = c.entry.pageCount;
          subtitle = trailing = pages == null ? '' : '$pages pages';
      }
    }
    return _Item(
      kind: _Kind.issue,
      title: title ?? c.issueLabel,
      subtitle: subtitle,
      trailing: trailing,
      comic: c,
      onTap: () => _open(c),
    );
  }
}

String _plural(int n, String one, String many) => '$n ${n == 1 ? one : many}';

class _SetUpLibrary extends ConsumerWidget {
  const _SetUpLibrary({required this.onOpenFile});

  final VoidCallback onOpenFile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      child: Card.outlined(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Set up your library', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text(
                'Choose the folder where you keep your comics. Panelist '
                'finds every comic inside it, including subfolders, and '
                'sorts them by series and publisher.',
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: () => chooseLibraryFolder(context, ref),
                    icon: const Icon(Icons.create_new_folder_outlined),
                    label: const Text('Choose library folder'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onOpenFile,
                    icon: const Icon(Icons.file_open_outlined),
                    label: const Text('Open a single comic'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.prefs,
    required this.onView,
    this.remote = false,
  });

  /// Showing a computer's shared library (its comics are edited there).
  final bool remote;
  final LibraryPrefs prefs;
  final ValueChanged<LibraryView> onView;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 8,
          children: [
            const LibrarySourcePicker(),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<LibraryView>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                  segments: const [
                    ButtonSegment(
                      value: LibraryView.folders,
                      label: Text('Folders'),
                    ),
                    ButtonSegment(
                      value: LibraryView.series,
                      label: Text('Series'),
                    ),
                    ButtonSegment(
                      value: LibraryView.publishers,
                      label: Text('Publishers'),
                    ),
                  ],
                  selected: {prefs.view},
                  onSelectionChanged: (s) => onView(s.single),
                ),
                if (canEditMetadata && !remote)
                  IconButton(
                    tooltip: 'Look up info',
                    icon: const Icon(Icons.travel_explore),
                    onPressed: () => lookUpLibrary(context, ref),
                  ),
                if (canEditMetadata && !remote)
                  IconButton(
                    tooltip: 'Organize library',
                    icon: const Icon(Icons.account_tree_outlined),
                    onPressed: () => organizeLibrary(context, ref),
                  ),
                IconButton(
                  tooltip: prefs.layout == LibraryLayout.grid
                      ? 'Show as list'
                      : 'Show as grid',
                  icon: Icon(
                    prefs.layout == LibraryLayout.grid
                        ? Icons.view_list_outlined
                        : Icons.grid_view_outlined,
                  ),
                  onPressed: () => ref
                      .read(libraryPrefsProvider.notifier)
                      .setLayout(
                        prefs.layout == LibraryLayout.grid
                            ? LibraryLayout.list
                            : LibraryLayout.grid,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Breadcrumbs extends StatelessWidget {
  const _Breadcrumbs({required this.crumbs, required this.onTap, this.onMenu});

  final List<String> crumbs;

  /// Called with the depth to go back to.
  final ValueChanged<int> onTap;

  /// The long-press / right-click action for the crumb at a depth.
  final VoidCallback? Function(int depth)? onMenu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (crumbs.length > 1)
            IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back),
              onPressed: () => onTap(crumbs.length - 2),
            )
          else
            const SizedBox(width: 12),
          for (final (i, name) in crumbs.indexed)
            if (i == crumbs.length - 1)
              GestureDetector(
                onLongPress: () => onMenu?.call(i)?.call(),
                onSecondaryTap: () => onMenu?.call(i)?.call(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  child: Text(name, style: theme.textTheme.bodyLarge),
                ),
              )
            else ...[
              GestureDetector(
                onSecondaryTap: () => onMenu?.call(i)?.call(),
                child: TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  onPressed: () => onTap(i),
                  onLongPress: () => onMenu?.call(i)?.call(),
                  child: Text(name),
                ),
              ),
              Text('›', style: theme.textTheme.bodyLarge),
            ],
        ],
      ),
    );
  }
}

/// A comic's cover thumbnail, or a placeholder.
class LibraryCover extends ConsumerWidget {
  const LibraryCover({super.key, required this.comic});

  final LibraryComic? comic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final c = comic;
    Widget placeholder() => ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          c?.entry.error != null
              ? Icons.broken_image_outlined
              : Icons.menu_book,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
    final id = c?.entry.bookId;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: id == null
          ? placeholder()
          : Image.file(
              File(p.join(ref.watch(coversDirProvider).path, '$id.png')),
              fit: BoxFit.cover,
              cacheWidth: 320,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => placeholder(),
            ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.item, this.onLongPress});

  final _Item item;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final c = item.comic;
    Widget cover = LibraryCover(comic: c);
    if (item.kind == _Kind.group) {
      // Edges of the next covers, for a stack.
      Widget edge(double inset, Color color) => Positioned(
        left: inset * 2,
        right: 0,
        top: 0,
        bottom: inset * 2,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      );
      cover = Stack(
        fit: StackFit.expand,
        children: [
          edge(3, scheme.outlineVariant),
          Positioned.fill(
            right: 4,
            top: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          Positioned.fill(right: 8, top: 8, child: cover),
        ],
      );
    }
    final badge = switch ((item.kind, c?.readState)) {
      (_Kind.issue, ReadState.read) => '✓ Read',
      _ => null,
    };
    return InkWell(
      onTap: item.onTap,
      onLongPress: onLongPress,
      onSecondaryTap: onLongPress,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                cover,
                if (item.kind == _Kind.folder)
                  Positioned(
                    left: 6,
                    top: 6,
                    child: _Chip(
                      icon: Icons.folder,
                      label: '${item.count ?? ''}',
                    ),
                  ),
                if (badge != null)
                  Positioned(right: 6, top: 6, child: _Chip(label: badge)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          if (item.kind == _Kind.issue && c?.readState == ReadState.reading)
            LinearProgressIndicator(value: c!.progressFraction, minHeight: 3)
          else
            const SizedBox(height: 3),
          const SizedBox(height: 6),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
          Text(
            item.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: Colors.white70),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item, this.onLongPress});

  final _Item item;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    // Right-click does what long-press does (ListTile has no hook for it).
    return GestureDetector(
      onSecondaryTap: onLongPress,
      child: ListTile(
        onTap: item.onTap,
        onLongPress: onLongPress,
        leading: SizedBox(
          width: 40,
          height: 60,
          child: item.kind == _Kind.folder
              ? const Icon(Icons.folder_outlined, size: 32)
              : LibraryCover(comic: item.comic),
        ),
        title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          item.subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: item.trailing == null ? null : Text(item.trailing!),
      ),
    );
  }
}

/// Where each of an issue's details came from.
class _DetailsSheet extends StatelessWidget {
  const _DetailsSheet({
    required this.comic,
    required this.onMark,
    required this.onEdit,
    required this.onConvert,
    required this.onLookUp,
    required this.onClean,
    required this.onRename,
    this.download,
  });

  final LibraryComic comic;

  /// For a comic in a computer's shared library: download it.
  final Widget? download;

  /// Renames the file by the name template; null where it can't be.
  final VoidCallback? onRename;

  /// Looks for promo pages to remove; null where it can't.
  final VoidCallback? onClean;

  /// Looks the comic's details up; null where it can't be.
  final VoidCallback? onLookUp;
  final _OnMark onMark;

  /// Converts the comic to CBZ; null where it can't be.
  final VoidCallback? onConvert;

  /// Opens the metadata editor; null where the comic can't be edited.
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = comic.entry;
    final (series, seriesSrc) = comic.seriesWithSource;
    final number = comic.numberWithSource;
    final year = comic.yearWithSource;
    final rows = <(String, String, FieldSource?)>[
      ('Series', series, seriesSrc),
      ('Number', number?.$1 ?? 'None', number?.$2),
      ('Year', year == null ? 'Unknown' : '${year.$1}', year?.$2),
      (
        'Publisher',
        comic.publisher ?? 'Unknown',
        comic.publisher == null ? null : FieldSource.comicInfo,
      ),
      if (e.title != null) ('Title', e.title!, FieldSource.comicInfo),
      if (e.pageCount != null) ('Pages', '${e.pageCount}', null),
      ('File', [if (e.folder.isNotEmpty) e.folder, e.fileName].join('/'), null),
      if (e.error != null) ('Problem', e.error!, null),
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$series ${comic.issueLabel}',
              style: theme.textTheme.titleLarge,
            ),
            if (e.bookId != null && e.pageCount != null) ...[
              const SizedBox(height: 12),
              _MarkButtons(
                comics: [comic],
                showRead: comic.readState != ReadState.read,
                showUnread: comic.readState != ReadState.unread,
                onMark: onMark,
                extra: [
                  ?download,
                  if (onEdit != null)
                    OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit details'),
                    ),
                  if (onLookUp != null)
                    OutlinedButton.icon(
                      onPressed: onLookUp,
                      icon: const Icon(Icons.travel_explore),
                      label: const Text('Look up info'),
                    ),
                  if (onClean != null)
                    OutlinedButton.icon(
                      onPressed: onClean,
                      icon: const Icon(Icons.cleaning_services_outlined),
                      label: const Text('Remove promo pages'),
                    ),
                  if (onRename != null)
                    OutlinedButton.icon(
                      onPressed: onRename,
                      icon: const Icon(Icons.drive_file_rename_outline),
                      label: const Text('Rename…'),
                    ),
                ],
              ),
            ],
            if (onEdit == null && onConvert != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: onConvert,
                    icon: const Icon(Icons.transform),
                    label: const Text('Convert to CBZ'),
                  ),
                  Text('to edit its details', style: theme.textTheme.bodySmall),
                ],
              ),
            ] else if (onEdit == null &&
                canEditMetadata &&
                download == null) ...[
              const SizedBox(height: 8),
              Text(
                'PDF details can’t be edited.',
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'ComicInfo is used first, then the folder or file name.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            for (final (label, value, source) in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 96,
                      child: Text(label, style: theme.textTheme.bodySmall),
                    ),
                    Expanded(child: SelectableText(value)),
                    if (source != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          switch (source) {
                            FieldSource.comicInfo => 'ComicInfo',
                            FieldSource.fileName => 'File name',
                            FieldSource.folder => 'Folder',
                          },
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

typedef _OnMark = void Function(List<LibraryComic>, {required bool read});

/// "Mark as read" / "Mark as unread"; closes the sheet it's in.
class _MarkButtons extends StatelessWidget {
  const _MarkButtons({
    required this.comics,
    required this.onMark,
    this.showRead = true,
    this.showUnread = true,
    this.all = false,
    this.extra = const [],
  });

  final List<LibraryComic> comics;
  final _OnMark onMark;
  final bool showRead;
  final bool showUnread;

  /// Says "all" (for a group).
  final bool all;

  /// More buttons in the same row.
  final List<Widget> extra;

  @override
  Widget build(BuildContext context) {
    void mark({required bool read}) {
      onMark(comics, read: read);
      Navigator.of(context).pop();
    }

    final which = all ? 'all ' : '';
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (showRead)
          FilledButton.tonalIcon(
            onPressed: () => mark(read: true),
            icon: const Icon(Icons.done_all),
            label: Text('Mark ${which}as read'),
          ),
        if (showUnread)
          OutlinedButton.icon(
            onPressed: () => mark(read: false),
            icon: const Icon(Icons.remove_done),
            label: Text('Mark ${which}as unread'),
          ),
        ...extra,
      ],
    );
  }
}

/// Long-press on a series, publisher or folder.
class _GroupSheet extends StatelessWidget {
  const _GroupSheet({
    required this.item,
    required this.onMark,
    this.download,
    required this.onEdit,
    required this.onConvert,
    required this.onLookUp,
    required this.onClean,
    required this.onRename,
  });

  final _Item item;

  /// For comics in a computer's shared library: download them all.
  final Widget? download;

  /// Renames the given members' files by the name template.
  final void Function(List<LibraryComic> comics) onRename;

  /// Looks the given members over for promo pages.
  final void Function(List<LibraryComic> comics) onClean;

  /// Looks the given members' details up.
  final void Function(List<LibraryComic> comics) onLookUp;
  final _OnMark onMark;

  /// Converts the given members to CBZ.
  final void Function(List<LibraryComic> comics) onConvert;

  /// Edits the field the group is named by, for all its comics.
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final read = item.members
        .where((c) => c.readState == ReadState.read)
        .length;
    final unread = item.members
        .where((c) => c.readState == ReadState.unread)
        .length;
    final n = item.members.length;
    final convertible = item.members.where(isConvertibleComic).toList();
    final renamable = item.members.where(canRenameComic).toList();
    // CBZ (by name, to stay cheap) and anything convertible to it.
    final taggable = item.members.where(canLookUpComic).toList();
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              '${_plural(n, 'comic', 'comics')} · $read read',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            _MarkButtons(
              comics: item.members,
              showRead: read < n,
              showUnread: unread < n,
              all: true,
              onMark: onMark,
              extra: [
                ?download,
                if (onEdit != null)
                  OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    label: Text('Edit ${item.field!.$2.toLowerCase()}'),
                  ),
                if (taggable.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => onLookUp(taggable),
                    icon: const Icon(Icons.travel_explore),
                    label: Text(
                      taggable.length == 1
                          ? 'Look up info for 1'
                          : 'Look up info for ${taggable.length}',
                    ),
                  ),
                if (taggable.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => onClean(taggable),
                    icon: const Icon(Icons.cleaning_services_outlined),
                    label: const Text('Remove promo pages'),
                  ),
                if (renamable.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => onRename(renamable),
                    icon: const Icon(Icons.drive_file_rename_outline),
                    label: Text(
                      renamable.length == 1
                          ? 'Rename 1…'
                          : 'Rename ${renamable.length}…',
                    ),
                  ),
                if (convertible.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => onConvert(convertible),
                    icon: const Icon(Icons.transform),
                    label: Text(
                      convertible.length == 1
                          ? 'Convert 1 to CBZ'
                          : 'Convert ${convertible.length} to CBZ',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

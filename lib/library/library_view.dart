import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../data/database.dart';
import '../home/home_screen.dart' show openInReader;
import 'library_model.dart';
import 'library_providers.dart';
import 'library_scanner.dart';
import 'library_settings_screen.dart';

/// The home screen's scrolling body: [leading] slivers (Continue reading),
/// then the library, browsable by folder, series or publisher. Back goes
/// up a level.
class LibraryBrowser extends ConsumerStatefulWidget {
  const LibraryBrowser({
    super.key,
    this.leading = const [],
    required this.onOpenFile,
  });

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
}

class _LibraryBrowserState extends ConsumerState<LibraryBrowser> {
  /// Drill-down within the current view: folder names, or a publisher
  /// and/or series name.
  final _path = <String>[];

  void _push(String key) => setState(() => _path.add(key));

  void _goTo(int depth) => setState(() => _path.length = depth);

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(libraryPrefsProvider);
    final roots = ref.watch(libraryRootsProvider).value;
    final comics = ref.watch(libraryComicsProvider);
    final scan = ref.watch(libraryScanProvider);

    final slivers = <Widget>[...widget.leading];
    if (roots == null) {
      // Still loading.
    } else if (roots.isEmpty) {
      slivers.add(
        SliverToBoxAdapter(child: _SetUpLibrary(onOpenFile: widget.onOpenFile)),
      );
    } else {
      final (crumbs, items) = _level(prefs.view, roots, comics);
      slivers
        ..add(
          SliverToBoxAdapter(
            child: _Header(prefs: prefs, onView: _onView),
          ),
        )
        ..add(
          SliverToBoxAdapter(
            child: _Breadcrumbs(crumbs: crumbs, onTap: _goTo),
          ),
        );
      if (items.isEmpty) {
        slivers.add(
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  scan.running
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
      canPop: _path.isEmpty,
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
    if (item.kind != _Kind.issue || c == null) return null;
    return () => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _DetailsSheet(comic: c),
    );
  }

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
                    onPressed: () => addLibraryFolder(ref),
                    icon: const Icon(Icons.create_new_folder_outlined),
                    label: const Text('Add library folder'),
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
  const _Header({required this.prefs, required this.onView});

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
            Text('Library', style: Theme.of(context).textTheme.titleMedium),
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
  const _Breadcrumbs({required this.crumbs, required this.onTap});

  final List<String> crumbs;

  /// Called with the depth to go back to.
  final ValueChanged<int> onTap;

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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Text(name, style: theme.textTheme.bodyLarge),
              )
            else ...[
              TextButton(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                ),
                onPressed: () => onTap(i),
                child: Text(name),
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
    return ListTile(
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
    );
  }
}

/// Where each of an issue's details came from.
class _DetailsSheet extends StatelessWidget {
  const _DetailsSheet({required this.comic});

  final LibraryComic comic;

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
        e.publisher ?? 'Unknown',
        e.publisher == null ? null : FieldSource.comicInfo,
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
            const SizedBox(height: 4),
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

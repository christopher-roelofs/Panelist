import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../app/providers.dart';
import '../core/metadata/promo_pages.dart';
import '../core/sources/archive_page_source.dart';
import '../core/sources/cbz_page_source.dart';
import '../core/sources/open_source.dart';
import '../core/sources/page_source.dart';
import '../data/database.dart';
import 'comic_info_editor.dart';
import 'convert_comics.dart';
import 'library_model.dart';
import 'library_scanner.dart';

/// Whether [comic] can have pages removed here (CBZ, or convertible to it;
/// by name, so it's cheap for a whole publisher).
bool canCleanComic(LibraryComic comic) =>
    canEditMetadata &&
    (isConvertibleComic(comic) ||
        p.extension(comic.entry.fileName).toLowerCase() == '.cbz');

/// Pages [promoPages] picked in one comic, with their images to show.
typedef PromoFind = ({
  LibraryComic comic,
  List<String> pages,
  List<Uint8List?> images,
});

/// Looks through [comics] for promo pages (no changes made).
Future<List<PromoFind>> findPromos(
  List<LibraryComic> comics, {
  void Function(int done)? onProgress,
  bool Function()? shouldStop,
}) async {
  final out = <PromoFind>[];
  for (final (i, comic) in comics.indexed) {
    if (shouldStop?.call() ?? false) break;
    PageSource? source;
    try {
      source = await openSource(comic.location);
      final names = switch (source) {
        CbzPageSource s => s.pageNames,
        ArchivePageSource s => s.pageNames,
        _ => const <String>[],
      };
      final promos = promoPages(names);
      if (promos.isNotEmpty) {
        final images = <Uint8List?>[];
        for (final name in promos) {
          try {
            images.add(
              await (source as EncodedPageSource).page(names.indexOf(name)),
            );
          } on Object {
            images.add(null);
          }
        }
        out.add((comic: comic, pages: promos, images: images));
      }
    } on Object {
      // Unreadable: nothing to offer.
    } finally {
      await source?.close();
      onProgress?.call(i + 1);
    }
  }
  return out;
}

typedef CleanResult = ({
  int cleaned,
  int pages,
  int failed,
  List<String> errors,
});

/// Removes the found pages, converting CBR/CB7/CBT to CBZ first, and moves
/// reading progress to each comic's new book ID.
Future<CleanResult> removePromos(
  AppDatabase db,
  List<PromoFind> finds, {
  void Function(int done)? onProgress,
  Future<bool> Function(String path) trash = moveToTrash,
}) async {
  var cleaned = 0, pages = 0, failed = 0;
  final errors = <String>[];
  for (final (i, f) in finds.indexed) {
    try {
      var path = f.comic.location;
      if (isConvertibleComic(f.comic)) {
        final c = await convertComics(db, [f.comic], trash: trash);
        if (c.failed > 0) throw Exception(c.errors.first);
        path = p.setExtension(path, '.cbz');
      }
      final ids = await removePagesFromCbz(path, f.pages.toSet());
      await db.moveBook(ids.oldId, ids.newId, path);
      cleaned++;
      pages += f.pages.length;
    } on Object catch (e) {
      failed++;
      errors.add('${f.comic.entry.fileName}: $e');
    } finally {
      onProgress?.call(i + 1);
    }
  }
  return (cleaned: cleaned, pages: pages, failed: failed, errors: errors);
}

String describeCleanResult(CleanResult r) => [
  'Removed ${r.pages == 1 ? '1 page' : '${r.pages} pages'} from '
      '${r.cleaned == 1 ? '1 comic' : '${r.cleaned} comics'}',
  if (r.failed > 0) '${r.failed} failed: ${r.errors.first}',
].join(' · ');

/// Looks through [comics], shows what it found, and removes what the user
/// keeps ticked.
Future<void> cleanPromosWithReview(
  BuildContext context,
  WidgetRef ref,
  List<LibraryComic> comics,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final result = await showDialog<CleanResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PromoDialog(comics: comics),
  );
  if (result == null) return;
  unawaited(ref.read(libraryScanProvider.notifier).scan());
  messenger.showSnackBar(
    SnackBar(
      content: Text(describeCleanResult(result)),
      duration: Duration(seconds: result.failed > 0 ? 10 : 4),
    ),
  );
}

class _PromoDialog extends ConsumerStatefulWidget {
  const _PromoDialog({required this.comics});
  final List<LibraryComic> comics;

  @override
  ConsumerState<_PromoDialog> createState() => _PromoDialogState();
}

class _PromoDialogState extends ConsumerState<_PromoDialog> {
  int _looked = 0;
  bool _stopping = false;
  List<PromoFind>? _finds;
  final _chosen = <int>{};
  int? _removed;

  @override
  void initState() {
    super.initState();
    unawaited(_find());
  }

  Future<void> _find() async {
    final finds = await findPromos(
      widget.comics,
      onProgress: (n) {
        if (mounted) setState(() => _looked = n);
      },
      shouldStop: () => _stopping || !mounted,
    );
    if (!mounted) return;
    setState(() {
      _finds = finds;
      _chosen.addAll(List.generate(finds.length, (i) => i));
    });
  }

  Future<void> _remove() async {
    final finds = _finds!;
    setState(() => _removed = 0);
    final result = await removePromos(
      ref.read(databaseProvider),
      [
        for (final (i, f) in finds.indexed)
          if (_chosen.contains(i)) f,
      ],
      onProgress: (n) {
        if (mounted) setState(() => _removed = n);
      },
    );
    if (mounted) Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final finds = _finds;
    final total = widget.comics.length;
    final removed = _removed;
    final convert = [
      for (final i in _chosen)
        if (finds != null && isConvertibleComic(finds[i].comic)) i,
    ].length;

    final Widget content;
    if (finds == null) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Looking for pages added at the end that don’t belong to the '
            'comic, such as a scan group’s promo image.',
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(value: total == 0 ? null : _looked / total),
          const SizedBox(height: 8),
          Text('$_looked of $total', style: theme.textTheme.bodySmall),
        ],
      );
    } else if (finds.isEmpty) {
      content = Text(
        total == 1
            ? 'No promo pages found.'
            : 'No promo pages found in $_looked comics.',
      );
    } else {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'These pages are named unlike the rest of their comic. Untick '
            'any that belong to it.'
            '${convert > 0 ? ' $convert CBR/CB7/CBT ${convert == 1 ? 'file is' : 'files are'} converted to CBZ first.' : ''}',
          ),
          const SizedBox(height: 12),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final (i, f) in finds.indexed)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _chosen.contains(i),
                    onChanged: removed != null
                        ? null
                        : (v) => setState(
                            () => v! ? _chosen.add(i) : _chosen.remove(i),
                          ),
                    title: Text(f.comic.entry.fileName),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final (j, name) in f.pages.indexed)
                            Column(
                              children: [
                                SizedBox(
                                  height: 120,
                                  child: f.images[j] == null
                                      ? const Icon(Icons.broken_image_outlined)
                                      : Image.memory(
                                          f.images[j]!,
                                          fit: BoxFit.contain,
                                          cacheHeight: 240,
                                          errorBuilder: (_, _, _) => const Icon(
                                            Icons.broken_image_outlined,
                                          ),
                                        ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  p.basename(name),
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (removed != null) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(value: removed / _chosen.length),
          ],
        ],
      );
    }

    return AlertDialog(
      title: const Text('Remove promo pages'),
      content: SizedBox(width: 560, child: content),
      actions: [
        if (finds == null)
          TextButton(
            onPressed: _stopping
                ? null
                : () => setState(() => _stopping = true),
            child: const Text('Stop'),
          )
        else
          TextButton(
            onPressed: removed != null
                ? null
                : () => Navigator.of(context).pop(),
            child: Text(finds.isEmpty ? 'Close' : 'Cancel'),
          ),
        if (finds != null && finds.isNotEmpty)
          FilledButton(
            onPressed: removed != null || _chosen.isEmpty ? null : _remove,
            child: Text(
              _chosen.length == 1
                  ? 'Remove from 1 comic'
                  : 'Remove from ${_chosen.length} comics',
            ),
          ),
      ],
    );
  }
}

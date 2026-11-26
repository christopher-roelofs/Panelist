import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../library/library_model.dart';
import 'remote_library.dart';
import 'remote_settings.dart';
import 'share_client.dart';

/// The library header's title: just "Library", or, with paired libraries, a
/// menu to switch between this device's and theirs.
class LibrarySourcePicker extends ConsumerWidget {
  const LibrarySourcePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final paired = ref.watch(remoteLibrariesProvider).value ?? const [];
    final shown = ref.watch(shownLibraryProvider);
    final current = paired.where((l) => l.id == shown).firstOrNull;
    if (paired.isEmpty) {
      return Text('Library', style: theme.textTheme.titleMedium);
    }
    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Icons.folder_outlined),
          trailingIcon: current == null ? const Icon(Icons.check) : null,
          onPressed: () => ref.read(shownLibraryProvider.notifier).show(null),
          child: const Text('This device'),
        ),
        for (final l in paired)
          MenuItemButton(
            leadingIcon: const Icon(Icons.computer_outlined),
            trailingIcon: current?.id == l.id ? const Icon(Icons.check) : null,
            onPressed: () => ref.read(shownLibraryProvider.notifier).show(l.id),
            child: Text(l.name),
          ),
      ],
      builder: (context, menu, _) => TextButton.icon(
        onPressed: () => menu.isOpen ? menu.close() : menu.open(),
        icon: Icon(
          current == null ? Icons.folder_outlined : Icons.computer_outlined,
          size: 20,
        ),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(
                current?.name ?? 'This device',
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
}

/// Under the header when a paired library is shown: connecting, or why it
/// can't be reached (the last list still shows).
class RemoteStatusBar extends ConsumerWidget {
  const RemoteStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shown = ref.watch(shownLibraryProvider);
    if (shown == null) return const SizedBox.shrink();
    final lib = (ref.watch(remoteLibrariesProvider).value ?? const [])
        .where((l) => l.id == shown)
        .firstOrNull;
    if (lib == null) return const SizedBox.shrink();
    final state = ref.watch(remoteComicsProvider(shown));
    final theme = Theme.of(context);
    final Widget body;
    if (state.error case final error?) {
      body = Row(
        children: [
          Icon(Icons.cloud_off_outlined, color: theme.colorScheme.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              state.comics.isEmpty
                  ? error
                  : '$error. Showing the last list; downloaded comics open '
                        'without it.',
              style: theme.textTheme.bodySmall,
            ),
          ),
          if (state.unpaired)
            TextButton(
              onPressed: () => pairWithLibrary(context, ref, lib.address),
              child: const Text('Add again'),
            )
          else
            TextButton(
              onPressed: () async {
                await ref.read(remoteAccessProvider).findMovedLibraries();
                await ref.read(remoteComicsProvider(shown).notifier).refresh();
              },
              child: const Text('Try again'),
            ),
        ],
      );
    } else if (state.loading) {
      body = Row(
        children: [
          const SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text('Connecting to ${lib.name}…', style: theme.textTheme.bodySmall),
        ],
      );
    } else {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: body,
    );
  }
}

/// In a paired library's comic details: download it to read without the
/// computer, or remove the download.
class DownloadButton extends ConsumerStatefulWidget {
  const DownloadButton({super.key, required this.comic});
  final LibraryComic comic;

  @override
  ConsumerState<DownloadButton> createState() => _DownloadButtonState();
}

class _DownloadButtonState extends ConsumerState<DownloadButton> {
  double? _progress;
  bool _cancel = false;

  ({int library, String bookId})? get _where =>
      parseRemoteLocation(widget.comic.location);

  Future<void> _download() async {
    final where = _where!;
    final comic = ref
        .read(remoteComicsProvider(where.library))
        .comics
        .where((c) => c.id == where.bookId)
        .firstOrNull;
    if (comic == null) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _progress = 0;
      _cancel = false;
    });
    try {
      await ref
          .read(downloadsProvider.notifier)
          .download(
            where.library,
            comic,
            onProgress: (done, total) {
              if (mounted && total > 0) {
                setState(() => _progress = done / total);
              }
            },
            cancelled: () => _cancel,
          );
    } on ShareException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _progress = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final where = _where;
    if (where == null) return const SizedBox.shrink();
    final downloaded = ref.watch(downloadsProvider).containsKey(where.bookId);
    if (_progress case final progress?) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 140, child: LinearProgressIndicator(value: progress)),
          const SizedBox(width: 8),
          Text('${(progress * 100).round()}%'),
          TextButton(
            onPressed: () => setState(() => _cancel = true),
            child: const Text('Stop'),
          ),
        ],
      );
    }
    if (downloaded) {
      return OutlinedButton.icon(
        onPressed: () => unawaited(
          ref.read(downloadsProvider.notifier).remove(where.bookId),
        ),
        icon: const Icon(Icons.download_done),
        label: const Text('Downloaded · Remove'),
      );
    }
    return OutlinedButton.icon(
      onPressed: _download,
      icon: const Icon(Icons.download_outlined),
      label: Text('Download (${_size(widget.comic.entry.size)})'),
    );
  }
}

String _size(int bytes) {
  if (bytes >= 1 << 30) return '${(bytes / (1 << 30)).toStringAsFixed(1)} GB';
  if (bytes >= 1 << 20) return '${(bytes / (1 << 20)).round()} MB';
  return '${(bytes / 1024).ceil()} KB';
}

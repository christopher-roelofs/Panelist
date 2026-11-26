import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../core/util/file_errors.dart';
import '../library/library_model.dart';
import 'remote_library.dart';
import 'remote_settings.dart';
import 'share_client.dart';
import 'share_protocol.dart';

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

  /// Why the last try failed, shown by the button (a snackbar can be hidden
  /// behind the details sheet).
  String? _error;

  ({int library, String bookId})? get _where =>
      parseRemoteLocation(widget.comic.location);

  Future<void> _download() async {
    final where = _where!;
    final comic = ref
        .read(remoteComicsProvider(where.library))
        .comics
        .where((c) => c.id == where.bookId)
        .firstOrNull;
    if (comic == null) {
      setState(() => _error = 'Not in the list from the computer; refresh it');
      return;
    }
    setState(() {
      _progress = 0;
      _cancel = false;
      _error = null;
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
      if (mounted && !_cancel) setState(() => _error = e.message);
    } on Object catch (e) {
      // A file this device couldn't write, for example.
      if (mounted) setState(() => _error = describeFileError(e));
    } finally {
      if (mounted) setState(() => _progress = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final where = _where;
    if (where == null) return const SizedBox.shrink();
    final downloaded = ref.watch(downloadsProvider).containsKey(where.bookId);
    final removable = ref
        .read(downloadsProvider.notifier)
        .removable(where.bookId);
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
    if (downloaded && !removable) {
      return const OutlinedButton(
        onPressed: null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.download_done),
            SizedBox(width: 8),
            Text('In your library'),
          ],
        ),
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
    final button = OutlinedButton.icon(
      onPressed: _download,
      icon: const Icon(Icons.download_outlined),
      label: Text('Download (${_size(widget.comic.entry.size)})'),
    );
    if (_error case final error?) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          button,
          const SizedBox(height: 4),
          Text(
            'Couldn’t download: $error',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      );
    }
    return button;
  }
}

String _size(int bytes) {
  if (bytes >= 1 << 30) return '${(bytes / (1 << 30)).toStringAsFixed(1)} GB';
  if (bytes >= 1 << 20) return '${(bytes / (1 << 20)).round()} MB';
  return '${(bytes / 1024).ceil()} KB';
}

/// Downloads waiting or running, one at a time; null when idle.
typedef DownloadQueueState = ({
  int total,
  int done,
  double current,
  String name,
});

final downloadQueueProvider =
    NotifierProvider<DownloadQueue, DownloadQueueState?>(DownloadQueue.new);

/// Downloads several comics in turn; keeps going when the sheet that
/// started it closes.
class DownloadQueue extends Notifier<DownloadQueueState?> {
  final _waiting = <(int, RemoteComic)>[];
  bool _stop = false;
  int _total = 0, _done = 0, _failed = 0;
  String? _lastError;

  @override
  DownloadQueueState? build() => null;

  /// Adds [comics] from [library]; [onDone] gets a summary when the queue
  /// empties.
  void add(
    int library,
    List<RemoteComic> comics, {
    void Function(String summary)? onDone,
  }) {
    final queued = {for (final (_, c) in _waiting) c.id};
    final fresh = [
      for (final c in comics)
        if (queued.add(c.id)) c,
    ];
    if (fresh.isEmpty) return;
    _waiting.addAll([for (final c in fresh) (library, c)]);
    _total += fresh.length;
    if (state == null) unawaited(_run(onDone));
  }

  void stop() {
    _stop = true;
    _waiting.clear();
  }

  Future<void> _run(void Function(String summary)? onDone) async {
    _stop = false;
    while (_waiting.isNotEmpty && !_stop) {
      final (library, comic) = _waiting.removeAt(0);
      state = (
        total: _total,
        done: _done,
        current: 0,
        name: p.basenameWithoutExtension(comic.fileName),
      );
      try {
        await ref
            .read(downloadsProvider.notifier)
            .download(
              library,
              comic,
              onProgress: (d, t) {
                if (t > 0 && ref.mounted && state != null) {
                  state = (
                    total: _total,
                    done: _done,
                    current: d / t,
                    name: state!.name,
                  );
                }
              },
              cancelled: () => _stop,
            );
        _done++;
      } on ShareException catch (e) {
        if (!_stop) {
          _failed++;
          _lastError = e.message;
        }
      } on Object catch (e) {
        _failed++;
        _lastError = describeFileError(e);
      }
      if (!ref.mounted) return;
    }
    final summary = [
      'Downloaded ${_done == 1 ? '1 comic' : '$_done comics'}',
      if (_stop) 'stopped',
      if (_failed > 0) '$_failed failed: $_lastError',
    ].join(' · ');
    _total = _done = _failed = 0;
    _lastError = null;
    state = null;
    onDone?.call(summary);
  }
}

/// In a paired library's group sheet: download every comic in it.
class DownloadAllButton extends ConsumerWidget {
  const DownloadAllButton({super.key, required this.comics});
  final List<LibraryComic> comics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(downloadQueueProvider);
    if (queue != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 140,
            child: LinearProgressIndicator(
              value: (queue.done + queue.current) / queue.total,
            ),
          ),
          const SizedBox(width: 8),
          Text('${queue.done + 1} of ${queue.total}'),
          TextButton(
            onPressed: () => ref.read(downloadQueueProvider.notifier).stop(),
            child: const Text('Stop'),
          ),
        ],
      );
    }
    final downloads = ref.watch(downloadsProvider);
    final byLibrary = <int, List<RemoteComic>>{};
    var size = 0;
    var have = 0;
    for (final c in comics) {
      final where = parseRemoteLocation(c.location);
      if (where == null) continue;
      if (downloads.containsKey(where.bookId)) {
        have++;
        continue;
      }
      final remote = ref
          .read(remoteComicsProvider(where.library))
          .comics
          .where((r) => r.id == where.bookId)
          .firstOrNull;
      if (remote == null) continue;
      byLibrary.putIfAbsent(where.library, () => []).add(remote);
      size += remote.size;
    }
    final missing = byLibrary.values.fold(0, (n, l) => n + l.length);
    if (missing == 0) {
      if (have == 0) return const SizedBox.shrink();
      final notifier = ref.read(downloadsProvider.notifier);
      final anyRemovable = comics.any(
        (c) => switch (parseRemoteLocation(c.location)) {
          final where? => notifier.removable(where.bookId),
          null => false,
        },
      );
      if (!anyRemovable) {
        return OutlinedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.download_done),
          label: Text(
            have == 1 ? 'In your library' : 'All $have in your library',
          ),
        );
      }
      return OutlinedButton.icon(
        onPressed: () async {
          for (final c in comics) {
            if (parseRemoteLocation(c.location) case final where?) {
              await ref.read(downloadsProvider.notifier).remove(where.bookId);
            }
          }
        },
        icon: const Icon(Icons.download_done),
        label: Text(
          have == 1 ? 'Downloaded · Remove' : 'All $have downloaded · Remove',
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: () {
        final messenger = ScaffoldMessenger.of(context);
        for (final MapEntry(key: library, value: list) in byLibrary.entries) {
          ref
              .read(downloadQueueProvider.notifier)
              .add(
                library,
                list,
                onDone: (s) =>
                    messenger.showSnackBar(SnackBar(content: Text(s))),
              );
        }
      },
      icon: const Icon(Icons.download_outlined),
      label: Text(
        missing == 1
            ? 'Download 1 (${_size(size)})'
            : 'Download ${have > 0 ? '$missing more' : 'all $missing'} '
                  '(${_size(size)})',
      ),
    );
  }
}

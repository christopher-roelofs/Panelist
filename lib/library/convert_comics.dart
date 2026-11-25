import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../app/providers.dart';
import '../core/metadata/cbz_converter.dart';
import '../data/database.dart';
import '../platform/android_documents.dart';
import 'comic_info_editor.dart';
import 'library_model.dart';
import 'library_scanner.dart';

const _convertibleExtensions = {'.cbr', '.cb7', '.cbt', '.rar', '.7z', '.tar'};

/// Whether [comic] can be converted to CBZ here (judged by its name, so it's
/// cheap for a whole publisher; [convertComics] checks the contents).
bool isConvertibleComic(LibraryComic comic) =>
    canEditMetadata &&
    !AndroidDocuments.isContentUri(comic.location) &&
    _convertibleExtensions.contains(
      p.extension(comic.entry.fileName).toLowerCase(),
    );

/// Moves [path] to the desktop's trash. False if there's no trash to use
/// (the file is then left where it is).
Future<bool> moveToTrash(String path) async {
  if (!Platform.isLinux) return false;
  for (final gio in ['/usr/bin/gio', 'gio']) {
    try {
      final r = await Process.run(gio, ['trash', path]);
      if (r.exitCode == 0) return !File(path).existsSync();
    } on ProcessException {
      // Try the next one.
    }
  }
  return false;
}

/// What converting did.
typedef ConvertResult = ({
  int converted,
  int kept,
  int failed,
  List<String> errors,
});

/// Converts each of [comics] to CBZ, moves its reading progress to the new
/// book ID, and moves the original to the trash ([trash], so tests can
/// stand in). Originals that can't be trashed are kept and counted.
Future<ConvertResult> convertComics(
  AppDatabase db,
  List<LibraryComic> comics, {
  void Function(int done)? onProgress,
  bool Function()? shouldStop,
  Future<bool> Function(String path) trash = moveToTrash,
}) async {
  var converted = 0, kept = 0, failed = 0;
  final errors = <String>[];
  for (final (i, comic) in comics.indexed) {
    if (shouldStop?.call() ?? false) break;
    try {
      final c = await convertToCbz(comic.location);
      await db.moveBook(c.oldId, c.newId, c.cbzPath);
      converted++;
      if (File(comic.location).existsSync() && !await trash(comic.location)) {
        kept++;
      }
    } on Object catch (e) {
      failed++;
      errors.add('$e');
    } finally {
      onProgress?.call(i + 1);
    }
  }
  return (converted: converted, kept: kept, failed: failed, errors: errors);
}

String describeConvertResult(ConvertResult r) {
  String n(int count) => count == 1 ? '1 comic' : '$count comics';
  return [
    'Converted ${n(r.converted)} to CBZ',
    if (r.kept > 0)
      '${r.kept} original${r.kept == 1 ? '' : 's'} kept '
          '(no trash)',
    if (r.failed > 0) '${r.failed} failed: ${r.errors.first}',
  ].join(' · ');
}

/// Asks, then converts [comics] with progress, then rescans.
Future<void> convertWithProgress(
  BuildContext context,
  WidgetRef ref,
  List<LibraryComic> comics,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final result = await showDialog<ConvertResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ConvertDialog(comics: comics),
  );
  if (result == null) return;
  unawaited(ref.read(libraryScanProvider.notifier).scan());
  messenger.showSnackBar(
    SnackBar(
      content: Text(describeConvertResult(result)),
      duration: Duration(seconds: result.failed > 0 ? 10 : 4),
    ),
  );
}

class _ConvertDialog extends ConsumerStatefulWidget {
  const _ConvertDialog({required this.comics});

  final List<LibraryComic> comics;

  @override
  ConsumerState<_ConvertDialog> createState() => _ConvertDialogState();
}

class _ConvertDialogState extends ConsumerState<_ConvertDialog> {
  int? _done;
  bool _stopping = false;

  Future<void> _convert() async {
    setState(() => _done = 0);
    final result = await convertComics(
      ref.read(databaseProvider),
      widget.comics,
      onProgress: (done) {
        if (mounted) setState(() => _done = done);
      },
      shouldStop: () => _stopping,
    );
    if (mounted) Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = widget.comics.length;
    final done = _done;
    final what = total == 1
        ? '“${widget.comics.single.entry.fileName}”'
        : '$total comics';
    return AlertDialog(
      title: Text(total == 1 ? 'Convert to CBZ?' : 'Convert $total to CBZ?'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Makes a CBZ of $what with the same pages, so its details can '
              'be edited. Reading progress carries over. '
              '${Platform.isLinux ? 'The original goes to the trash.' : 'The original is kept.'}',
              style: theme.textTheme.bodyMedium,
            ),
            if (done != null) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: done / total),
              const SizedBox(height: 8),
              Text(
                _stopping ? 'Stopping after this one…' : '$done of $total',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (done == null)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          )
        else
          TextButton(
            onPressed: _stopping
                ? null
                : () => setState(() => _stopping = true),
            child: const Text('Stop'),
          ),
        FilledButton(
          onPressed: done == null ? _convert : null,
          child: const Text('Convert'),
        ),
      ],
    );
  }
}

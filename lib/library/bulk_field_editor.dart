import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../app/providers.dart';
import '../core/metadata/comic_info.dart';
import '../core/metadata/comic_info_document.dart';
import '../core/metadata/comic_info_writer.dart';
import '../core/sources/open_source.dart';
import '../data/book_extensions.dart';
import '../data/database.dart';
import 'comic_info_editor.dart';
import 'library_model.dart';
import 'library_scanner.dart';

/// What a bulk edit did.
typedef BulkResult = ({int changed, int unchanged, int skipped, int failed});

/// Sets ComicInfo [field] to [value] (blank removes it) in every editable
/// comic of [comics], one at a time. Comics that can't be edited yet (not
/// CBZ) are skipped; ones already set to [value] aren't rewritten.
/// [onProgress] gets the number done so far.
Future<BulkResult> setComicInfoField(
  AppDatabase db,
  List<LibraryComic> comics,
  String field,
  String value, {
  void Function(int done)? onProgress,
}) async {
  var changed = 0, unchanged = 0, skipped = 0, failed = 0;
  final want = value.trim();
  for (final (i, comic) in comics.indexed) {
    try {
      if (!isEditableComic(comic.location)) {
        skipped++;
        continue;
      }
      final source = await openSource(comic.location);
      final String? xml;
      try {
        xml = await source.readComicInfo();
      } finally {
        await source.close();
      }
      final doc = ComicInfoDocument.parse(xml);
      if ((doc[field] ?? '') == want) {
        unchanged++;
        continue;
      }
      doc[field] = want;
      final updated = doc.toXmlString();
      await writeComicInfoToCbz(comic.location, updated);
      final info = ComicInfo.parse(updated);
      final bookId = comic.entry.bookId;
      if (info != null && bookId != null) {
        await db.saveMetadata(bookId, metadataFrom(info));
      }
      changed++;
    } on Object {
      failed++;
    } finally {
      onProgress?.call(i + 1);
    }
  }
  return (
    changed: changed,
    unchanged: unchanged,
    skipped: skipped,
    failed: failed,
  );
}

/// Asks for a new value of [field] for all of [comics] and saves it into
/// their files. [current] prefills the box (null for "unknown").
Future<void> editFieldForAll(
  BuildContext context,
  WidgetRef ref, {
  required List<LibraryComic> comics,
  required String field,
  required String label,
  required String? current,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final result = await showDialog<BulkResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _BulkFieldDialog(
      comics: comics,
      field: field,
      label: label,
      current: current,
    ),
  );
  if (result == null) return;
  unawaited(ref.read(libraryScanProvider.notifier).scan());
  messenger.showSnackBar(SnackBar(content: Text(describeBulkResult(result))));
}

/// [field] as the library last read it from [comic]'s ComicInfo, where
/// it's kept; null if unknown.
String? storedField(LibraryComic comic, String field) => switch (field) {
  'Series' => comic.entry.series,
  'Number' => comic.entry.number,
  'Publisher' => comic.entry.publisher,
  _ => null,
};

String describeBulkResult(BulkResult r) {
  String n(int count) => count == 1 ? '1 comic' : '$count comics';
  return [
    'Updated ${n(r.changed)}',
    if (r.unchanged > 0) '${r.unchanged} already set',
    if (r.skipped > 0) '${r.skipped} skipped (only CBZ for now)',
    if (r.failed > 0) '${r.failed} couldn’t be saved',
  ].join(' · ');
}

class _BulkFieldDialog extends ConsumerStatefulWidget {
  const _BulkFieldDialog({
    required this.comics,
    required this.field,
    required this.label,
    required this.current,
  });

  final List<LibraryComic> comics;
  final String field;
  final String label;
  final String? current;

  @override
  ConsumerState<_BulkFieldDialog> createState() => _BulkFieldDialogState();
}

class _BulkFieldDialogState extends ConsumerState<_BulkFieldDialog> {
  late final _controller = TextEditingController(text: widget.current ?? '');
  late final int _editable = widget.comics
      .where((c) => isEditableComic(c.location))
      .length;
  int? _done;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Whether saving would change anything: a new value, or comics whose
  /// files don't say this yet (a series named from file names).
  bool get _changed {
    final want = _controller.text.trim();
    return want != (widget.current ?? '') ||
        widget.comics.any((c) => (storedField(c, widget.field) ?? '') != want);
  }

  Future<void> _save() async {
    if (!_changed || _editable == 0 || _done != null) return;
    setState(() => _done = 0);
    final result = await setComicInfoField(
      ref.read(databaseProvider),
      widget.comics,
      widget.field,
      _controller.text,
      onProgress: (done) {
        if (mounted) setState(() => _done = done);
      },
    );
    if (mounted) Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = widget.comics.length;
    final other = total - _editable;
    final done = _done;
    return AlertDialog(
      title: Text('Edit ${widget.label.toLowerCase()}'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              enabled: done == null,
              decoration: InputDecoration(
                labelText: widget.label,
                border: const OutlineInputBorder(),
                helperText: 'Leave empty to remove it',
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 16),
            Text(
              _editable == 0
                  ? 'None of these comics can be edited yet: only CBZ '
                        'files can be for now.'
                  : 'Saves into the ComicInfo.xml of '
                        '${_editable == 1 ? '1 comic' : '$_editable comics'}.'
                        '${other > 0 ? ' $other other ${other == 1 ? 'file isn’t' : 'files aren’t'} CBZ and will be skipped.' : ''}',
              style: theme.textTheme.bodySmall,
            ),
            if (done != null) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: total == 0 ? null : done / total),
              const SizedBox(height: 8),
              Text('$done of $total', style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: done == null ? () => Navigator.of(context).pop() : null,
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: done == null && _changed && _editable > 0 ? _save : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

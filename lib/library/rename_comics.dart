import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../app/providers.dart';
import '../data/database.dart';
import '../platform/android_documents.dart';
import 'comic_info_editor.dart';
import 'library_model.dart';
import 'library_providers.dart';
import 'library_scanner.dart';
import 'rename_template.dart';

const renameTemplateKey = 'rename.template';

/// Whether [comic]'s file can be renamed here.
bool canRenameComic(LibraryComic comic) =>
    canEditMetadata && !AndroidDocuments.isContentUri(comic.location);

/// The values a template is filled from: ComicInfo first, then what the
/// file and folder names say.
Map<String, String?> templateValues(LibraryComic c) => {
  'series': c.series,
  'number': c.number,
  'year': c.year?.toString(),
  'volume': c.entry.volume?.toString(),
  'publisher': c.publisher,
  'title': c.entry.title,
};

enum RenameState { rename, same, clash, exists, noName }

/// Where one comic would go.
typedef RenamePlan = ({LibraryComic comic, String? target, RenameState state});

/// Where each of [comics] goes by [template]. A template without `/`
/// renames in place; with `/`, its folders start at the comic's library
/// folder ([rootOf]). Nothing is overwritten: a target that exists, or
/// that two comics share, is a clash.
List<RenamePlan> planRenames(
  List<LibraryComic> comics,
  String template,
  String? Function(LibraryComic) rootOf, {
  bool Function(String path)? exists,
}) {
  final there =
      exists ??
      (path) =>
          FileSystemEntity.typeSync(path) != FileSystemEntityType.notFound;
  final organise = template.contains('/');
  final plans = <RenamePlan>[];
  for (final c in comics) {
    final rendered = renderTemplate(template, templateValues(c));
    final base = organise ? rootOf(c) : p.dirname(c.location);
    if (rendered == null || base == null) {
      plans.add((comic: c, target: null, state: RenameState.noName));
      continue;
    }
    final target =
        p.joinAll([base, ...rendered.split('/')]) +
        p.extension(c.location).toLowerCase();
    final state = target == c.location
        ? RenameState.same
        // Only the letters' case changes: the "existing" file is this one.
        : there(target) && target.toLowerCase() != c.location.toLowerCase()
        ? RenameState.exists
        : RenameState.rename;
    plans.add((comic: c, target: target, state: state));
  }
  // Two comics to one name: neither moves.
  final counts = <String, int>{};
  for (final r in plans) {
    if (r.target case final t?) {
      counts.update(t, (n) => n + 1, ifAbsent: () => 1);
    }
  }
  return [
    for (final r in plans)
      r.state == RenameState.rename && counts[r.target]! > 1
          ? (comic: r.comic, target: r.target, state: RenameState.clash)
          : r,
  ];
}

typedef RenameResult = ({int renamed, int failed, List<String> errors});

/// Moves the comics planned to [RenameState.rename], keeping their reading
/// progress (book IDs come from the contents, so only the path changes),
/// then removes folders inside [roots] that were left empty.
Future<RenameResult> renameComics(
  AppDatabase db,
  List<RenamePlan> plans, {
  Set<String> roots = const {},
}) async {
  var renamed = 0, failed = 0;
  final errors = <String>[];
  final left = <String>{};
  for (final r in plans) {
    if (r.state != RenameState.rename) continue;
    final from = r.comic.location, to = r.target!;
    try {
      await Directory(p.dirname(to)).create(recursive: true);
      // Re-check just before: never overwrite.
      if (to.toLowerCase() != from.toLowerCase() &&
          FileSystemEntity.typeSync(to) != FileSystemEntityType.notFound) {
        throw FileSystemException('Already exists', to);
      }
      await File(from).rename(to);
      if (r.comic.entry.bookId case final id?) await db.moveBook(id, id, to);
      left.add(p.dirname(from));
      renamed++;
    } on Object catch (e) {
      failed++;
      errors.add('${r.comic.entry.fileName}: $e');
    }
  }
  for (final dir in left) {
    await _removeEmpty(dir, roots);
  }
  return (renamed: renamed, failed: failed, errors: errors);
}

/// Deletes [dir] and its parents while they're empty, stopping at a
/// library folder (never deleted) or anything outside one.
Future<void> _removeEmpty(String dir, Set<String> roots) async {
  var d = dir;
  while (!roots.contains(d) && roots.any((r) => p.isWithin(r, d))) {
    final folder = Directory(d);
    try {
      if (!folder.existsSync() || folder.listSync().isNotEmpty) return;
      await folder.delete();
    } on FileSystemException {
      return;
    }
    d = p.dirname(d);
  }
}

String describeRenameResult(RenameResult r) => [
  'Renamed ${r.renamed == 1 ? '1 comic' : '${r.renamed} comics'}',
  if (r.failed > 0) '${r.failed} failed: ${r.errors.first}',
].join(' · ');

/// Shows where [comics] would go, then renames them.
Future<void> renameWithPreview(
  BuildContext context,
  WidgetRef ref,
  List<LibraryComic> comics,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final template =
      await ref.read(databaseProvider).setting(renameTemplateKey) ??
      defaultRenameTemplate;
  if (!context.mounted) return;
  final result = await showDialog<RenameResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _RenameDialog(comics: comics, template: template),
  );
  if (result == null) return;
  unawaited(ref.read(libraryScanProvider.notifier).scan());
  messenger.showSnackBar(
    SnackBar(
      content: Text(describeRenameResult(result)),
      duration: Duration(seconds: result.failed > 0 ? 10 : 4),
    ),
  );
}

class _RenameDialog extends ConsumerStatefulWidget {
  const _RenameDialog({required this.comics, required this.template});
  final List<LibraryComic> comics;
  final String template;

  @override
  ConsumerState<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends ConsumerState<_RenameDialog> {
  late final _template = TextEditingController(text: widget.template);
  bool _busy = false;

  @override
  void dispose() {
    _template.dispose();
    super.dispose();
  }

  Map<int, String> get _roots => {
    for (final r
        in ref.read(libraryRootsProvider).value ?? const <LibraryRoot>[])
      r.id: r.location,
  };

  List<RenamePlan> _plan() {
    final roots = _roots;
    return planRenames(
      widget.comics,
      _template.text.trim(),
      (c) => roots[c.entry.rootId],
    );
  }

  Future<void> _rename(List<RenamePlan> plans) async {
    setState(() => _busy = true);
    final db = ref.read(databaseProvider);
    await db.setSetting(renameTemplateKey, _template.text.trim());
    final result = await renameComics(db, plans, roots: _roots.values.toSet());
    if (mounted) Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final problem = checkTemplate(_template.text);
    final plans = problem == null ? _plan() : const <RenamePlan>[];
    final moving = plans.where((r) => r.state == RenameState.rename).toList();
    final organise = _template.text.contains('/');
    final roots = _roots;
    String shown(LibraryComic c, String path) {
      final root = organise ? roots[c.entry.rootId] : p.dirname(c.location);
      return root == null ? path : p.relative(path, from: root);
    }

    String count(RenameState s) {
      final n = plans.where((r) => r.state == s).length;
      return n == 0
          ? ''
          : switch (s) {
              RenameState.same => '$n already named so',
              RenameState.clash => '$n would share a name',
              RenameState.exists => '$n would replace another file',
              RenameState.noName => '$n without the details to name',
              RenameState.rename => '',
            };
    }

    final skipped = [for (final s in RenameState.values) count(s)]
        .where((t) => t.isNotEmpty)
        .join(' · ');

    return AlertDialog(
      title: Text(
        widget.comics.length == 1
            ? 'Rename comic'
            : 'Rename ${widget.comics.length} comics',
      ),
      content: SizedBox(
        width: 640,
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _template,
              enabled: !_busy,
              decoration: InputDecoration(
                labelText: 'Name template',
                border: const OutlineInputBorder(),
                errorText: problem,
                helperMaxLines: 3,
                helperText:
                    'Fields: {series} {number} {number:3} {year} {volume} '
                    '{publisher} {title} {title:40}. Add / to sort into '
                    'folders inside the library folder; without it files '
                    'stay where they are.',
                suffixIcon: IconButton(
                  tooltip: 'Default',
                  icon: const Icon(Icons.restart_alt),
                  onPressed: () =>
                      setState(() => _template.text = defaultRenameTemplate),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            if (skipped.isNotEmpty)
              Text(
                'Left as they are: $skipped.',
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  for (final r in plans.take(500))
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        switch (r.state) {
                          RenameState.rename => Icons.drive_file_rename_outline,
                          RenameState.same => Icons.check,
                          _ => Icons.block,
                        },
                        color: r.state == RenameState.rename
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline,
                      ),
                      title: Text(
                        r.target == null
                            ? r.comic.entry.fileName
                            : shown(r.comic, r.target!),
                      ),
                      subtitle: r.state == RenameState.same
                          ? null
                          : Text(
                              r.state == RenameState.rename
                                  ? 'from ${r.comic.entry.fileName}'
                                  : switch (r.state) {
                                      RenameState.clash =>
                                        'another comic would get this name',
                                      RenameState.exists =>
                                        'a file with this name exists',
                                      _ => 'no series or number',
                                    },
                            ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy || moving.isEmpty ? null : () => _rename(moving),
          child: Text(
            moving.length == 1 ? 'Rename 1' : 'Rename ${moving.length}',
          ),
        ),
      ],
    );
  }
}

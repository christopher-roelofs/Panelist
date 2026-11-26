import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../app/providers.dart';
import '../core/metadata/comic_info_document.dart';
import '../core/sources/open_source.dart';
import '../data/database.dart';
import '../platform/android_documents.dart';
import 'comic_info_editor.dart';
import 'library_model.dart';
import 'library_providers.dart';
import 'library_scanner.dart';
import 'publisher_aliases.dart';
import 'rename_template.dart';

const renameTemplateKey = 'rename.template';
const keepOrganizedKey = 'organize.auto';

/// Ready-made layouts for the whole library.
const organizeLayouts = [
  (
    name: 'By publisher',
    template: '{publisher}/{series} ({volume})/{series} {number:3} ({year})',
  ),
  (
    name: 'By series',
    template: '{series} ({volume})/{series} {number:3} ({year})',
  ),
  (name: 'Files only', template: defaultRenameTemplate),
];

/// Whether [comic]'s file can be renamed here.
bool canRenameComic(LibraryComic comic) =>
    canEditMetadata &&
    !AndroidDocuments.isContentUri(comic.location) &&
    !isRemoteLocation(comic.location);

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

/// [comic] with the details just saved in [doc] (the library's copy is
/// only updated by the next scan).
LibraryComic withDetails(
  LibraryComic comic,
  ComicInfoDocument doc, {
  PublisherAliases aliases = const PublisherAliases(),
}) => LibraryComic(
  comic.entry.copyWith(
    series: Value(doc['Series']),
    number: Value(doc['Number']),
    year: Value(int.tryParse(doc['Year'] ?? '')),
    volume: Value(int.tryParse(doc['Volume'] ?? '')),
    publisher: Value(doc['Publisher']),
    title: Value(doc['Title']),
  ),
  comic.progress,
  publisher: aliases.apply(doc['Publisher']),
);

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
/// then removes folders inside [roots] that were left empty. Stops between
/// comics when [shouldStop] says so; what has moved stays moved.
Future<RenameResult> renameComics(
  AppDatabase db,
  List<RenamePlan> plans, {
  Set<String> roots = const {},
  void Function(int done)? onProgress,
  bool Function()? shouldStop,
}) async {
  var renamed = 0, failed = 0;
  final errors = <String>[];
  final left = <String>{};
  final moving = plans.where((r) => r.state == RenameState.rename).toList();
  for (final (i, r) in moving.indexed) {
    if (shouldStop?.call() ?? false) break;
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
    } finally {
      onProgress?.call(i + 1);
    }
  }
  // Deepest first, so a parent emptied by its child goes too.
  for (final dir in left.toList()..sort((a, b) => b.length - a.length)) {
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

String describeRenameResult(RenameResult r, {bool organize = false}) => [
  '${organize ? 'Moved' : 'Renamed'} '
      '${r.renamed == 1 ? '1 comic' : '${r.renamed} comics'}',
  if (r.failed > 0) '${r.failed} failed: ${r.errors.first}',
].join(' · ');

Future<String> _savedTemplate(WidgetRef ref) async =>
    await ref.read(databaseProvider).setting(renameTemplateKey) ??
    organizeLayouts.first.template;

/// Shows where [comics] would go, then renames them.
Future<void> renameWithPreview(
  BuildContext context,
  WidgetRef ref,
  List<LibraryComic> comics,
) => _showRename(context, ref, comics, organize: false);

/// The whole library, by a layout or template.
Future<void> organizeLibrary(BuildContext context, WidgetRef ref) =>
    _showRename(
      context,
      ref,
      ref.read(libraryComicsProvider).where(canRenameComic).toList(),
      organize: true,
    );

Future<void> _showRename(
  BuildContext context,
  WidgetRef ref,
  List<LibraryComic> comics, {
  required bool organize,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final template = await _savedTemplate(ref);
  if (!context.mounted) return;
  final result = await showDialog<RenameResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        _RenameDialog(comics: comics, template: template, organize: organize),
  );
  if (result == null) return;
  unawaited(ref.read(libraryScanProvider.notifier).scan());
  messenger.showSnackBar(
    SnackBar(
      content: Text(describeRenameResult(result, organize: organize)),
      duration: Duration(seconds: result.failed > 0 ? 10 : 4),
    ),
  );
}

/// Whether comics are filed by the saved template as soon as their details
/// are saved.
final keepOrganizedProvider = FutureProvider<bool>(
  (ref) async =>
      await ref.watch(databaseProvider).setting(keepOrganizedKey) == 'true',
);

/// Files [comic] (whose details were just saved in [doc]) by the saved
/// template, if the user keeps the library organized. Returns where it is
/// now.
Future<String> keepOrganized(
  WidgetRef ref,
  LibraryComic comic,
  ComicInfoDocument doc,
) async {
  if (!await ref.read(keepOrganizedProvider.future) || !canRenameComic(comic)) {
    return comic.location;
  }
  final aliases = await ref.read(publisherAliasesProvider.future);
  final roots = {
    for (final r in await ref.read(databaseProvider).roots()) r.id: r.location,
  };
  final plans = planRenames(
    [withDetails(comic, doc, aliases: aliases)],
    await _savedTemplate(ref),
    (c) => roots[c.entry.rootId],
  );
  final r = await renameComics(
    ref.read(databaseProvider),
    plans,
    roots: roots.values.toSet(),
  );
  return r.renamed == 1 ? plans.single.target! : comic.location;
}

/// Settings switch for [keepOrganizedProvider].
class KeepOrganizedTile extends ConsumerWidget {
  const KeepOrganizedTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => SwitchListTile(
    secondary: const Icon(Icons.auto_fix_high_outlined),
    title: const Text('Keep organized'),
    subtitle: const Text(
      'File a comic by the last layout used as soon as its details are '
      'saved (looked up or edited)',
    ),
    value: ref.watch(keepOrganizedProvider).value ?? false,
    onChanged: (v) async {
      await ref.read(databaseProvider).setSetting(keepOrganizedKey, '$v');
      ref.invalidate(keepOrganizedProvider);
    },
  );
}

class _RenameDialog extends ConsumerStatefulWidget {
  const _RenameDialog({
    required this.comics,
    required this.template,
    required this.organize,
  });
  final List<LibraryComic> comics;
  final String template;
  final bool organize;

  @override
  ConsumerState<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends ConsumerState<_RenameDialog> {
  late final _template = TextEditingController(text: widget.template);
  int? _done;
  bool _stopping = false;
  late bool _custom = !organizeLayouts.any(
    (l) => l.template == widget.template,
  );

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
    setState(() => _done = 0);
    final db = ref.read(databaseProvider);
    await db.setSetting(renameTemplateKey, _template.text.trim());
    final result = await renameComics(
      db,
      plans,
      roots: _roots.values.toSet(),
      onProgress: (n) {
        if (mounted) setState(() => _done = n);
      },
      shouldStop: () => _stopping,
    );
    if (mounted) Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Rebuild once the library folder has loaded.
    ref.watch(libraryRootsProvider);
    final problem = checkTemplate(_template.text);
    final plans = problem == null ? _plan() : const <RenamePlan>[];
    final moving = plans.where((r) => r.state == RenameState.rename).toList();
    final organise = _template.text.contains('/');
    final roots = _roots;
    final done = _done;
    final busy = done != null;
    final rootNames = {
      for (final r
          in ref.read(libraryRootsProvider).value ?? const <LibraryRoot>[])
        r.id: r.name,
    };
    // The whole path from the library folder down, breakable after each /.
    String shown(LibraryComic c, String path) {
      final root = roots[c.entry.rootId];
      final inside = root == null || !p.isWithin(root, path)
          ? path
          : p.joinAll([
              rootNames[c.entry.rootId] ?? p.basename(root),
              p.relative(path, from: root),
            ]);
      return inside.replaceAll(p.separator, '${p.separator}\u200B');
    }

    final template = _template.text.trim();
    final missing = {
      for (final r in plans)
        r: missingFields(template, templateValues(r.comic)),
    };
    final missingCounts = <String, int>{};
    for (final r in plans) {
      if (r.state == RenameState.noName) continue;
      for (final f in missing[r]!) {
        missingCounts.update(f, (n) => n + 1, ifAbsent: () => 1);
      }
    }
    final sampleRoot = rootNames.values.firstOrNull ?? 'Library';
    final sample = problem == null
        ? renderTemplate(template, sampleValues)
        : null;

    final skipped = [
      for (final s in RenameState.values)
        if (plans.where((r) => r.state == s).length case final n when n > 0)
          switch (s) {
            RenameState.same => '$n already in place',
            RenameState.clash => '$n would share a name',
            RenameState.exists => '$n would replace another file',
            RenameState.noName => '$n without the details to name',
            RenameState.rename => null,
          },
    ].nonNulls.join(' · ');

    final n = widget.comics.length;
    return AlertDialog(
      title: Text(
        widget.organize
            ? 'Organize library'
            : n == 1
            ? 'Rename comic'
            : 'Rename $n comics',
      ),
      content: SizedBox(
        width: 680,
        height: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final l in organizeLayouts)
                  ChoiceChip(
                    label: Text(l.name),
                    selected: !_custom && _template.text == l.template,
                    onSelected: busy
                        ? null
                        : (_) => setState(() {
                            _custom = false;
                            _template.text = l.template;
                          }),
                  ),
                ChoiceChip(
                  label: const Text('Custom'),
                  selected: _custom,
                  onSelected: busy
                      ? null
                      : (_) => setState(() => _custom = true),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_custom)
              TextField(
                controller: _template,
                enabled: !busy,
                decoration: InputDecoration(
                  labelText: 'Name template',
                  border: const OutlineInputBorder(),
                  errorText: problem,
                  helperMaxLines: 3,
                  helperText:
                      'Fields: {series} {number} {number:3} {year} {volume} '
                      '{publisher} {title} {title:40}. A / makes folders '
                      'inside the library folder; without one, files stay '
                      'where they are.',
                ),
                onChanged: (_) => setState(() {}),
              ),
            if (sample != null) ...[
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: 'For example, Saga #1 by Image Comics: ',
                    ),
                    TextSpan(
                      text:
                          '${[sampleRoot, if (!organise) '…', ...sample.split('/')].join('/\u200B')}.cbz',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                style: theme.textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 12),
            Text(
              [
                if (moving.isNotEmpty)
                  '${moving.length} to ${organise ? 'move' : 'rename'}.',
                if (skipped.isNotEmpty) 'Left as they are: $skipped.',
                if (organise)
                  'Folders left empty are removed; nothing is overwritten.',
              ].join(' '),
              style: theme.textTheme.bodySmall,
            ),
            if (missingCounts.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '${[for (final MapEntry(key: f, value: n) in missingCounts.entries) '$n ${n == 1 ? 'has' : 'have'} no $f'].join(', ')}, '
                'so that part is left out of their names. Look up info '
                'first to fill it in.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.tertiary,
                ),
              ),
            ],
            const SizedBox(height: 8),
            if (busy) ...[
              LinearProgressIndicator(
                value: moving.isEmpty ? null : done / moving.length,
              ),
              const SizedBox(height: 8),
            ],
            Expanded(
              child: ListView(
                children: [
                  // What changes first, then what doesn't.
                  for (final r in [
                    ...moving,
                    ...plans.where((r) => r.state != RenameState.rename),
                  ].take(1000))
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        switch (r.state) {
                          RenameState.rename =>
                            organise
                                ? Icons.drive_file_move_outline
                                : Icons.drive_file_rename_outline,
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
                      subtitle: Text(
                        [
                          switch (r.state) {
                            RenameState.rename =>
                              'from ${shown(r.comic, r.comic.location)}',
                            RenameState.same => 'already in place',
                            RenameState.clash =>
                              'another comic would get this name',
                            RenameState.exists =>
                              'a file with this name exists',
                            RenameState.noName => 'no series or number',
                          },
                          if (r.state != RenameState.noName &&
                              missing[r]!.isNotEmpty)
                            'no ${missing[r]!.join(', ')}',
                        ].join(' · '),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (busy)
          TextButton(
            onPressed: _stopping
                ? null
                : () => setState(() => _stopping = true),
            child: Text(_stopping ? 'Stopping…' : 'Stop'),
          )
        else
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        FilledButton(
          onPressed: busy || moving.isEmpty ? null : () => _rename(moving),
          child: Text('${organise ? 'Move' : 'Rename'} ${moving.length}'),
        ),
      ],
    );
  }
}

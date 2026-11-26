import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../app/providers.dart';
import '../core/metadata/comic_info.dart';
import '../core/metadata/comic_info_document.dart';
import '../core/metadata/comic_info_writer.dart';
import '../core/sources/fingerprint.dart';
import '../core/sources/open_source.dart';
import '../data/book_extensions.dart';
import '../platform/android_documents.dart';
import 'info_lookup.dart';
import 'library_model.dart';
import 'library_scanner.dart';
import 'library_view.dart' show LibraryCover;
import 'rename_comics.dart';

/// Whether this platform edits metadata (desktop: the library lives there,
/// and batch tagging is desk work).
bool get canEditMetadata =>
    Platform.isLinux || Platform.isWindows || Platform.isMacOS;

/// Whether [location] is a file whose ComicInfo Panelist can save: a ZIP
/// (CBZ, or a ZIP misnamed .cbr). Other formats come later.
bool isEditableComic(String location) {
  if (!canEditMetadata ||
      AndroidDocuments.isContentUri(location) ||
      isRemoteLocation(location)) {
    return false;
  }
  try {
    final magic = readMagic(location, 4);
    return magic.length == 4 &&
        magic[0] == 0x50 &&
        magic[1] == 0x4B &&
        (magic[2] == 0x03 || magic[2] == 0x05);
  } on FileSystemException {
    return false;
  }
}

enum _Kind { text, multiline, integer, choice }

class _Field {
  const _Field(
    this.name,
    this.label, {
    this.kind = _Kind.text,
    this.min,
    this.max,
    this.choices = const [],
    this.wide = false,
    this.hint,
  });

  /// The ComicInfo element.
  final String name;
  final String label;
  final _Kind kind;
  final int? min;
  final int? max;
  final List<String> choices;

  /// Takes a whole row.
  final bool wide;
  final String? hint;

  /// An error message for [value], or null if it's fine.
  String? validate(String value) {
    final v = value.trim();
    if (v.isEmpty || kind != _Kind.integer) return null;
    final n = int.tryParse(v);
    if (n == null) return 'A whole number';
    if (min != null && n < min!) return 'At least $min';
    if (max != null && n > max!) return 'At most $max';
    return null;
  }
}

const _list = 'Separate several with commas';

const _sections = <(String, List<_Field>)>[
  (
    'Issue',
    [
      _Field('Series', 'Series', wide: true),
      _Field('Title', 'Issue title', wide: true),
      _Field('Number', 'Number', hint: 'e.g. 1, 12.1, Annual 1'),
      _Field('Count', 'Issues in series', kind: _Kind.integer, min: 1),
      _Field('Volume', 'Volume', kind: _Kind.integer, min: 1),
      _Field('Year', 'Year', kind: _Kind.integer, min: 1800, max: 2200),
      _Field('Month', 'Month', kind: _Kind.integer, min: 1, max: 12),
      _Field('Day', 'Day', kind: _Kind.integer, min: 1, max: 31),
      _Field('Publisher', 'Publisher'),
      _Field('Imprint', 'Imprint'),
      _Field('Format', 'Format', hint: 'e.g. Series, TPB, One-Shot'),
    ],
  ),
  (
    'Credits',
    [
      _Field('Writer', 'Writer', hint: _list),
      _Field('Penciller', 'Penciller', hint: _list),
      _Field('Inker', 'Inker', hint: _list),
      _Field('Colorist', 'Colorist', hint: _list),
      _Field('Letterer', 'Letterer', hint: _list),
      _Field('CoverArtist', 'Cover artist', hint: _list),
      _Field('Editor', 'Editor', hint: _list),
      _Field('Translator', 'Translator', hint: _list),
    ],
  ),
  (
    'Story',
    [
      _Field('Summary', 'Summary', kind: _Kind.multiline, wide: true),
      _Field('StoryArc', 'Story arc'),
      _Field('StoryArcNumber', 'Part of arc'),
      _Field('SeriesGroup', 'Series group'),
      _Field('Genre', 'Genre', hint: _list),
      _Field('Tags', 'Tags', hint: _list),
      _Field('Characters', 'Characters', hint: _list),
      _Field('Teams', 'Teams', hint: _list),
      _Field('Locations', 'Locations', hint: _list),
      _Field('MainCharacterOrTeam', 'Main character or team'),
    ],
  ),
  (
    'More',
    [
      _Field('AlternateSeries', 'Alternate series'),
      _Field('AlternateNumber', 'Alternate number'),
      _Field('AlternateCount', 'Alternate count', kind: _Kind.integer, min: 1),
      _Field('LanguageISO', 'Language', hint: 'ISO code, e.g. en'),
      _Field(
        'AgeRating',
        'Age rating',
        kind: _Kind.choice,
        choices: [
          'Unknown', 'Adults Only 18+', 'Early Childhood', 'Everyone', //
          'Everyone 10+', 'G', 'Kids to Adults', 'M', 'MA15+',
          'Mature 17+', 'PG', 'R18+', 'Rating Pending', 'Teen', 'X18+',
        ],
      ),
      _Field(
        'Manga',
        'Manga',
        kind: _Kind.choice,
        choices: ['Unknown', 'No', 'Yes', 'YesAndRightToLeft'],
      ),
      _Field(
        'BlackAndWhite',
        'Black and white',
        kind: _Kind.choice,
        choices: ['Unknown', 'No', 'Yes'],
      ),
      _Field('Web', 'Web link', wide: true),
      _Field('GTIN', 'Barcode (GTIN)'),
      _Field('ScanInformation', 'Scan information'),
      _Field('Notes', 'Notes', kind: _Kind.multiline, wide: true),
    ],
  ),
];

/// Edits one comic's ComicInfo.xml and saves it into the file.
class ComicInfoEditor extends ConsumerStatefulWidget {
  const ComicInfoEditor({super.key, required this.comic, this.lookUp = false});

  final LibraryComic comic;

  /// Start by looking the comic's details up.
  final bool lookUp;

  @override
  ConsumerState<ComicInfoEditor> createState() => _ComicInfoEditorState();
}

class _ComicInfoEditorState extends ConsumerState<ComicInfoEditor> {
  ComicInfoDocument? _doc;
  Object? _loadError;
  final _controllers = <String, TextEditingController>{};
  final _original = <String, String>{};
  bool _saving = false;

  LibraryComic get _comic => widget.comic;
  Iterable<_Field> get _fields => _sections.expand((s) => s.$2);

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final source = await openSource(_comic.location);
      final String? xml;
      try {
        xml = await source.readComicInfo();
      } finally {
        await source.close();
      }
      final doc = ComicInfoDocument.parse(xml);
      for (final f in _fields) {
        final value = doc[f.name] ?? '';
        _original[f.name] = value;
        _controllers[f.name] = TextEditingController(text: value)
          ..addListener(() => setState(() {}));
      }
      if (mounted) setState(() => _doc = doc);
      if (mounted && widget.lookUp) unawaited(_lookUp());
    } on Object catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  bool get _dirty =>
      _doc != null &&
      _fields.any(
        (f) => _controllers[f.name]!.text.trim() != _original[f.name]!.trim(),
      );

  bool get _valid =>
      _fields.every((f) => f.validate(_controllers[f.name]!.text) == null);

  /// Fills empty Series, Number and Year from the folder and file names.
  /// Searches the lookup services and fills the form with the chosen
  /// issue's details, for the user to check and save.
  Future<void> _lookUp() async {
    final doc = _doc;
    if (doc == null) return;
    final guess = _comic.nameGuess;
    String? value(String field) {
      final v = _controllers[field]!.text.trim();
      return v.isEmpty ? null : v;
    }

    // Apply to a copy holding the form's current values, then show it.
    final copy = ComicInfoDocument.parse(doc.toXmlString());
    for (final f in _fields) {
      copy[f.name] = _controllers[f.name]!.text;
    }
    final source = await chooseIssue(
      context,
      ref,
      doc: copy,
      series: value('Series') ?? guess.series ?? '',
      number: value('Number') ?? guess.number ?? '',
      year: int.tryParse(value('Year') ?? '') ?? guess.year,
      publisher: value('Publisher'),
    );
    if (source == null || !mounted) return;
    for (final f in _fields) {
      _controllers[f.name]!.text = copy[f.name] ?? '';
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Filled from $source: check, then save')),
    );
  }

  void _fillFromNames() {
    final guess = _comic.nameGuess;
    void fill(String field, Object? value) {
      final c = _controllers[field]!;
      if (c.text.trim().isEmpty && value != null) c.text = '$value';
    }

    fill('Series', guess.series);
    fill('Number', guess.number);
    fill('Year', guess.year);
  }

  Future<void> _save() async {
    final doc = _doc;
    if (doc == null || !_dirty || !_valid || _saving) return;
    for (final f in _fields) {
      doc[f.name] = _controllers[f.name]!.text;
    }
    final xml = doc.toXmlString();
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await writeComicInfoToCbz(_comic.location, xml);
    } on Object catch (e) {
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text('$e')));
      return;
    }
    // Show the new details right away: the opened book's stored metadata,
    // and the library (the scan notices the file changed).
    final info = ComicInfo.parse(xml);
    final bookId = _comic.entry.bookId;
    if (info != null && bookId != null) {
      await ref.read(databaseProvider).saveMetadata(bookId, metadataFrom(info));
    }
    final moved = await keepOrganized(ref, _comic, doc) != _comic.location;
    unawaited(ref.read(libraryScanProvider.notifier).scan());
    messenger.showSnackBar(
      SnackBar(content: Text(moved ? 'Saved and filed' : 'Saved')),
    );
    navigator.pop(true);
  }

  Future<void> _close() async {
    if (_dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard changes?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep editing'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if (discard != true) return;
    }
    if (mounted) Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final doc = _doc;
    final canSave = doc != null && _dirty && _valid && !_saving;
    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_close());
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyS, control: true): _save,
          const SingleActivator(LogicalKeyboardKey.escape): _close,
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close),
                onPressed: _close,
              ),
              title: Text('Edit ${_comic.series} ${_comic.issueLabel}'),
              actions: [
                TextButton.icon(
                  onPressed: doc == null || _saving ? null : _lookUp,
                  icon: const Icon(Icons.travel_explore),
                  label: const Text('Look up info'),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: FilledButton.icon(
                    onPressed: canSave ? _save : null,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('Save'),
                  ),
                ),
              ],
            ),
            body: switch ((doc, _loadError)) {
              (_, final error?) => Center(
                child: Text('Couldn’t read this comic: $error'),
              ),
              (null, _) => const Center(child: CircularProgressIndicator()),
              _ => _form(context),
            },
          ),
        ),
      ),
    );
  }

  Widget _form(BuildContext context) {
    final theme = Theme.of(context);
    final guess = _comic.nameGuess;
    final hasGuess = [
      guess.series,
      guess.number,
      guess.year,
    ].any((v) => v != null);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.clamp(0, 960).toDouble() - 48;
        final columns = width >= 640 ? 2 : 1;
        final fieldWidth = (width - (columns - 1) * 16) / columns;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
          child: Center(
            child: SizedBox(
              width: width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 96,
                        child: AspectRatio(
                          aspectRatio: 2 / 3,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LibraryCover(comic: _comic),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SelectableText(
                              _comic.entry.fileName,
                              style: theme.textTheme.titleMedium,
                            ),
                            if (_comic.entry.folder.isNotEmpty)
                              Text(
                                _comic.entry.folder,
                                style: theme.textTheme.bodySmall,
                              ),
                            const SizedBox(height: 8),
                            Text(
                              'Saved as ComicInfo.xml inside the file. '
                              'Fields you clear are removed; anything not '
                              'shown here is kept.',
                              style: theme.textTheme.bodySmall,
                            ),
                            if (hasGuess) ...[
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: _fillFromNames,
                                icon: const Icon(Icons.auto_fix_high, size: 18),
                                label: const Text(
                                  'Fill empty fields from file name',
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  for (final (title, fields) in _sections) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 28, bottom: 12),
                      child: Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        for (final f in fields)
                          SizedBox(
                            width: f.wide ? width : fieldWidth,
                            child: _input(f),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _input(_Field f) {
    final c = _controllers[f.name]!;
    if (f.kind == _Kind.choice) {
      // Values outside the list (other tools' spellings) are kept as-is.
      final values = {'', ...f.choices.where((v) => v != 'Unknown'), c.text};
      return DropdownButtonFormField<String>(
        initialValue: c.text,
        decoration: InputDecoration(
          labelText: f.label,
          border: const OutlineInputBorder(),
        ),
        items: [
          for (final v in values)
            DropdownMenuItem(value: v, child: Text(v.isEmpty ? 'Not set' : v)),
        ],
        onChanged: (v) => c.text = v ?? '',
      );
    }
    final multiline = f.kind == _Kind.multiline;
    return TextField(
      controller: c,
      minLines: multiline ? 3 : 1,
      maxLines: multiline ? 10 : 1,
      keyboardType: f.kind == _Kind.integer
          ? TextInputType.number
          : multiline
          ? TextInputType.multiline
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: f.label,
        helperText: f.hint,
        errorText: f.validate(c.text),
        border: const OutlineInputBorder(),
      ),
    );
  }
}

/// Opens the editor for [comic]; true if it saved.
Future<bool> editComicInfo(
  BuildContext context,
  LibraryComic comic, {
  bool lookUp = false,
}) async =>
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ComicInfoEditor(comic: comic, lookUp: lookUp),
      ),
    ) ??
    false;

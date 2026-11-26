import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../app/providers.dart';
import '../core/metadata/comic_info.dart';
import '../core/metadata/comic_info_document.dart';
import '../core/metadata/comic_info_writer.dart';
import '../core/metadata/metron.dart';
import '../core/metadata/metron_cache.dart';
import '../core/sources/open_source.dart';
import '../data/book_extensions.dart';
import '../data/database.dart';
import 'comic_info_editor.dart';
import 'convert_comics.dart';
import 'library_model.dart';
import 'library_scanner.dart';

const metronTokenKey = 'metron.token';

/// The user's Metron API token, or null if not set.
final metronTokenProvider = FutureProvider<String?>((ref) async {
  final t = await ref.watch(databaseProvider).setting(metronTokenKey);
  return t == null || t.trim().isEmpty ? null : t.trim();
});

/// Metron answers kept between runs. In memory unless overridden (main
/// gives it a file in the app's cache folder).
final metronCacheProvider = Provider<MetronCache>((ref) => MetronCache());

/// One client per token, so its pacing and cache are shared by every lookup.
final metronClientProvider = Provider<MetronClient?>((ref) {
  final token = ref.watch(metronTokenProvider).value;
  return token == null
      ? null
      : MetronClient(token, cache: ref.watch(metronCacheProvider));
});

/// What to search Metron for, from ComicInfo first, then the names.
({String? series, String? number, int? year}) lookupTerms(
  LibraryComic comic,
  ComicInfoDocument doc,
) {
  final guess = comic.nameGuess;
  return (
    series: doc['Series'] ?? guess.series,
    number: doc['Number'] ?? guess.number,
    year: int.tryParse(doc['Year'] ?? '') ?? guess.year,
  );
}

/// A comic the batch couldn't match on its own.
typedef Unmatched = ({LibraryComic comic, String reason});

typedef TagResult = ({
  int tagged,
  int failed,
  int skipped,
  List<Unmatched> unmatched,
  List<String> errors,
});

/// Looks each comic up on Metron and saves what it finds into the file.
/// Comics already carrying a Metron issue ID use it; others are matched by
/// series, number and year ([chooseMatch]), and left for the user when that
/// isn't certain. CBR/CB7/CBT are converted to CBZ first; PDFs are skipped.
Future<TagResult> tagComics(
  AppDatabase db,
  MetronClient metron,
  List<LibraryComic> comics, {
  void Function(int done)? onProgress,
  bool Function()? shouldStop,
  Future<bool> Function(String path) trash = moveToTrash,
}) async {
  var tagged = 0, failed = 0, skipped = 0;
  final unmatched = <Unmatched>[];
  final errors = <String>[];
  for (final (i, original) in comics.indexed) {
    if (shouldStop?.call() ?? false) break;
    var comic = original;
    try {
      if (isConvertibleComic(comic)) {
        final c = await convertComics(db, [comic], trash: trash);
        if (c.failed > 0) throw Exception(c.errors.first);
        final cbz = p.setExtension(comic.location, '.cbz');
        comic = LibraryComic(
          comic.entry.copyWith(location: cbz, fileName: p.basename(cbz)),
          comic.progress,
        );
      }
      if (!isEditableComic(comic.location)) {
        skipped++;
        continue;
      }
      final doc = ComicInfoDocument.parse(await _readComicInfo(comic));
      var id = metronIdFrom(doc);
      if (id == null) {
        final t = lookupTerms(comic, doc);
        if (t.series == null || t.number == null) {
          unmatched.add((
            comic: comic,
            reason: 'No series or number to search',
          ));
          continue;
        }
        final found = await metron.findIssue(
          series: t.series!,
          number: t.number,
          year: t.year,
        );
        final match = found.match;
        if (match == null || !found.sure) {
          unmatched.add((
            comic: comic,
            reason: match != null
                ? 'Likely ${match.displayName}: please confirm'
                : found.results.isEmpty
                ? 'Not found on Metron'
                : '${found.results.length} possible matches',
          ));
          continue;
        }
        id = match.id;
      }
      applyMetronIssue(doc, await metron.issue(id));
      await saveComicInfo(db, comic, doc);
      tagged++;
    } on Object catch (e) {
      failed++;
      errors.add('${comic.entry.fileName}: $e');
      // Without a working token nothing else will work either.
      if (e is MetronException && e.message.contains('token')) break;
    } finally {
      onProgress?.call(i + 1);
    }
  }
  return (
    tagged: tagged,
    failed: failed,
    skipped: skipped,
    unmatched: unmatched,
    errors: errors,
  );
}

Future<String?> _readComicInfo(LibraryComic comic) async {
  final source = await openSource(comic.location);
  try {
    return await source.readComicInfo();
  } finally {
    await source.close();
  }
}

/// Writes [doc] into [comic]'s CBZ and updates the stored details.
Future<void> saveComicInfo(
  AppDatabase db,
  LibraryComic comic,
  ComicInfoDocument doc,
) async {
  final xml = doc.toXmlString();
  await writeComicInfoToCbz(comic.location, xml);
  final info = ComicInfo.parse(xml);
  final bookId = comic.entry.bookId;
  if (info != null && bookId != null) {
    await db.saveMetadata(bookId, metadataFrom(info));
  }
}

String describeTagResult(TagResult r) {
  String n(int count) => count == 1 ? '1 comic' : '$count comics';
  return [
    'Tagged ${n(r.tagged)}',
    if (r.unmatched.isNotEmpty) '${r.unmatched.length} to choose',
    if (r.skipped > 0) '${r.skipped} skipped (PDF)',
    if (r.failed > 0) '${r.failed} failed',
  ].join(' · ');
}

/// Asks for the token if there's none; true if there is one now.
Future<bool> ensureMetronToken(BuildContext context, WidgetRef ref) async {
  if (ref.read(metronClientProvider) != null) return true;
  await editMetronToken(context, ref);
  await ref.read(metronTokenProvider.future);
  return ref.read(metronClientProvider) != null;
}

/// Lets the user enter or change their Metron API token.
Future<void> editMetronToken(BuildContext context, WidgetRef ref) async {
  final db = ref.read(databaseProvider);
  final current = await db.setting(metronTokenKey) ?? '';
  if (!context.mounted) return;
  final token = await showDialog<String>(
    context: context,
    builder: (context) => _TokenDialog(current: current),
  );
  if (token == null) return;
  await db.setSetting(metronTokenKey, token.trim());
  ref.invalidate(metronTokenProvider);
}

class _TokenDialog extends StatefulWidget {
  const _TokenDialog({required this.current});
  final String current;

  @override
  State<_TokenDialog> createState() => _TokenDialogState();
}

class _TokenDialogState extends State<_TokenDialog> {
  late final _controller = TextEditingController(text: widget.current);
  bool _show = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Metron API token'),
    content: SizedBox(
      width: 440,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Panelist looks up comic details on Metron (metron.cloud), a '
            'free comic database. Sign in there, create an API token on your '
            'account page, and paste it here. It’s kept on this computer '
            'and only sent to Metron.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            obscureText: !_show,
            decoration: InputDecoration(
              labelText: 'API token',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: _show ? 'Hide' : 'Show',
                icon: Icon(_show ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _show = !_show),
              ),
            ),
            onSubmitted: (v) => Navigator.of(context).pop(v),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(_controller.text),
        child: const Text('Save'),
      ),
    ],
  );
}

/// Looks [comics] up on Metron with progress, then lists the ones that
/// need a choice.
Future<void> tagWithProgress(
  BuildContext context,
  WidgetRef ref,
  List<LibraryComic> comics,
) async {
  if (!await ensureMetronToken(context, ref) || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  final result = await showDialog<TagResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _TagDialog(comics: comics),
  );
  if (result == null) return;
  unawaited(ref.read(libraryScanProvider.notifier).scan());
  if (!context.mounted) return;
  if (result.unmatched.isEmpty && result.errors.isEmpty) {
    messenger.showSnackBar(SnackBar(content: Text(describeTagResult(result))));
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (_) => _TagReport(result: result, parent: context),
  );
}

class _TagDialog extends ConsumerStatefulWidget {
  const _TagDialog({required this.comics});
  final List<LibraryComic> comics;

  @override
  ConsumerState<_TagDialog> createState() => _TagDialogState();
}

class _TagDialogState extends ConsumerState<_TagDialog> {
  int? _done;
  bool _stopping = false;

  Future<void> _run() async {
    final metron = ref.read(metronClientProvider);
    if (metron == null) return;
    setState(() => _done = 0);
    final result = await tagComics(
      ref.read(databaseProvider),
      metron,
      widget.comics,
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
    final total = widget.comics.length;
    final done = _done;
    final convert = widget.comics.where(isConvertibleComic).length;
    final minutes = (total * 2 * 3.1 / 60).ceil();
    return AlertDialog(
      title: Text(
        total == 1 ? 'Look up on Metron?' : 'Look up $total comics on Metron?',
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Finds each comic by series, number and year (or the Metron ID '
              'it was tagged with) and saves the details into the file. '
              'Comics without one clear match are listed for you to choose.'
              '${convert > 0 ? ' $convert CBR/CB7/CBT ${convert == 1 ? 'file is' : 'files are'} converted to CBZ first.' : ''}'
              '${minutes > 1 ? ' Metron limits how fast it can be asked, so this takes up to about $minutes minutes.' : ''}',
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
          onPressed: done == null ? _run : null,
          child: const Text('Look up'),
        ),
      ],
    );
  }
}

class _TagReport extends StatelessWidget {
  const _TagReport({required this.result, required this.parent});
  final TagResult result;

  /// For opening the editor after this dialog closes.
  final BuildContext parent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(describeTagResult(result)),
      content: SizedBox(
        width: 520,
        child: ListView(
          shrinkWrap: true,
          children: [
            if (result.unmatched.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Choose the right issue for these:',
                  style: theme.textTheme.titleSmall,
                ),
              ),
            for (final u in result.unmatched)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(u.comic.entry.fileName),
                subtitle: Text(u.reason),
                trailing: TextButton(
                  onPressed: () =>
                      unawaited(editComicInfo(parent, u.comic, lookUp: true)),
                  child: const Text('Choose…'),
                ),
              ),
            if (result.errors.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: Text('Failed:', style: theme.textTheme.titleSmall),
              ),
              for (final e in result.errors)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(e, style: theme.textTheme.bodySmall),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

/// Searches Metron for one comic and returns the chosen issue's details.
Future<Map<String, Object?>?> chooseMetronIssue(
  BuildContext context,
  WidgetRef ref, {
  required String series,
  required String number,
  required int? year,
}) async {
  if (!await ensureMetronToken(context, ref) || !context.mounted) return null;
  return showDialog<Map<String, Object?>>(
    context: context,
    builder: (_) => _ChooseDialog(series: series, number: number, year: year),
  );
}

class _ChooseDialog extends ConsumerStatefulWidget {
  const _ChooseDialog({
    required this.series,
    required this.number,
    required this.year,
  });
  final String series;
  final String number;
  final int? year;

  @override
  ConsumerState<_ChooseDialog> createState() => _ChooseDialogState();
}

class _ChooseDialogState extends ConsumerState<_ChooseDialog> {
  late final _series = TextEditingController(text: widget.series);
  late final _number = TextEditingController(text: widget.number);
  List<MetronIssueSummary>? _results;
  MetronIssueSummary? _best;
  bool _sure = false;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.series.isNotEmpty) unawaited(_search());
  }

  @override
  void dispose() {
    _series.dispose();
    _number.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final metron = ref.read(metronClientProvider);
    if (metron == null || _series.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final number = _number.text.trim();
      final found = await metron.findIssue(
        series: _series.text.trim(),
        number: number.isEmpty ? null : number,
        year: widget.year,
      );
      if (mounted) {
        setState(() {
          _results = found.results; // best first
          _best = found.match;
          _sure = found.sure;
        });
      }
    } on MetronException catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pick(MetronIssueSummary r) async {
    final metron = ref.read(metronClientProvider);
    if (metron == null) return;
    setState(() => _busy = true);
    try {
      final issue = await metron.issue(r.id);
      // Later issues of this series are found by its ID.
      metron
        ..rememberSeries(widget.series, r)
        ..rememberSeries(_series.text.trim(), r);
      if (mounted) Navigator.of(context).pop(issue);
    } on MetronException catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final results = _results;
    String date(DateTime? d) =>
        d == null ? '' : '${d.year}-${d.month.toString().padLeft(2, '0')}';
    return AlertDialog(
      title: const Text('Look up on Metron'),
      content: SizedBox(
        width: 560,
        height: 480,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _series,
                    decoration: const InputDecoration(
                      labelText: 'Series',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _number,
                    decoration: const InputDecoration(
                      labelText: 'Number',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.filledTonal(
                  tooltip: 'Search',
                  onPressed: _busy ? null : _search,
                  icon: const Icon(Icons.search),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_busy) const LinearProgressIndicator(),
            if (_error case final e?)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  e,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            if (results != null && results.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Nothing found. Try a shorter series name, or leave the '
                  'number empty.',
                ),
              ),
            if (results != null)
              Expanded(
                child: ListView(
                  children: [
                    for (final r in results)
                      ListTile(
                        leading: SizedBox(
                          width: 40,
                          height: 60,
                          child: r.image == null
                              ? const Icon(Icons.image_not_supported_outlined)
                              : Image.network(
                                  r.image!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const Icon(
                                    Icons.image_not_supported_outlined,
                                  ),
                                ),
                        ),
                        title: Text(
                          r.displayName.isEmpty
                              ? '${r.seriesName} #${r.number}'
                              : r.displayName,
                        ),
                        subtitle: Text(
                          [
                            if (r.seriesYearBegan != null)
                              'Series from ${r.seriesYearBegan}',
                            if (r.coverDate != null)
                              'cover ${date(r.coverDate)}',
                          ].join(' · '),
                        ),
                        trailing: r == _best
                            ? Chip(
                                label: Text(
                                  _sure ? 'Best match' : 'Likely match',
                                ),
                              )
                            : null,
                        onTap: _busy ? null : () => _pick(r),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

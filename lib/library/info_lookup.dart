import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../app/providers.dart';
import '../core/metadata/comic_info.dart';
import '../core/metadata/comic_info_document.dart';
import '../core/metadata/comic_info_writer.dart';
import '../core/metadata/lookup/api_client.dart';
import '../core/metadata/lookup/comicvine_provider.dart';
import '../core/metadata/lookup/lookup_cache.dart';
import '../core/metadata/lookup/lookup_provider.dart';
import '../core/metadata/lookup/metron_provider.dart';
import '../core/sources/open_source.dart';
import '../data/book_extensions.dart';
import '../data/database.dart';
import 'comic_info_editor.dart';
import 'convert_comics.dart';
import 'library_model.dart';
import 'library_scanner.dart';
import 'publisher_aliases.dart';

/// A comic database Panelist can look details up in. Adding one: write a
/// [LookupProvider] and list it in [lookupServices].
class LookupService {
  const LookupService({
    required this.id,
    required this.name,
    required this.keyName,
    required this.settingKey,
    required this.help,
    required this.create,
  });

  final String id;
  final String name;

  /// What the service calls its key ("API token").
  final String keyName;

  /// Where the key is stored in the settings table.
  final String settingKey;

  /// How to get a key.
  final String help;
  final LookupProvider Function(String key, LookupCache cache) create;
}

final lookupServices = [
  LookupService(
    id: 'metron',
    name: 'Metron',
    keyName: 'API token',
    settingKey: 'metron.token',
    help:
        'Metron (metron.cloud) is a free community comic database. Sign in '
        'there, create an API token on your account page, and paste it here.',
    create: (key, cache) => MetronProvider(key, cache: cache),
  ),
  LookupService(
    id: 'comicvine',
    name: 'Comic Vine',
    keyName: 'API key',
    settingKey: 'comicvine.key',
    help:
        'Comic Vine (comicvine.gamespot.com) is a large comic database. Sign '
        'in there, open comicvine.gamespot.com/api to see your API key, and '
        'paste it here.',
    create: (key, cache) => ComicVineProvider(key, cache: cache),
  ),
];

const preferredLookupKey = 'lookup.preferred';

/// The keys the user has entered, by service ID (only those set).
final lookupKeysProvider = FutureProvider<Map<String, String>>((ref) async {
  final db = ref.watch(databaseProvider);
  final out = <String, String>{};
  for (final s in lookupServices) {
    final k = (await db.setting(s.settingKey))?.trim();
    if (k != null && k.isNotEmpty) out[s.id] = k;
  }
  return out;
});

/// The service tried first.
final preferredLookupProvider = FutureProvider<String>((ref) async {
  final id = await ref.watch(databaseProvider).setting(preferredLookupKey);
  return lookupServices.any((s) => s.id == id) ? id! : lookupServices.first.id;
});

/// Lookup answers kept between runs. In memory unless overridden (main
/// gives it a file in the app's cache folder).
final lookupCacheProvider = Provider<LookupCache>((ref) => LookupCache());

/// The services with a key, preferred first. One instance per key, so its
/// pacing and cache are shared by every lookup.
final lookupProvidersProvider = Provider<List<LookupProvider>>((ref) {
  final keys = ref.watch(lookupKeysProvider).value ?? const {};
  final first = ref.watch(preferredLookupProvider).value;
  final cache = ref.watch(lookupCacheProvider);
  final services = [
    ...lookupServices.where((s) => s.id == first),
    ...lookupServices.where((s) => s.id != first),
  ];
  return [
    for (final s in services)
      if (keys[s.id] case final key?) s.create(key, cache),
  ];
});

/// "Metron or Comic Vine".
String providerNames(List<LookupProvider> providers) {
  final names = [for (final p in providers) p.name];
  return names.length < 2
      ? names.join()
      : '${names.take(names.length - 1).join(', ')} or ${names.last}';
}

/// What to search for, from ComicInfo first, then the names.
({String? series, String? number, int? year, String? publisher}) lookupTerms(
  LibraryComic comic,
  ComicInfoDocument doc,
) {
  final guess = comic.nameGuess;
  return (
    series: doc['Series'] ?? guess.series,
    number: doc['Number'] ?? guess.number,
    year: int.tryParse(doc['Year'] ?? '') ?? guess.year,
    publisher: doc['Publisher'],
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

/// Looks each comic up and saves what it finds into the file. [providers]
/// are tried in order: a comic already tagged by one of them uses that ID;
/// otherwise each is searched until one has a sure match ([chooseMatch]).
/// Comics no provider is sure of are left for the user. A provider that
/// refuses its key or hits its limit is skipped for the rest of the run.
/// CBR/CB7/CBT are converted to CBZ first; PDFs are skipped.
Future<TagResult> tagComics(
  AppDatabase db,
  List<LookupProvider> providers,
  List<LibraryComic> comics, {
  void Function(int done)? onProgress,
  bool Function()? shouldStop,
  Future<bool> Function(String path) trash = moveToTrash,
  PublisherAliases aliases = const PublisherAliases(),
}) async {
  var tagged = 0, failed = 0, skipped = 0;
  final unmatched = <Unmatched>[];
  final errors = <String>[];
  final usable = [...providers];
  for (final (i, original) in comics.indexed) {
    if (shouldStop?.call() ?? false) break;
    if (usable.isEmpty) break;
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
      final t = lookupTerms(comic, doc);
      String? reason;
      Object? lastError;
      var done = false;
      for (final provider in [...usable]) {
        try {
          var id = provider.knownId(doc);
          if (id == null) {
            if (t.series == null || t.number == null) continue;
            final found = await provider.findIssue(
              series: t.series!,
              number: t.number,
              year: t.year,
              publisher: t.publisher,
            );
            final match = found.match;
            if (match == null || !found.sure) {
              // The first provider's near miss is the most useful hint.
              reason ??= match != null
                  ? 'Likely ${match.label} on ${provider.name}: please '
                        'confirm'
                  : found.results.isEmpty
                  ? null
                  : '${found.results.length} possible matches on '
                        '${provider.name}';
              continue;
            }
            id = match.id;
          }
          await provider.apply(doc, id);
          doc['Publisher'] = aliases.apply(doc['Publisher']);
          await saveComicInfo(db, comic, doc);
          tagged++;
          done = true;
          break;
        } on LookupException catch (e) {
          lastError = e;
          if (e.stopsProvider) {
            usable.remove(provider);
            errors.add('${provider.name}: $e');
          }
        }
      }
      if (done) continue;
      if (t.series == null || t.number == null) {
        unmatched.add((comic: comic, reason: 'No series or number to search'));
      } else if (reason != null) {
        unmatched.add((comic: comic, reason: reason));
      } else if (lastError != null) {
        failed++;
        errors.add('${comic.entry.fileName}: $lastError');
      } else {
        unmatched.add((
          comic: comic,
          reason: 'Not found on ${providerNames(providers)}',
        ));
      }
    } on Object catch (e) {
      failed++;
      errors.add('${comic.entry.fileName}: $e');
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

/// Asks for a key if there's none; true if there is one now.
Future<bool> ensureLookupKey(BuildContext context, WidgetRef ref) async {
  // The saved keys load from the database: wait for them, or a key that is
  // set looks missing.
  await ref.read(lookupKeysProvider.future);
  await ref.read(preferredLookupProvider.future);
  if (ref.read(lookupProvidersProvider).isNotEmpty) return true;
  if (!context.mounted) return false;
  await editLookupKey(context, ref, lookupServices.first);
  await ref.read(lookupKeysProvider.future);
  return ref.read(lookupProvidersProvider).isNotEmpty;
}

/// Lets the user enter or change [service]'s key.
Future<void> editLookupKey(
  BuildContext context,
  WidgetRef ref,
  LookupService service,
) async {
  final db = ref.read(databaseProvider);
  final current = await db.setting(service.settingKey) ?? '';
  if (!context.mounted) return;
  final key = await showDialog<String>(
    context: context,
    builder: (context) => _KeyDialog(service: service, current: current),
  );
  if (key == null) return;
  await db.setSetting(service.settingKey, key.trim());
  ref.invalidate(lookupKeysProvider);
}

Future<void> setPreferredLookup(WidgetRef ref, String id) async {
  await ref.read(databaseProvider).setSetting(preferredLookupKey, id);
  ref.invalidate(preferredLookupProvider);
}

class _KeyDialog extends StatefulWidget {
  const _KeyDialog({required this.service, required this.current});
  final LookupService service;
  final String current;

  @override
  State<_KeyDialog> createState() => _KeyDialogState();
}

class _KeyDialogState extends State<_KeyDialog> {
  late final _controller = TextEditingController(text: widget.current);
  bool _show = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.service;
    return AlertDialog(
      title: Text('${s.name} ${s.keyName}'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${s.help} It’s kept on this computer and only sent to '
              '${s.name}. Leave it empty to stop using ${s.name}.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              obscureText: !_show,
              decoration: InputDecoration(
                labelText: s.keyName,
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
}

/// Settings rows: one key per service, and which is tried first.
class LookupSettings extends ConsumerWidget {
  const LookupSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keys = ref.watch(lookupKeysProvider).value ?? const {};
    final preferred = ref.watch(preferredLookupProvider).value;
    return Column(
      children: [
        for (final s in lookupServices)
          ListTile(
            leading: const Icon(Icons.key_outlined),
            title: Text('${s.name} ${s.keyName}'),
            subtitle: Text(
              keys.containsKey(s.id)
                  ? 'Set'
                  : 'Not set: needed to look up details on ${s.name}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => editLookupKey(context, ref, s),
          ),
        ListTile(
          leading: const Icon(Icons.travel_explore),
          title: const Text('Look up first on'),
          subtitle: const Text(
            'The others are tried when it doesn’t find a comic',
          ),
          trailing: DropdownButton<String>(
            value: preferred,
            underline: const SizedBox(),
            items: [
              for (final s in lookupServices)
                DropdownMenuItem(value: s.id, child: Text(s.name)),
            ],
            onChanged: (id) {
              if (id != null) unawaited(setPreferredLookup(ref, id));
            },
          ),
        ),
      ],
    );
  }
}

/// Looks [comics] up with progress, then lists the ones that need a choice.
Future<void> tagWithProgress(
  BuildContext context,
  WidgetRef ref,
  List<LibraryComic> comics,
) async {
  if (!await ensureLookupKey(context, ref) || !context.mounted) return;
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
    final providers = ref.read(lookupProvidersProvider);
    if (providers.isEmpty) return;
    setState(() => _done = 0);
    final result = await tagComics(
      ref.read(databaseProvider),
      providers,
      widget.comics,
      onProgress: (n) {
        if (mounted) setState(() => _done = n);
      },
      shouldStop: () => _stopping,
      aliases:
          ref.read(publisherAliasesProvider).value ?? const PublisherAliases(),
    );
    if (mounted) Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final providers = ref.watch(lookupProvidersProvider);
    final total = widget.comics.length;
    final done = _done;
    final convert = widget.comics.where(isConvertibleComic).length;
    final spacing = providers.isEmpty
        ? 0
        : providers.first.requestSpacing.inMilliseconds / 1000;
    final minutes = (total * 2 * spacing / 60).ceil();
    final names = providerNames(providers);
    return AlertDialog(
      title: Text(total == 1 ? 'Look up info?' : 'Look up $total comics?'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Finds each comic on $names by series, number and year (or '
              'the ID it was tagged with) and saves the details into the '
              'file. ${providers.length > 1 ? '${providers.skip(1).map((p) => p.name).join(' and ')} is tried when ${providers.first.name} doesn’t find one. ' : ''}'
              'Comics without one clear match are listed for you to choose.'
              '${convert > 0 ? ' $convert CBR/CB7/CBT ${convert == 1 ? 'file is' : 'files are'} converted to CBZ first.' : ''}'
              '${minutes > 1 ? ' ${providers.first.name} limits how fast it can be asked, so this takes about $minutes minutes or more.' : ''}',
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

/// Searches for one comic and writes the issue the user picks into [doc].
/// Returns the provider's name, or null if nothing was picked.
Future<String?> chooseIssue(
  BuildContext context,
  WidgetRef ref, {
  required ComicInfoDocument doc,
  required String series,
  required String number,
  required int? year,
  String? publisher,
}) async {
  if (!await ensureLookupKey(context, ref) || !context.mounted) return null;
  return showDialog<String>(
    context: context,
    builder: (_) => _ChooseDialog(
      doc: doc,
      series: series,
      number: number,
      year: year,
      publisher: publisher,
    ),
  );
}

class _ChooseDialog extends ConsumerStatefulWidget {
  const _ChooseDialog({
    required this.doc,
    required this.series,
    required this.number,
    required this.year,
    required this.publisher,
  });
  final ComicInfoDocument doc;
  final String series;
  final String number;
  final int? year;
  final String? publisher;

  @override
  ConsumerState<_ChooseDialog> createState() => _ChooseDialogState();
}

class _ChooseDialogState extends ConsumerState<_ChooseDialog> {
  late final _series = TextEditingController(text: widget.series);
  late final _number = TextEditingController(text: widget.number);
  List<IssueCandidate>? _results;
  IssueCandidate? _best;
  bool _sure = false;
  final _errors = <String>[];
  bool _busy = false;
  late final List<LookupProvider> _providers = ref.read(
    lookupProvidersProvider,
  );

  /// Providers searched so far for the current terms.
  int _searched = 0;

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

  /// Searches the providers in order until one is sure; [more] continues
  /// with the next one instead of starting over.
  Future<void> _search({bool more = false}) async {
    if (_series.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      if (!more) {
        _searched = 0;
        _results = null;
        _best = null;
        _sure = false;
        _errors.clear();
      }
    });
    final number = _number.text.trim();
    final results = [...?_results];
    try {
      while (_searched < _providers.length) {
        final provider = _providers[_searched++];
        try {
          final found = await provider.findIssue(
            series: _series.text.trim(),
            number: number.isEmpty ? null : number,
            year: widget.year,
            publisher: widget.publisher,
          );
          results.addAll(found.results);
          if (_best == null || (!_sure && found.sure)) {
            _best = found.match ?? _best;
            _sure = found.sure;
          }
          if (mounted) setState(() => _results = [...results]);
          // Stop once something fits; the user can ask the next one.
          if (found.match != null || (more && found.results.isNotEmpty)) {
            break;
          }
        } on LookupException catch (e) {
          if (mounted) setState(() => _errors.add('${provider.name}: $e'));
        }
      }
      if (mounted) setState(() => _results = results);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pick(IssueCandidate r) async {
    setState(() => _busy = true);
    try {
      await r.provider.apply(widget.doc, r.id);
      final aliases = await ref.read(publisherAliasesProvider.future);
      widget.doc['Publisher'] = aliases.apply(widget.doc['Publisher']);
      // Later issues of this series are found by its ID.
      r.provider
        ..rememberSeries(widget.series, r)
        ..rememberSeries(_series.text.trim(), r);
      if (mounted) Navigator.of(context).pop(r.provider.name);
    } on LookupException catch (e) {
      if (mounted) {
        setState(() {
          _errors.add('${r.provider.name}: $e');
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final results = _results;
    final several = _providers.length > 1;
    final next = _searched < _providers.length ? _providers[_searched] : null;
    String date(DateTime? d) =>
        d == null ? '' : '${d.year}-${d.month.toString().padLeft(2, '0')}';
    return AlertDialog(
      title: const Text('Look up info'),
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
            for (final e in _errors)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  e,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            if (results != null && results.isEmpty && !_busy)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Nothing found on ${providerNames(_providers)}. Try a '
                  'shorter series name, or leave the number empty.',
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
                        title: Text(r.label),
                        subtitle: Text(
                          [
                            if (several) r.provider.name,
                            if (r.publisher != null) r.publisher!,
                            if (r.seriesYearBegan != null)
                              'series from ${r.seriesYearBegan}',
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
                    if (next != null && !_busy)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Center(
                          child: TextButton.icon(
                            onPressed: () => _search(more: true),
                            icon: const Icon(Icons.search),
                            label: Text('Search ${next.name} too'),
                          ),
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
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

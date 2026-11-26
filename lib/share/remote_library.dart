import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bonsoir/bonsoir.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../app/providers.dart';
import '../core/sources/open_source.dart';
import '../core/sources/page_source.dart';
import '../data/database.dart';
import '../library/library_model.dart';
import '../library/library_providers.dart';
import '../library/library_scanner.dart';
import 'remote_page_source.dart';
import 'share_client.dart';
import 'share_protocol.dart';

// --- Locations -----------------------------------------------------------

const _scheme = 'panelist';

/// Where a comic in a paired library lives: `panelist://<library>/<book>`.
String remoteLocation(int library, String bookId) =>
    '$_scheme://$library/$bookId';

({int library, String bookId})? parseRemoteLocation(String location) {
  if (!isRemoteLocation(location)) return null;
  final parts = location.substring(_scheme.length + 3).split('/');
  final library = parts.length == 2 ? int.tryParse(parts[0]) : null;
  return library == null ? null : (library: library, bookId: parts[1]);
}

/// Folders where this device keeps its own data for shared libraries.
/// Overridden in `main`.
final shareDirsProvider = Provider<({Directory cache, Directory downloads})>(
  (ref) => throw UnimplementedError('shareDirsProvider must be overridden'),
);

// --- Paired libraries ----------------------------------------------------

final remoteLibrariesProvider = StreamProvider<List<RemoteLibrary>>(
  (ref) => ref.watch(databaseProvider).watchRemoteLibraries(),
);

/// A [ShareClient] for each paired library, made again when its address or
/// token changes.
final shareClientProvider = Provider.family<ShareClient?, int>((ref, id) {
  // Only the address and token matter: a sync updating the row's times
  // mustn't replace the client (and cut off what it's fetching).
  final where = ref.watch(
    remoteLibrariesProvider.select((libs) {
      final lib = libs.value?.where((l) => l.id == id).firstOrNull;
      return lib == null ? null : (lib.address, lib.token);
    }),
  );
  if (where == null) return null;
  final client = ShareClient(where.$1, token: where.$2);
  ref.onDispose(client.close);
  return client;
});

/// The library shown: null for this device's own, or a paired library's ID.
final shownLibraryProvider = NotifierProvider<ShownLibrary, int?>(
  ShownLibrary.new,
);

class ShownLibrary extends Notifier<int?> {
  ShownLibrary([this._initial]);

  static const _key = 'library.shown';

  /// The library shown last (call before building the app); null if it
  /// was this device's or that library was removed since.
  static Future<int?> load(AppDatabase db) async {
    final saved = int.tryParse(await db.setting(_key) ?? '');
    if (saved == null) return null;
    final paired = await db.remoteLibraryList();
    return paired.any((l) => l.id == saved) ? saved : null;
  }

  final int? _initial;

  @override
  int? build() => _initial;

  void show(int? library) {
    state = library;
    unawaited(
      ref.read(databaseProvider).setSetting(_key, library?.toString() ?? ''),
    );
    if (library != null) {
      unawaited(ref.read(remoteComicsProvider(library).notifier).refresh());
    }
  }
}

// --- A paired library's comics -------------------------------------------

/// A paired library's comic list, kept on the device so it can be browsed
/// (and downloaded comics read) without the computer.
class RemoteComics {
  const RemoteComics({
    this.comics = const [],
    this.etag,
    this.loading = false,
    this.error,
    this.unpaired = false,
  });

  final List<RemoteComic> comics;
  final String? etag;
  final bool loading;

  /// Why the last refresh failed, if it did (the list is the last one).
  final String? error;
  final bool unpaired;

  RemoteComics copyWith({
    List<RemoteComic>? comics,
    String? etag,
    bool? loading,
    String? Function()? error,
    bool? unpaired,
  }) => RemoteComics(
    comics: comics ?? this.comics,
    etag: etag ?? this.etag,
    loading: loading ?? this.loading,
    error: error == null ? this.error : error(),
    unpaired: unpaired ?? this.unpaired,
  );
}

final remoteComicsProvider =
    NotifierProvider.family<RemoteComicsNotifier, RemoteComics, int>(
      RemoteComicsNotifier.new,
    );

class RemoteComicsNotifier extends Notifier<RemoteComics> {
  RemoteComicsNotifier(this.library);
  final int library;

  File get _cacheFile => File(
    p.join(ref.read(shareDirsProvider).cache.path, 'library-$library.json'),
  );

  @override
  RemoteComics build() {
    unawaited(_loadCache().then((_) => refresh()));
    return const RemoteComics(loading: true);
  }

  Future<void> _loadCache() async {
    try {
      final j = jsonDecode(await _cacheFile.readAsString()) as Map;
      if (!ref.mounted) return;
      state = state.copyWith(
        comics: [
          for (final c in j['comics'] as List)
            RemoteComic.fromJson(c as Map<String, Object?>),
        ],
        etag: j['etag'] as String?,
      );
    } on Object {
      // None yet.
    }
  }

  /// Fetches the list if it changed, then any covers not here yet.
  Future<void> refresh() async {
    // At start the paired libraries may still be loading.
    await ref.read(remoteLibrariesProvider.future);
    if (!ref.mounted) return;
    final client = ref.read(shareClientProvider(library));
    if (client == null) {
      state = state.copyWith(
        loading: false,
        error: () => 'This library isn’t added on this device any more',
      );
      return;
    }
    state = state.copyWith(loading: true);
    try {
      final fresh = await client.library(
        etag: state.comics.isEmpty ? null : state.etag,
      );
      if (!ref.mounted) return;
      if (fresh != null) {
        state = state.copyWith(comics: fresh.comics, etag: fresh.etag);
        await _cacheFile.parent.create(recursive: true);
        await _cacheFile.writeAsString(
          jsonEncode({
            'etag': fresh.etag,
            'comics': [for (final c in fresh.comics) c.toJson()],
          }),
        );
      }
      state = state.copyWith(loading: false, error: () => null);
      await ref.read(databaseProvider).nameUntitledBooks({
        for (final c in state.comics)
          c.id: p.basenameWithoutExtension(c.fileName),
      });
      unawaited(_fetchCovers(client));
    } on ShareException catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        loading: false,
        error: () => e.message,
        unpaired: e.unpaired,
      );
    } on Object catch (e) {
      // Never stuck on "Connecting…".
      if (!ref.mounted) return;
      state = state.copyWith(loading: false, error: () => 'Couldn’t load: $e');
    }
  }

  bool _fetchingCovers = false;

  Future<void> _fetchCovers(ShareClient client) async {
    if (_fetchingCovers) return;
    _fetchingCovers = true;
    try {
      await _fetchMissingCovers(client, state.comics);
    } finally {
      _fetchingCovers = false;
    }
  }

  Future<void> _fetchMissingCovers(
    ShareClient client,
    List<RemoteComic> comics,
  ) async {
    final dir = ref.read(coversDirProvider);
    await dir.create(recursive: true);
    if (!ref.mounted) return;
    var fetched = 0;
    for (final c in comics) {
      final f = File(p.join(dir.path, '${c.id}.png'));
      if (f.existsSync()) continue;
      try {
        await f.writeAsBytes(await client.cover(c.id));
        fetched++;
        // Show covers as they come, a batch at a time.
        if (fetched % 24 == 0 && ref.mounted) {
          PaintingBinding.instance.imageCache.clear();
          state = state.copyWith();
        }
      } on ShareException {
        // No cover there (or gone): the placeholder shows.
      }
      if (!ref.mounted) return;
    }
    if (fetched > 0 && ref.mounted) {
      PaintingBinding.instance.imageCache.clear();
      state = state.copyWith();
    }
  }
}

/// The library being shown, as roots and comics like this device's own (one
/// root named after the computer).
final shownRootsProvider = Provider<List<LibraryRoot>?>((ref) {
  final shown = ref.watch(shownLibraryProvider);
  if (shown == null) return ref.watch(libraryRootsProvider).value;
  final lib = ref
      .watch(remoteLibrariesProvider)
      .value
      ?.where((l) => l.id == shown)
      .firstOrNull;
  if (lib == null) return ref.watch(libraryRootsProvider).value;
  return [
    LibraryRoot(
      id: -lib.id,
      location: remoteLocation(lib.id, ''),
      name: lib.name,
    ),
  ];
});

final shownComicsProvider = Provider<List<LibraryComic>>((ref) {
  final shown = ref.watch(shownLibraryProvider);
  final lib = shown == null
      ? null
      : ref
            .watch(remoteLibrariesProvider)
            .value
            ?.where((l) => l.id == shown)
            .firstOrNull;
  if (lib == null) return ref.watch(libraryComicsProvider);
  final remote = ref.watch(remoteComicsProvider(lib.id));
  final progress = ref.watch(bookProgressProvider).value ?? const {};
  return [
    for (final c in remote.comics)
      LibraryComic(
        LibraryEntry(
          location: remoteLocation(lib.id, c.id),
          rootId: -lib.id,
          folder: c.folder,
          fileName: c.fileName,
          size: c.size,
          modified: 0,
          bookId: c.id,
          pageCount: c.pageCount,
          series: c.series,
          number: c.number,
          volume: c.volume,
          year: c.year,
          publisher: c.publisher,
          title: c.title,
        ),
        progress[c.id],
      ),
  ];
});

// --- Downloads -----------------------------------------------------------

/// Comics downloaded from shared libraries: book ID → file. Each lives at
/// `downloads/<book ID>/<file name>`.
final downloadsProvider = NotifierProvider<Downloads, Map<String, File>>(
  Downloads.new,
);

class Downloads extends Notifier<Map<String, File>> {
  Directory get _dir => ref.read(shareDirsProvider).downloads;

  @override
  Map<String, File> build() {
    final found = <String, File>{};
    try {
      for (final d in _dir.listSync().whereType<Directory>()) {
        final file = d
            .listSync()
            .whereType<File>()
            .where((f) => !f.path.endsWith('.part'))
            .firstOrNull;
        if (file != null) found[p.basename(d.path)] = file;
      }
    } on FileSystemException {
      // None yet.
    }
    return found;
  }

  /// Downloads [comic] from [library].
  Future<File> download(
    int library,
    RemoteComic comic, {
    void Function(int done, int total)? onProgress,
    bool Function()? cancelled,
  }) async {
    final client = ref.read(shareClientProvider(library));
    if (client == null) throw const ShareException('Not paired');
    final to = File(p.join(_dir.path, comic.id, comic.fileName));
    await client.download(
      comic.id,
      to,
      onProgress: onProgress,
      cancelled: cancelled,
    );
    state = {...state, comic.id: to};
    return to;
  }

  Future<void> remove(String bookId) async {
    final dir = Directory(p.join(_dir.path, bookId));
    if (dir.existsSync()) await dir.delete(recursive: true);
    state = {...state}..remove(bookId);
  }
}

// --- Opening -------------------------------------------------------------

/// Opens `panelist://` locations: the downloaded copy when there is one,
/// otherwise pages over the network. Installed by [RemoteAccess].
Future<PageSource> _openRemote(Ref ref, String location) async {
  final where = parseRemoteLocation(location);
  if (where == null) throw UnsupportedSourceException('Not found: $location');
  if (ref.read(downloadsProvider)[where.bookId] case final file?
      when file.existsSync()) {
    return openSource(file.path);
  }
  final client = ref.read(shareClientProvider(where.library));
  if (client == null) {
    throw UnsupportedSourceException(
      'That library isn’t paired with this device any more',
    );
  }
  final comic = ref
      .read(remoteComicsProvider(where.library))
      .comics
      .where((c) => c.id == where.bookId)
      .firstOrNull;
  try {
    return await RemotePageSource.open(
      client,
      where.bookId,
      fileName: comic?.fileName ?? where.bookId,
    );
  } on ShareException catch (e) {
    throw UnsupportedSourceException(e.message);
  }
}

// --- Sync ----------------------------------------------------------------

/// Watched by the app: lets `panelist://` comics open, keeps reading
/// progress in step with paired libraries (a few seconds after it changes,
/// every few minutes, and when the app comes back), and looks for
/// libraries that moved to a new address.
final remoteAccessProvider = Provider<RemoteAccess>((ref) {
  final access = RemoteAccess(ref);
  ref.onDispose(access.dispose);
  return access;
});

class RemoteAccess {
  RemoteAccess(this._ref) {
    remoteOpener = (location) => _openRemote(_ref, location);
    _progress = _ref.read(databaseProvider).watchProgress().listen((_) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(seconds: 5), syncAll);
    });
    _periodic = Timer.periodic(const Duration(minutes: 5), (_) => syncAll());
    _lifecycle = AppLifecycleListener(onResume: () => syncAll(refresh: true));
    unawaited(
      Future<void>.delayed(const Duration(seconds: 2), () async {
        await syncAll();
        await findMovedLibraries();
      }),
    );
  }

  final Ref _ref;
  StreamSubscription<void>? _progress;
  Timer? _debounce;
  Timer? _periodic;
  AppLifecycleListener? _lifecycle;
  bool _syncing = false;

  void dispose() {
    remoteOpener = null;
    unawaited(_progress?.cancel());
    _debounce?.cancel();
    _periodic?.cancel();
    _lifecycle?.dispose();
  }

  /// Syncs progress with every paired library (and with [refresh], fetches
  /// the shown library's list again).
  Future<void> syncAll({bool refresh = false}) async {
    if (_syncing) return;
    _syncing = true;
    try {
      final db = _ref.read(databaseProvider);
      await _ref.read(remoteLibrariesProvider.future);
      for (final lib in await db.remoteLibraryList()) {
        final client = _ref.read(shareClientProvider(lib.id));
        if (client == null) continue;
        try {
          await syncProgress(
            db,
            lib,
            client,
            titleFor: (id) {
              final c = _ref
                  .read(remoteComicsProvider(lib.id))
                  .comics
                  .where((c) => c.id == id)
                  .firstOrNull;
              return c == null ? id : p.basenameWithoutExtension(c.fileName);
            },
          );
        } on ShareException catch (e) {
          debugPrint('Sync with ${lib.name}: $e');
        }
      }
      if (refresh) {
        if (_ref.read(shownLibraryProvider) case final shown?) {
          await _ref.read(remoteComicsProvider(shown).notifier).refresh();
        }
      }
    } finally {
      _syncing = false;
    }
  }

  /// Looks on the network for paired libraries that answer somewhere else
  /// now (a new IP address), for a few seconds.
  Future<void> findMovedLibraries() async {
    final db = _ref.read(databaseProvider);
    final paired = await db.remoteLibraryList();
    if (paired.isEmpty) return;
    final moved = <int>{};
    await for (final found in discoverLibraries(
      timeout: const Duration(seconds: 15),
    )) {
      for (final lib in paired) {
        if (lib.serverId == found.id &&
            lib.address != found.address &&
            moved.add(lib.id)) {
          await db.updateRemoteLibrary(
            lib.id,
            RemoteLibrariesCompanion(address: Value(found.address)),
          );
        }
      }
    }
    if (moved.isNotEmpty) unawaited(syncAll(refresh: true));
  }
}

/// One progress sync with [lib]: sends what changed here since the last
/// one, applies what changed there (the latest change wins).
Future<void> syncProgress(
  AppDatabase db,
  RemoteLibrary lib,
  ShareClient client, {
  required String Function(String bookId) titleFor,
}) async {
  final sentUntil = DateTime.now().toUtc();
  final mine = await db.progressChangedSince(lib.sentUntil);
  final theirs = await client.sync(
    ProgressSync(since: lib.syncedUntil, now: DateTime.now(), changes: mine),
  );
  // Their times shifted onto this clock.
  final skew = theirs.now == null
      ? Duration.zero
      : DateTime.now().difference(theirs.now!);
  for (final c in theirs.changes) {
    await db.applyProgress(
      c.shifted(skew),
      path: remoteLocation(lib.id, c.id),
      title: titleFor(c.id),
    );
  }
  await db.updateRemoteLibrary(
    lib.id,
    RemoteLibrariesCompanion(
      syncedUntil: Value(theirs.since),
      sentUntil: Value(sentUntil),
    ),
  );
}

// --- Discovery -----------------------------------------------------------

/// A shared library found on the network.
typedef FoundLibrary = ({String id, String name, String address});

/// Libraries announcing themselves on the network, as they're found (each
/// once), until [timeout] or the listener stops.
Stream<FoundLibrary> discoverLibraries({Duration? timeout}) {
  late final StreamController<FoundLibrary> out;
  BonsoirDiscovery? discovery;
  Timer? timer;
  final seen = <String>{};

  Future<void> stop() async {
    timer?.cancel();
    final d = discovery;
    discovery = null;
    if (d != null) {
      try {
        await d.stop();
      } on Object {
        // Already stopped.
      }
    }
    if (!out.isClosed) await out.close();
  }

  out = StreamController<FoundLibrary>(
    onListen: () async {
      if (timeout != null) timer = Timer(timeout, stop);
      try {
        final d = BonsoirDiscovery(type: shareServiceType);
        discovery = d;
        await d.initialize();
        d.eventStream!.listen((event) {
          switch (event) {
            case BonsoirDiscoveryServiceFoundEvent(:final service):
              unawaited(service.resolve(d.serviceResolver));
            case BonsoirDiscoveryServiceResolvedEvent(:final service):
              final id = service.attributes['id'];
              final host = _pickAddress(service.hostAddresses);
              if (id == null || host == null || out.isClosed) return;
              final address = joinAddress(host, service.port);
              if (seen.add('$id@$address')) {
                out.add((
                  id: id,
                  name: service.name.replaceFirst(RegExp('^Panelist on '), ''),
                  address: address,
                ));
              }
            default:
          }
        });
        await d.start();
      } on Object catch (e) {
        debugPrint('Couldn’t look for libraries: $e');
        await stop();
      }
    },
    onCancel: stop,
  );
  return out.stream;
}

/// IPv4 first (simplest to reach), then anything but link-local IPv6.
String? _pickAddress(List<String> addresses) =>
    addresses.where((a) => !a.contains(':')).firstOrNull ??
    addresses.where((a) => !a.toLowerCase().startsWith('fe80')).firstOrNull;

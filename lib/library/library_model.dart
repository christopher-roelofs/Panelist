import 'package:path/path.dart' as p;

import '../core/util/natural_sort.dart';
import '../data/database.dart';
import 'comic_name.dart';

/// Where a displayed field's value came from.
enum FieldSource { comicInfo, fileName, folder }

enum ReadState { unread, reading, read }

/// A comic in the library with its reading progress and the names used to
/// group it. ComicInfo.xml wins; without it the series comes from the
/// comic's folder (when it's in one) or its file name.
/// Whether two series names from file and folder names are the same series,
/// or one is a shorter form of the other (ignoring case and punctuation).
bool sameSeries(String a, String b) {
  String norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  final x = norm(a);
  final y = norm(b);
  if (x.isEmpty || y.isEmpty) return false;
  return x.startsWith(y) || y.startsWith(x);
}

class LibraryComic {
  LibraryComic(this.entry, this.progress, {String? publisher})
    : publisher = publisher ?? entry.publisher;

  final LibraryEntry entry;

  /// Null until the book has been opened.
  final BookProgress? progress;

  late final ComicName _file = ComicName.parse(entry.fileName);
  late final ComicName? _folder = entry.folder.isEmpty
      ? null
      : ComicName.parse(entry.folder.split('/').last, isFolder: true);

  String get location => entry.location;

  /// What the folder and file names say, ignoring ComicInfo (to fill in
  /// ComicInfo from them).
  ({String? series, String? number, int? year}) get nameGuess => (
    series: _nameSeries?.$1,
    number: _file.number,
    year: _file.year ?? _folder?.year,
  );

  /// The series from the names. The folder's name is used only when it's
  /// about this comic: the file name has no series of its own (`01.cbz`,
  /// `Chapter 01.cbz`), or gives a fuller name for the same series (folder
  /// `Locke & Key - Welcome to Lovecraft (2008)`, file `Locke & Key
  /// 001.cbz`). Otherwise
  /// the folder is something else (`2026.11.18 DC Week`, `Image`,
  /// `Downloads`) and the file name wins.
  late final (String, FieldSource)? _nameSeries = () {
    final file = _file.series;
    final folder = _folder?.series;
    if (folder != null) {
      if (file == null || _genericSeries.hasMatch(file)) {
        return (folder, FieldSource.folder);
      }
      // Same series: the fuller name (a folder `Batman` doesn't shorten
      // `Batman - Superman 001`).
      if (sameSeries(file, folder) && folder.length >= file.length) {
        return (folder, FieldSource.folder);
      }
    }
    return file == null ? null : (file, FieldSource.fileName);
  }();

  static final _genericSeries = RegExp(
    r'^(?:ch(?:apter)?|issue|part|vol(?:ume)?|v|episode|ep|book|no)$',
    caseSensitive: false,
  );

  (String, FieldSource) get seriesWithSource {
    if (entry.series case final s?) return (s, FieldSource.comicInfo);
    return _nameSeries ??
        (p.basenameWithoutExtension(entry.fileName), FieldSource.fileName);
  }

  String get series => seriesWithSource.$1;

  (String, FieldSource)? get numberWithSource {
    if (entry.number case final n?) return (n, FieldSource.comicInfo);
    if (_file.number case final n?) return (n, FieldSource.fileName);
    return null;
  }

  String? get number => numberWithSource?.$1;

  (int, FieldSource)? get yearWithSource {
    if (entry.year case final y?) return (y, FieldSource.comicInfo);
    if (_file.year case final y?) return (y, FieldSource.fileName);
    if (_folder?.year case final y?) return (y, FieldSource.folder);
    return null;
  }

  int? get year => yearWithSource?.$1;

  /// From ComicInfo only, as the user's publisher rules name it; null means
  /// unknown.
  final String? publisher;

  /// "#3 (2008)", or the file name when there's no number.
  String get issueLabel {
    final n = number;
    final y = year;
    if (n == null) return p.basenameWithoutExtension(entry.fileName);
    return y == null ? '#$n' : '#$n ($y)';
  }

  ReadState get readState {
    final pr = progress;
    if (pr == null) return ReadState.unread;
    if (pr.finished) return ReadState.read;
    // Opened but still on the cover (or marked unread): not started.
    if (pr.currentPage == 0) return ReadState.unread;
    return ReadState.reading;
  }

  /// 0..1, for a progress bar.
  double get progressFraction {
    final pr = progress;
    if (pr == null || pr.pageCount <= 1) return 0;
    return (pr.currentPage / (pr.pageCount - 1)).clamp(0, 1);
  }
}

/// Issue order: number, then year, then file name.
int compareIssues(LibraryComic a, LibraryComic b) {
  final na = _leadingNumber(a.number);
  final nb = _leadingNumber(b.number);
  if (na != nb) {
    if (na == null) return 1;
    if (nb == null) return -1;
    return na.compareTo(nb);
  }
  final ya = a.year ?? 0;
  final yb = b.year ?? 0;
  if (ya != yb) return ya.compareTo(yb);
  return naturalCompare(a.entry.fileName, b.entry.fileName);
}

double? _leadingNumber(String? n) {
  if (n == null) return null;
  final m = RegExp(r'^-?\d+(?:\.\d+)?').firstMatch(n);
  return m == null ? null : double.parse(m.group(0)!);
}

class SeriesGroup {
  SeriesGroup(this.name, List<LibraryComic> comics)
    : comics = [...comics]..sort(compareIssues);

  final String name;

  /// In issue order.
  final List<LibraryComic> comics;

  LibraryComic get first => comics.first;
  int get readCount =>
      comics.where((c) => c.readState == ReadState.read).length;
}

class PublisherGroup {
  PublisherGroup(this.name, this.series);

  /// Null for comics without a publisher.
  final String? name;
  final List<SeriesGroup> series;

  LibraryComic get first => series.first.first;
  int get issueCount => series.fold(0, (n, s) => n + s.comics.length);
}

/// Series, alphabetical. Names are compared exactly as written.
List<SeriesGroup> groupBySeries(Iterable<LibraryComic> comics) {
  final by = <String, List<LibraryComic>>{};
  for (final c in comics) {
    (by[c.series] ??= []).add(c);
  }
  return [for (final e in by.entries) SeriesGroup(e.key, e.value)]
    ..sort((a, b) => naturalCompare(a.name, b.name));
}

/// Publishers, alphabetical, with the unknown publisher last.
List<PublisherGroup> groupByPublisher(Iterable<LibraryComic> comics) {
  final by = <String?, List<LibraryComic>>{};
  for (final c in comics) {
    (by[c.publisher] ??= []).add(c);
  }
  return [
    for (final e in by.entries) PublisherGroup(e.key, groupBySeries(e.value)),
  ]..sort((a, b) {
    if (a.name == null) return 1;
    if (b.name == null) return -1;
    return naturalCompare(a.name!, b.name!);
  });
}

class FolderGroup {
  FolderGroup(this.name, this.comics);

  final String name;

  /// Everything inside, at any depth.
  final List<LibraryComic> comics;

  /// The comic whose cover represents the folder: the first by path.
  LibraryComic get first => comics.reduce(
    (a, b) => naturalCompare(_sortPath(a), _sortPath(b)) <= 0 ? a : b,
  );

  static String _sortPath(LibraryComic c) =>
      '${c.entry.folder}/${c.entry.fileName}';
}

/// What's directly inside [folder] (`/`-separated, empty for the top) of
/// library root [rootId]: its subfolders and comics, each in natural order.
(List<FolderGroup>, List<LibraryComic>) folderContents(
  Iterable<LibraryComic> comics,
  int rootId,
  String folder,
) {
  final prefix = folder.isEmpty ? '' : '$folder/';
  final subfolders = <String, List<LibraryComic>>{};
  final files = <LibraryComic>[];
  for (final c in comics) {
    final e = c.entry;
    if (e.rootId != rootId) continue;
    if (e.folder == folder) {
      files.add(c);
    } else if (folder.isEmpty || e.folder.startsWith(prefix)) {
      final rest = e.folder.substring(prefix.length);
      (subfolders[rest.split('/').first] ??= []).add(c);
    }
  }
  return (
    [for (final e in subfolders.entries) FolderGroup(e.key, e.value)]
      ..sort((a, b) => naturalCompare(a.name, b.name)),
    files..sort((a, b) => naturalCompare(a.entry.fileName, b.entry.fileName)),
  );
}

/// Comics whose series, title, file name or publisher contain every word
/// of [query] (case-insensitive), in series then issue order.
List<LibraryComic> searchComics(Iterable<LibraryComic> comics, String query) {
  final words = query.toLowerCase().split(RegExp(r'\s+'))
    ..removeWhere((w) => w.isEmpty);
  if (words.isEmpty) return const [];
  final hits = [
    for (final c in comics)
      if ([
            c.series,
            c.entry.title ?? '',
            c.entry.fileName,
            c.publisher ?? '',
            c.number == null ? '' : '#${c.number}',
          ].join(' ').toLowerCase()
          case final text when words.every(text.contains))
        c,
  ];
  return hits..sort((a, b) {
    final s = naturalCompare(a.series, b.series);
    return s != 0 ? s : compareIssues(a, b);
  });
}

/// The issue after the book [bookId] in its series (by number, then year,
/// then file name), or null if it's the last one, or not in the library.
LibraryComic? nextInSeries(Iterable<LibraryComic> comics, String bookId) {
  final current = comics.where((c) => c.entry.bookId == bookId).firstOrNull;
  if (current == null) return null;
  final series = comics.where((c) => c.series == current.series).toList()
    ..sort(compareIssues);
  final i = series.indexOf(current);
  // Skip other copies of the same book (same content in two places).
  for (final c in series.skip(i + 1)) {
    if (c.entry.bookId != bookId) return c;
  }
  return null;
}

/// Marks [comics] read or unread. Comics not scanned yet are skipped.
Future<void> markComics(
  AppDatabase db,
  Iterable<LibraryComic> comics, {
  required bool read,
}) {
  final scanned = comics.where(
    (c) => c.entry.bookId != null && c.entry.pageCount != null,
  );
  if (!read) return db.markUnread(scanned.map((c) => c.entry.bookId!));
  return db.markRead([
    for (final c in scanned)
      (
        id: c.entry.bookId!,
        path: c.location,
        title: '${c.series} ${c.issueLabel}',
        pageCount: c.entry.pageCount!,
      ),
  ]);
}

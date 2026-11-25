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
class LibraryComic {
  LibraryComic(this.entry, this.progress);

  final LibraryEntry entry;

  /// Null until the book has been opened.
  final BookProgress? progress;

  late final ComicName _file = ComicName.parse(entry.fileName);
  late final ComicName? _folder = entry.folder.isEmpty
      ? null
      : ComicName.parse(entry.folder.split('/').last, isFolder: true);

  String get location => entry.location;

  (String, FieldSource) get seriesWithSource {
    if (entry.series case final s?) return (s, FieldSource.comicInfo);
    if (_folder?.series case final s?) return (s, FieldSource.folder);
    if (_file.series case final s?) return (s, FieldSource.fileName);
    return (p.basenameWithoutExtension(entry.fileName), FieldSource.fileName);
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

  /// From ComicInfo only; null means unknown.
  String? get publisher => entry.publisher;

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
    if (pr.currentPage >= pr.pageCount - 1) return ReadState.read;
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

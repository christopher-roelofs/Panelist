/// What the computer sharing its library and the devices reading from it
/// say to each other (see docs/PLAN.md, M7). Times are UTC milliseconds.
library;

import '../data/database.dart';

const apiVersion = 1;
const apiPath = '/api/v$apiVersion';
const defaultSharePort = 8696;

/// The mDNS service type the computer advertises.
const shareServiceType = '_panelist._tcp';

DateTime? _time(Object? ms) =>
    ms is int ? DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true) : null;

int? _ms(DateTime? t) => t?.toUtc().millisecondsSinceEpoch;

/// One comic in a shared library.
class RemoteComic {
  const RemoteComic({
    required this.id,
    required this.folder,
    required this.fileName,
    required this.size,
    this.pageCount,
    this.series,
    this.number,
    this.volume,
    this.year,
    this.publisher,
    this.title,
  });

  factory RemoteComic.fromEntry(LibraryEntry e) => RemoteComic(
    id: e.bookId!,
    folder: e.folder,
    fileName: e.fileName,
    size: e.size,
    pageCount: e.pageCount,
    series: e.series,
    number: e.number,
    volume: e.volume,
    year: e.year,
    publisher: e.publisher,
    title: e.title,
  );

  factory RemoteComic.fromJson(Map<String, Object?> j) => RemoteComic(
    id: j['id']! as String,
    folder: j['folder'] as String? ?? '',
    fileName: j['fileName']! as String,
    size: j['size'] as int? ?? 0,
    pageCount: j['pageCount'] as int?,
    series: j['series'] as String?,
    number: j['number'] as String?,
    volume: j['volume'] as int?,
    year: j['year'] as int?,
    publisher: j['publisher'] as String?,
    title: j['title'] as String?,
  );

  /// The book ID (from the pages, so a downloaded copy has the same one).
  final String id;

  /// Folder inside the library, `/`-separated; empty at the top.
  final String folder;
  final String fileName;
  final int size;
  final int? pageCount;
  final String? series;
  final String? number;
  final int? volume;
  final int? year;
  final String? publisher;
  final String? title;

  Map<String, Object?> toJson() => {
    'id': id,
    'folder': folder,
    'fileName': fileName,
    'size': size,
    'pageCount': ?pageCount,
    'series': ?series,
    'number': ?number,
    'volume': ?volume,
    'year': ?year,
    'publisher': ?publisher,
    'title': ?title,
  };
}

/// A book's reading position as of [updated].
class ProgressChange {
  const ProgressChange({
    required this.id,
    required this.page,
    required this.pageCount,
    required this.finished,
    required this.updated,
  });

  factory ProgressChange.fromJson(Map<String, Object?> j) => ProgressChange(
    id: j['id']! as String,
    page: j['page']! as int,
    pageCount: j['pageCount']! as int,
    finished: j['finished']! as bool,
    updated: _time(j['updated'])!,
  );

  final String id;
  final int page;
  final int pageCount;
  final bool finished;
  final DateTime updated;

  ProgressChange shifted(Duration by) => ProgressChange(
    id: id,
    page: page,
    pageCount: pageCount,
    finished: finished,
    updated: updated.add(by),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'page': page,
    'pageCount': pageCount,
    'finished': finished,
    'updated': _ms(updated),
  };

  @override
  bool operator ==(Object other) =>
      other is ProgressChange &&
      other.id == id &&
      other.page == page &&
      other.pageCount == pageCount &&
      other.finished == finished &&
      other.updated.isAtSameMomentAs(updated);

  @override
  int get hashCode => Object.hash(id, page, pageCount, finished);

  @override
  String toString() =>
      'ProgressChange($id, page $page/$pageCount'
      '${finished ? ', finished' : ''}, $updated)';
}

/// A sync, either way. From a device: its changes, the server time of its
/// last sync ([since], null the first time) and its clock ([now]). From
/// the computer: the changes after [since], and its time now as the next
/// [since].
class ProgressSync {
  const ProgressSync({this.since, this.now, this.changes = const []});

  factory ProgressSync.fromJson(Map<String, Object?> j) => ProgressSync(
    since: _time(j['since']),
    now: _time(j['now']),
    changes: [
      for (final c in (j['changes'] as List?) ?? const [])
        ProgressChange.fromJson(c as Map<String, Object?>),
    ],
  );

  final DateTime? since;
  final DateTime? now;
  final List<ProgressChange> changes;

  Map<String, Object?> toJson() => {
    'since': _ms(since),
    'now': _ms(now),
    'changes': [for (final c in changes) c.toJson()],
  };
}

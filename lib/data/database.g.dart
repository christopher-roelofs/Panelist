// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $BooksTable extends Books with TableInfo<$BooksTable, Book> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BooksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pageCountMeta = const VerificationMeta(
    'pageCount',
  );
  @override
  late final GeneratedColumn<int> pageCount = GeneratedColumn<int>(
    'page_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currentPageMeta = const VerificationMeta(
    'currentPage',
  );
  @override
  late final GeneratedColumn<int> currentPage = GeneratedColumn<int>(
    'current_page',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastOpenedMeta = const VerificationMeta(
    'lastOpened',
  );
  @override
  late final GeneratedColumn<DateTime> lastOpened = GeneratedColumn<DateTime>(
    'last_opened',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _coverMeta = const VerificationMeta('cover');
  @override
  late final GeneratedColumn<Uint8List> cover = GeneratedColumn<Uint8List>(
    'cover',
    aliasedName,
    true,
    type: DriftSqlType.blob,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _seriesMeta = const VerificationMeta('series');
  @override
  late final GeneratedColumn<String> series = GeneratedColumn<String>(
    'series',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _numberMeta = const VerificationMeta('number');
  @override
  late final GeneratedColumn<String> number = GeneratedColumn<String>(
    'number',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _writerMeta = const VerificationMeta('writer');
  @override
  late final GeneratedColumn<String> writer = GeneratedColumn<String>(
    'writer',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _artistMeta = const VerificationMeta('artist');
  @override
  late final GeneratedColumn<String> artist = GeneratedColumn<String>(
    'artist',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _summaryMeta = const VerificationMeta(
    'summary',
  );
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
    'summary',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rightToLeftMeta = const VerificationMeta(
    'rightToLeft',
  );
  @override
  late final GeneratedColumn<bool> rightToLeft = GeneratedColumn<bool>(
    'right_to_left',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("right_to_left" IN (0, 1))',
    ),
  );
  static const VerificationMeta _publisherMeta = const VerificationMeta(
    'publisher',
  );
  @override
  late final GeneratedColumn<String> publisher = GeneratedColumn<String>(
    'publisher',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _finishedMeta = const VerificationMeta(
    'finished',
  );
  @override
  late final GeneratedColumn<bool> finished = GeneratedColumn<bool>(
    'finished',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("finished" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _progressUpdatedMeta = const VerificationMeta(
    'progressUpdated',
  );
  @override
  late final GeneratedColumn<DateTime> progressUpdated =
      GeneratedColumn<DateTime>(
        'progress_updated',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _pageSizesMeta = const VerificationMeta(
    'pageSizes',
  );
  @override
  late final GeneratedColumn<String> pageSizes = GeneratedColumn<String>(
    'page_sizes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fitModeMeta = const VerificationMeta(
    'fitMode',
  );
  @override
  late final GeneratedColumn<String> fitMode = GeneratedColumn<String>(
    'fit_mode',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _layoutModeMeta = const VerificationMeta(
    'layoutMode',
  );
  @override
  late final GeneratedColumn<String> layoutMode = GeneratedColumn<String>(
    'layout_mode',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverAloneMeta = const VerificationMeta(
    'coverAlone',
  );
  @override
  late final GeneratedColumn<bool> coverAlone = GeneratedColumn<bool>(
    'cover_alone',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("cover_alone" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    path,
    title,
    pageCount,
    currentPage,
    lastOpened,
    cover,
    series,
    number,
    year,
    writer,
    artist,
    summary,
    rightToLeft,
    publisher,
    finished,
    progressUpdated,
    pageSizes,
    fitMode,
    layoutMode,
    coverAlone,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'books';
  @override
  VerificationContext validateIntegrity(
    Insertable<Book> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('page_count')) {
      context.handle(
        _pageCountMeta,
        pageCount.isAcceptableOrUnknown(data['page_count']!, _pageCountMeta),
      );
    } else if (isInserting) {
      context.missing(_pageCountMeta);
    }
    if (data.containsKey('current_page')) {
      context.handle(
        _currentPageMeta,
        currentPage.isAcceptableOrUnknown(
          data['current_page']!,
          _currentPageMeta,
        ),
      );
    }
    if (data.containsKey('last_opened')) {
      context.handle(
        _lastOpenedMeta,
        lastOpened.isAcceptableOrUnknown(data['last_opened']!, _lastOpenedMeta),
      );
    } else if (isInserting) {
      context.missing(_lastOpenedMeta);
    }
    if (data.containsKey('cover')) {
      context.handle(
        _coverMeta,
        cover.isAcceptableOrUnknown(data['cover']!, _coverMeta),
      );
    }
    if (data.containsKey('series')) {
      context.handle(
        _seriesMeta,
        series.isAcceptableOrUnknown(data['series']!, _seriesMeta),
      );
    }
    if (data.containsKey('number')) {
      context.handle(
        _numberMeta,
        number.isAcceptableOrUnknown(data['number']!, _numberMeta),
      );
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    }
    if (data.containsKey('writer')) {
      context.handle(
        _writerMeta,
        writer.isAcceptableOrUnknown(data['writer']!, _writerMeta),
      );
    }
    if (data.containsKey('artist')) {
      context.handle(
        _artistMeta,
        artist.isAcceptableOrUnknown(data['artist']!, _artistMeta),
      );
    }
    if (data.containsKey('summary')) {
      context.handle(
        _summaryMeta,
        summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta),
      );
    }
    if (data.containsKey('right_to_left')) {
      context.handle(
        _rightToLeftMeta,
        rightToLeft.isAcceptableOrUnknown(
          data['right_to_left']!,
          _rightToLeftMeta,
        ),
      );
    }
    if (data.containsKey('publisher')) {
      context.handle(
        _publisherMeta,
        publisher.isAcceptableOrUnknown(data['publisher']!, _publisherMeta),
      );
    }
    if (data.containsKey('finished')) {
      context.handle(
        _finishedMeta,
        finished.isAcceptableOrUnknown(data['finished']!, _finishedMeta),
      );
    }
    if (data.containsKey('progress_updated')) {
      context.handle(
        _progressUpdatedMeta,
        progressUpdated.isAcceptableOrUnknown(
          data['progress_updated']!,
          _progressUpdatedMeta,
        ),
      );
    }
    if (data.containsKey('page_sizes')) {
      context.handle(
        _pageSizesMeta,
        pageSizes.isAcceptableOrUnknown(data['page_sizes']!, _pageSizesMeta),
      );
    }
    if (data.containsKey('fit_mode')) {
      context.handle(
        _fitModeMeta,
        fitMode.isAcceptableOrUnknown(data['fit_mode']!, _fitModeMeta),
      );
    }
    if (data.containsKey('layout_mode')) {
      context.handle(
        _layoutModeMeta,
        layoutMode.isAcceptableOrUnknown(data['layout_mode']!, _layoutModeMeta),
      );
    }
    if (data.containsKey('cover_alone')) {
      context.handle(
        _coverAloneMeta,
        coverAlone.isAcceptableOrUnknown(data['cover_alone']!, _coverAloneMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Book map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Book(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      pageCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page_count'],
      )!,
      currentPage: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_page'],
      )!,
      lastOpened: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_opened'],
      )!,
      cover: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}cover'],
      ),
      series: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}series'],
      ),
      number: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}number'],
      ),
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      ),
      writer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}writer'],
      ),
      artist: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist'],
      ),
      summary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary'],
      ),
      rightToLeft: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}right_to_left'],
      ),
      publisher: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}publisher'],
      ),
      finished: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}finished'],
      )!,
      progressUpdated: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}progress_updated'],
      ),
      pageSizes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}page_sizes'],
      ),
      fitMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fit_mode'],
      ),
      layoutMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}layout_mode'],
      ),
      coverAlone: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}cover_alone'],
      ),
    );
  }

  @override
  $BooksTable createAlias(String alias) {
    return $BooksTable(attachedDatabase, alias);
  }
}

class Book extends DataClass implements Insertable<Book> {
  final String id;
  final String path;
  final String title;
  final int pageCount;
  final int currentPage;
  final DateTime lastOpened;
  final Uint8List? cover;
  final String? series;
  final String? number;
  final int? year;
  final String? writer;
  final String? artist;
  final String? summary;
  final bool? rightToLeft;
  final String? publisher;

  /// Read to the end (or marked read). Stays set when paging back or
  /// re-reading, until the book is marked unread.
  final bool finished;

  /// When the reading position or finished flag last changed (here or by
  /// sync); null if never. Syncing compares these: the latest wins.
  final DateTime? progressUpdated;

  /// Cached page sizes, JSON `[[w,h] | null, ...]`.
  final String? pageSizes;
  final String? fitMode;
  final String? layoutMode;
  final bool? coverAlone;
  const Book({
    required this.id,
    required this.path,
    required this.title,
    required this.pageCount,
    required this.currentPage,
    required this.lastOpened,
    this.cover,
    this.series,
    this.number,
    this.year,
    this.writer,
    this.artist,
    this.summary,
    this.rightToLeft,
    this.publisher,
    required this.finished,
    this.progressUpdated,
    this.pageSizes,
    this.fitMode,
    this.layoutMode,
    this.coverAlone,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['path'] = Variable<String>(path);
    map['title'] = Variable<String>(title);
    map['page_count'] = Variable<int>(pageCount);
    map['current_page'] = Variable<int>(currentPage);
    map['last_opened'] = Variable<DateTime>(lastOpened);
    if (!nullToAbsent || cover != null) {
      map['cover'] = Variable<Uint8List>(cover);
    }
    if (!nullToAbsent || series != null) {
      map['series'] = Variable<String>(series);
    }
    if (!nullToAbsent || number != null) {
      map['number'] = Variable<String>(number);
    }
    if (!nullToAbsent || year != null) {
      map['year'] = Variable<int>(year);
    }
    if (!nullToAbsent || writer != null) {
      map['writer'] = Variable<String>(writer);
    }
    if (!nullToAbsent || artist != null) {
      map['artist'] = Variable<String>(artist);
    }
    if (!nullToAbsent || summary != null) {
      map['summary'] = Variable<String>(summary);
    }
    if (!nullToAbsent || rightToLeft != null) {
      map['right_to_left'] = Variable<bool>(rightToLeft);
    }
    if (!nullToAbsent || publisher != null) {
      map['publisher'] = Variable<String>(publisher);
    }
    map['finished'] = Variable<bool>(finished);
    if (!nullToAbsent || progressUpdated != null) {
      map['progress_updated'] = Variable<DateTime>(progressUpdated);
    }
    if (!nullToAbsent || pageSizes != null) {
      map['page_sizes'] = Variable<String>(pageSizes);
    }
    if (!nullToAbsent || fitMode != null) {
      map['fit_mode'] = Variable<String>(fitMode);
    }
    if (!nullToAbsent || layoutMode != null) {
      map['layout_mode'] = Variable<String>(layoutMode);
    }
    if (!nullToAbsent || coverAlone != null) {
      map['cover_alone'] = Variable<bool>(coverAlone);
    }
    return map;
  }

  BooksCompanion toCompanion(bool nullToAbsent) {
    return BooksCompanion(
      id: Value(id),
      path: Value(path),
      title: Value(title),
      pageCount: Value(pageCount),
      currentPage: Value(currentPage),
      lastOpened: Value(lastOpened),
      cover: cover == null && nullToAbsent
          ? const Value.absent()
          : Value(cover),
      series: series == null && nullToAbsent
          ? const Value.absent()
          : Value(series),
      number: number == null && nullToAbsent
          ? const Value.absent()
          : Value(number),
      year: year == null && nullToAbsent ? const Value.absent() : Value(year),
      writer: writer == null && nullToAbsent
          ? const Value.absent()
          : Value(writer),
      artist: artist == null && nullToAbsent
          ? const Value.absent()
          : Value(artist),
      summary: summary == null && nullToAbsent
          ? const Value.absent()
          : Value(summary),
      rightToLeft: rightToLeft == null && nullToAbsent
          ? const Value.absent()
          : Value(rightToLeft),
      publisher: publisher == null && nullToAbsent
          ? const Value.absent()
          : Value(publisher),
      finished: Value(finished),
      progressUpdated: progressUpdated == null && nullToAbsent
          ? const Value.absent()
          : Value(progressUpdated),
      pageSizes: pageSizes == null && nullToAbsent
          ? const Value.absent()
          : Value(pageSizes),
      fitMode: fitMode == null && nullToAbsent
          ? const Value.absent()
          : Value(fitMode),
      layoutMode: layoutMode == null && nullToAbsent
          ? const Value.absent()
          : Value(layoutMode),
      coverAlone: coverAlone == null && nullToAbsent
          ? const Value.absent()
          : Value(coverAlone),
    );
  }

  factory Book.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Book(
      id: serializer.fromJson<String>(json['id']),
      path: serializer.fromJson<String>(json['path']),
      title: serializer.fromJson<String>(json['title']),
      pageCount: serializer.fromJson<int>(json['pageCount']),
      currentPage: serializer.fromJson<int>(json['currentPage']),
      lastOpened: serializer.fromJson<DateTime>(json['lastOpened']),
      cover: serializer.fromJson<Uint8List?>(json['cover']),
      series: serializer.fromJson<String?>(json['series']),
      number: serializer.fromJson<String?>(json['number']),
      year: serializer.fromJson<int?>(json['year']),
      writer: serializer.fromJson<String?>(json['writer']),
      artist: serializer.fromJson<String?>(json['artist']),
      summary: serializer.fromJson<String?>(json['summary']),
      rightToLeft: serializer.fromJson<bool?>(json['rightToLeft']),
      publisher: serializer.fromJson<String?>(json['publisher']),
      finished: serializer.fromJson<bool>(json['finished']),
      progressUpdated: serializer.fromJson<DateTime?>(json['progressUpdated']),
      pageSizes: serializer.fromJson<String?>(json['pageSizes']),
      fitMode: serializer.fromJson<String?>(json['fitMode']),
      layoutMode: serializer.fromJson<String?>(json['layoutMode']),
      coverAlone: serializer.fromJson<bool?>(json['coverAlone']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'path': serializer.toJson<String>(path),
      'title': serializer.toJson<String>(title),
      'pageCount': serializer.toJson<int>(pageCount),
      'currentPage': serializer.toJson<int>(currentPage),
      'lastOpened': serializer.toJson<DateTime>(lastOpened),
      'cover': serializer.toJson<Uint8List?>(cover),
      'series': serializer.toJson<String?>(series),
      'number': serializer.toJson<String?>(number),
      'year': serializer.toJson<int?>(year),
      'writer': serializer.toJson<String?>(writer),
      'artist': serializer.toJson<String?>(artist),
      'summary': serializer.toJson<String?>(summary),
      'rightToLeft': serializer.toJson<bool?>(rightToLeft),
      'publisher': serializer.toJson<String?>(publisher),
      'finished': serializer.toJson<bool>(finished),
      'progressUpdated': serializer.toJson<DateTime?>(progressUpdated),
      'pageSizes': serializer.toJson<String?>(pageSizes),
      'fitMode': serializer.toJson<String?>(fitMode),
      'layoutMode': serializer.toJson<String?>(layoutMode),
      'coverAlone': serializer.toJson<bool?>(coverAlone),
    };
  }

  Book copyWith({
    String? id,
    String? path,
    String? title,
    int? pageCount,
    int? currentPage,
    DateTime? lastOpened,
    Value<Uint8List?> cover = const Value.absent(),
    Value<String?> series = const Value.absent(),
    Value<String?> number = const Value.absent(),
    Value<int?> year = const Value.absent(),
    Value<String?> writer = const Value.absent(),
    Value<String?> artist = const Value.absent(),
    Value<String?> summary = const Value.absent(),
    Value<bool?> rightToLeft = const Value.absent(),
    Value<String?> publisher = const Value.absent(),
    bool? finished,
    Value<DateTime?> progressUpdated = const Value.absent(),
    Value<String?> pageSizes = const Value.absent(),
    Value<String?> fitMode = const Value.absent(),
    Value<String?> layoutMode = const Value.absent(),
    Value<bool?> coverAlone = const Value.absent(),
  }) => Book(
    id: id ?? this.id,
    path: path ?? this.path,
    title: title ?? this.title,
    pageCount: pageCount ?? this.pageCount,
    currentPage: currentPage ?? this.currentPage,
    lastOpened: lastOpened ?? this.lastOpened,
    cover: cover.present ? cover.value : this.cover,
    series: series.present ? series.value : this.series,
    number: number.present ? number.value : this.number,
    year: year.present ? year.value : this.year,
    writer: writer.present ? writer.value : this.writer,
    artist: artist.present ? artist.value : this.artist,
    summary: summary.present ? summary.value : this.summary,
    rightToLeft: rightToLeft.present ? rightToLeft.value : this.rightToLeft,
    publisher: publisher.present ? publisher.value : this.publisher,
    finished: finished ?? this.finished,
    progressUpdated: progressUpdated.present
        ? progressUpdated.value
        : this.progressUpdated,
    pageSizes: pageSizes.present ? pageSizes.value : this.pageSizes,
    fitMode: fitMode.present ? fitMode.value : this.fitMode,
    layoutMode: layoutMode.present ? layoutMode.value : this.layoutMode,
    coverAlone: coverAlone.present ? coverAlone.value : this.coverAlone,
  );
  Book copyWithCompanion(BooksCompanion data) {
    return Book(
      id: data.id.present ? data.id.value : this.id,
      path: data.path.present ? data.path.value : this.path,
      title: data.title.present ? data.title.value : this.title,
      pageCount: data.pageCount.present ? data.pageCount.value : this.pageCount,
      currentPage: data.currentPage.present
          ? data.currentPage.value
          : this.currentPage,
      lastOpened: data.lastOpened.present
          ? data.lastOpened.value
          : this.lastOpened,
      cover: data.cover.present ? data.cover.value : this.cover,
      series: data.series.present ? data.series.value : this.series,
      number: data.number.present ? data.number.value : this.number,
      year: data.year.present ? data.year.value : this.year,
      writer: data.writer.present ? data.writer.value : this.writer,
      artist: data.artist.present ? data.artist.value : this.artist,
      summary: data.summary.present ? data.summary.value : this.summary,
      rightToLeft: data.rightToLeft.present
          ? data.rightToLeft.value
          : this.rightToLeft,
      publisher: data.publisher.present ? data.publisher.value : this.publisher,
      finished: data.finished.present ? data.finished.value : this.finished,
      progressUpdated: data.progressUpdated.present
          ? data.progressUpdated.value
          : this.progressUpdated,
      pageSizes: data.pageSizes.present ? data.pageSizes.value : this.pageSizes,
      fitMode: data.fitMode.present ? data.fitMode.value : this.fitMode,
      layoutMode: data.layoutMode.present
          ? data.layoutMode.value
          : this.layoutMode,
      coverAlone: data.coverAlone.present
          ? data.coverAlone.value
          : this.coverAlone,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Book(')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('title: $title, ')
          ..write('pageCount: $pageCount, ')
          ..write('currentPage: $currentPage, ')
          ..write('lastOpened: $lastOpened, ')
          ..write('cover: $cover, ')
          ..write('series: $series, ')
          ..write('number: $number, ')
          ..write('year: $year, ')
          ..write('writer: $writer, ')
          ..write('artist: $artist, ')
          ..write('summary: $summary, ')
          ..write('rightToLeft: $rightToLeft, ')
          ..write('publisher: $publisher, ')
          ..write('finished: $finished, ')
          ..write('progressUpdated: $progressUpdated, ')
          ..write('pageSizes: $pageSizes, ')
          ..write('fitMode: $fitMode, ')
          ..write('layoutMode: $layoutMode, ')
          ..write('coverAlone: $coverAlone')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    path,
    title,
    pageCount,
    currentPage,
    lastOpened,
    $driftBlobEquality.hash(cover),
    series,
    number,
    year,
    writer,
    artist,
    summary,
    rightToLeft,
    publisher,
    finished,
    progressUpdated,
    pageSizes,
    fitMode,
    layoutMode,
    coverAlone,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Book &&
          other.id == this.id &&
          other.path == this.path &&
          other.title == this.title &&
          other.pageCount == this.pageCount &&
          other.currentPage == this.currentPage &&
          other.lastOpened == this.lastOpened &&
          $driftBlobEquality.equals(other.cover, this.cover) &&
          other.series == this.series &&
          other.number == this.number &&
          other.year == this.year &&
          other.writer == this.writer &&
          other.artist == this.artist &&
          other.summary == this.summary &&
          other.rightToLeft == this.rightToLeft &&
          other.publisher == this.publisher &&
          other.finished == this.finished &&
          other.progressUpdated == this.progressUpdated &&
          other.pageSizes == this.pageSizes &&
          other.fitMode == this.fitMode &&
          other.layoutMode == this.layoutMode &&
          other.coverAlone == this.coverAlone);
}

class BooksCompanion extends UpdateCompanion<Book> {
  final Value<String> id;
  final Value<String> path;
  final Value<String> title;
  final Value<int> pageCount;
  final Value<int> currentPage;
  final Value<DateTime> lastOpened;
  final Value<Uint8List?> cover;
  final Value<String?> series;
  final Value<String?> number;
  final Value<int?> year;
  final Value<String?> writer;
  final Value<String?> artist;
  final Value<String?> summary;
  final Value<bool?> rightToLeft;
  final Value<String?> publisher;
  final Value<bool> finished;
  final Value<DateTime?> progressUpdated;
  final Value<String?> pageSizes;
  final Value<String?> fitMode;
  final Value<String?> layoutMode;
  final Value<bool?> coverAlone;
  final Value<int> rowid;
  const BooksCompanion({
    this.id = const Value.absent(),
    this.path = const Value.absent(),
    this.title = const Value.absent(),
    this.pageCount = const Value.absent(),
    this.currentPage = const Value.absent(),
    this.lastOpened = const Value.absent(),
    this.cover = const Value.absent(),
    this.series = const Value.absent(),
    this.number = const Value.absent(),
    this.year = const Value.absent(),
    this.writer = const Value.absent(),
    this.artist = const Value.absent(),
    this.summary = const Value.absent(),
    this.rightToLeft = const Value.absent(),
    this.publisher = const Value.absent(),
    this.finished = const Value.absent(),
    this.progressUpdated = const Value.absent(),
    this.pageSizes = const Value.absent(),
    this.fitMode = const Value.absent(),
    this.layoutMode = const Value.absent(),
    this.coverAlone = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BooksCompanion.insert({
    required String id,
    required String path,
    required String title,
    required int pageCount,
    this.currentPage = const Value.absent(),
    required DateTime lastOpened,
    this.cover = const Value.absent(),
    this.series = const Value.absent(),
    this.number = const Value.absent(),
    this.year = const Value.absent(),
    this.writer = const Value.absent(),
    this.artist = const Value.absent(),
    this.summary = const Value.absent(),
    this.rightToLeft = const Value.absent(),
    this.publisher = const Value.absent(),
    this.finished = const Value.absent(),
    this.progressUpdated = const Value.absent(),
    this.pageSizes = const Value.absent(),
    this.fitMode = const Value.absent(),
    this.layoutMode = const Value.absent(),
    this.coverAlone = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       path = Value(path),
       title = Value(title),
       pageCount = Value(pageCount),
       lastOpened = Value(lastOpened);
  static Insertable<Book> custom({
    Expression<String>? id,
    Expression<String>? path,
    Expression<String>? title,
    Expression<int>? pageCount,
    Expression<int>? currentPage,
    Expression<DateTime>? lastOpened,
    Expression<Uint8List>? cover,
    Expression<String>? series,
    Expression<String>? number,
    Expression<int>? year,
    Expression<String>? writer,
    Expression<String>? artist,
    Expression<String>? summary,
    Expression<bool>? rightToLeft,
    Expression<String>? publisher,
    Expression<bool>? finished,
    Expression<DateTime>? progressUpdated,
    Expression<String>? pageSizes,
    Expression<String>? fitMode,
    Expression<String>? layoutMode,
    Expression<bool>? coverAlone,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (path != null) 'path': path,
      if (title != null) 'title': title,
      if (pageCount != null) 'page_count': pageCount,
      if (currentPage != null) 'current_page': currentPage,
      if (lastOpened != null) 'last_opened': lastOpened,
      if (cover != null) 'cover': cover,
      if (series != null) 'series': series,
      if (number != null) 'number': number,
      if (year != null) 'year': year,
      if (writer != null) 'writer': writer,
      if (artist != null) 'artist': artist,
      if (summary != null) 'summary': summary,
      if (rightToLeft != null) 'right_to_left': rightToLeft,
      if (publisher != null) 'publisher': publisher,
      if (finished != null) 'finished': finished,
      if (progressUpdated != null) 'progress_updated': progressUpdated,
      if (pageSizes != null) 'page_sizes': pageSizes,
      if (fitMode != null) 'fit_mode': fitMode,
      if (layoutMode != null) 'layout_mode': layoutMode,
      if (coverAlone != null) 'cover_alone': coverAlone,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BooksCompanion copyWith({
    Value<String>? id,
    Value<String>? path,
    Value<String>? title,
    Value<int>? pageCount,
    Value<int>? currentPage,
    Value<DateTime>? lastOpened,
    Value<Uint8List?>? cover,
    Value<String?>? series,
    Value<String?>? number,
    Value<int?>? year,
    Value<String?>? writer,
    Value<String?>? artist,
    Value<String?>? summary,
    Value<bool?>? rightToLeft,
    Value<String?>? publisher,
    Value<bool>? finished,
    Value<DateTime?>? progressUpdated,
    Value<String?>? pageSizes,
    Value<String?>? fitMode,
    Value<String?>? layoutMode,
    Value<bool?>? coverAlone,
    Value<int>? rowid,
  }) {
    return BooksCompanion(
      id: id ?? this.id,
      path: path ?? this.path,
      title: title ?? this.title,
      pageCount: pageCount ?? this.pageCount,
      currentPage: currentPage ?? this.currentPage,
      lastOpened: lastOpened ?? this.lastOpened,
      cover: cover ?? this.cover,
      series: series ?? this.series,
      number: number ?? this.number,
      year: year ?? this.year,
      writer: writer ?? this.writer,
      artist: artist ?? this.artist,
      summary: summary ?? this.summary,
      rightToLeft: rightToLeft ?? this.rightToLeft,
      publisher: publisher ?? this.publisher,
      finished: finished ?? this.finished,
      progressUpdated: progressUpdated ?? this.progressUpdated,
      pageSizes: pageSizes ?? this.pageSizes,
      fitMode: fitMode ?? this.fitMode,
      layoutMode: layoutMode ?? this.layoutMode,
      coverAlone: coverAlone ?? this.coverAlone,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (pageCount.present) {
      map['page_count'] = Variable<int>(pageCount.value);
    }
    if (currentPage.present) {
      map['current_page'] = Variable<int>(currentPage.value);
    }
    if (lastOpened.present) {
      map['last_opened'] = Variable<DateTime>(lastOpened.value);
    }
    if (cover.present) {
      map['cover'] = Variable<Uint8List>(cover.value);
    }
    if (series.present) {
      map['series'] = Variable<String>(series.value);
    }
    if (number.present) {
      map['number'] = Variable<String>(number.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (writer.present) {
      map['writer'] = Variable<String>(writer.value);
    }
    if (artist.present) {
      map['artist'] = Variable<String>(artist.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (rightToLeft.present) {
      map['right_to_left'] = Variable<bool>(rightToLeft.value);
    }
    if (publisher.present) {
      map['publisher'] = Variable<String>(publisher.value);
    }
    if (finished.present) {
      map['finished'] = Variable<bool>(finished.value);
    }
    if (progressUpdated.present) {
      map['progress_updated'] = Variable<DateTime>(progressUpdated.value);
    }
    if (pageSizes.present) {
      map['page_sizes'] = Variable<String>(pageSizes.value);
    }
    if (fitMode.present) {
      map['fit_mode'] = Variable<String>(fitMode.value);
    }
    if (layoutMode.present) {
      map['layout_mode'] = Variable<String>(layoutMode.value);
    }
    if (coverAlone.present) {
      map['cover_alone'] = Variable<bool>(coverAlone.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BooksCompanion(')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('title: $title, ')
          ..write('pageCount: $pageCount, ')
          ..write('currentPage: $currentPage, ')
          ..write('lastOpened: $lastOpened, ')
          ..write('cover: $cover, ')
          ..write('series: $series, ')
          ..write('number: $number, ')
          ..write('year: $year, ')
          ..write('writer: $writer, ')
          ..write('artist: $artist, ')
          ..write('summary: $summary, ')
          ..write('rightToLeft: $rightToLeft, ')
          ..write('publisher: $publisher, ')
          ..write('finished: $finished, ')
          ..write('progressUpdated: $progressUpdated, ')
          ..write('pageSizes: $pageSizes, ')
          ..write('fitMode: $fitMode, ')
          ..write('layoutMode: $layoutMode, ')
          ..write('coverAlone: $coverAlone, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Setting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  final String key;
  final String value;
  const Setting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory Setting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  Setting copyWith({String? key, String? value}) =>
      Setting(key: key ?? this.key, value: value ?? this.value);
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting && other.key == this.key && other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<Setting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LibraryRootsTable extends LibraryRoots
    with TableInfo<$LibraryRootsTable, LibraryRoot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LibraryRootsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _locationMeta = const VerificationMeta(
    'location',
  );
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
    'location',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, location, name];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'library_roots';
  @override
  VerificationContext validateIntegrity(
    Insertable<LibraryRoot> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('location')) {
      context.handle(
        _locationMeta,
        location.isAcceptableOrUnknown(data['location']!, _locationMeta),
      );
    } else if (isInserting) {
      context.missing(_locationMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LibraryRoot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LibraryRoot(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      location: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
    );
  }

  @override
  $LibraryRootsTable createAlias(String alias) {
    return $LibraryRootsTable(attachedDatabase, alias);
  }
}

class LibraryRoot extends DataClass implements Insertable<LibraryRoot> {
  final int id;
  final String location;
  final String name;
  const LibraryRoot({
    required this.id,
    required this.location,
    required this.name,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['location'] = Variable<String>(location);
    map['name'] = Variable<String>(name);
    return map;
  }

  LibraryRootsCompanion toCompanion(bool nullToAbsent) {
    return LibraryRootsCompanion(
      id: Value(id),
      location: Value(location),
      name: Value(name),
    );
  }

  factory LibraryRoot.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LibraryRoot(
      id: serializer.fromJson<int>(json['id']),
      location: serializer.fromJson<String>(json['location']),
      name: serializer.fromJson<String>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'location': serializer.toJson<String>(location),
      'name': serializer.toJson<String>(name),
    };
  }

  LibraryRoot copyWith({int? id, String? location, String? name}) =>
      LibraryRoot(
        id: id ?? this.id,
        location: location ?? this.location,
        name: name ?? this.name,
      );
  LibraryRoot copyWithCompanion(LibraryRootsCompanion data) {
    return LibraryRoot(
      id: data.id.present ? data.id.value : this.id,
      location: data.location.present ? data.location.value : this.location,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LibraryRoot(')
          ..write('id: $id, ')
          ..write('location: $location, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, location, name);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LibraryRoot &&
          other.id == this.id &&
          other.location == this.location &&
          other.name == this.name);
}

class LibraryRootsCompanion extends UpdateCompanion<LibraryRoot> {
  final Value<int> id;
  final Value<String> location;
  final Value<String> name;
  const LibraryRootsCompanion({
    this.id = const Value.absent(),
    this.location = const Value.absent(),
    this.name = const Value.absent(),
  });
  LibraryRootsCompanion.insert({
    this.id = const Value.absent(),
    required String location,
    required String name,
  }) : location = Value(location),
       name = Value(name);
  static Insertable<LibraryRoot> custom({
    Expression<int>? id,
    Expression<String>? location,
    Expression<String>? name,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (location != null) 'location': location,
      if (name != null) 'name': name,
    });
  }

  LibraryRootsCompanion copyWith({
    Value<int>? id,
    Value<String>? location,
    Value<String>? name,
  }) {
    return LibraryRootsCompanion(
      id: id ?? this.id,
      location: location ?? this.location,
      name: name ?? this.name,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LibraryRootsCompanion(')
          ..write('id: $id, ')
          ..write('location: $location, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }
}

class $LibraryEntriesTable extends LibraryEntries
    with TableInfo<$LibraryEntriesTable, LibraryEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LibraryEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _locationMeta = const VerificationMeta(
    'location',
  );
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
    'location',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rootIdMeta = const VerificationMeta('rootId');
  @override
  late final GeneratedColumn<int> rootId = GeneratedColumn<int>(
    'root_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _folderMeta = const VerificationMeta('folder');
  @override
  late final GeneratedColumn<String> folder = GeneratedColumn<String>(
    'folder',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
    'size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modifiedMeta = const VerificationMeta(
    'modified',
  );
  @override
  late final GeneratedColumn<int> modified = GeneratedColumn<int>(
    'modified',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pageCountMeta = const VerificationMeta(
    'pageCount',
  );
  @override
  late final GeneratedColumn<int> pageCount = GeneratedColumn<int>(
    'page_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _seriesMeta = const VerificationMeta('series');
  @override
  late final GeneratedColumn<String> series = GeneratedColumn<String>(
    'series',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _numberMeta = const VerificationMeta('number');
  @override
  late final GeneratedColumn<String> number = GeneratedColumn<String>(
    'number',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _volumeMeta = const VerificationMeta('volume');
  @override
  late final GeneratedColumn<int> volume = GeneratedColumn<int>(
    'volume',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _publisherMeta = const VerificationMeta(
    'publisher',
  );
  @override
  late final GeneratedColumn<String> publisher = GeneratedColumn<String>(
    'publisher',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<String> error = GeneratedColumn<String>(
    'error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    location,
    rootId,
    folder,
    fileName,
    size,
    modified,
    bookId,
    pageCount,
    series,
    number,
    volume,
    year,
    publisher,
    title,
    error,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'library_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<LibraryEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('location')) {
      context.handle(
        _locationMeta,
        location.isAcceptableOrUnknown(data['location']!, _locationMeta),
      );
    } else if (isInserting) {
      context.missing(_locationMeta);
    }
    if (data.containsKey('root_id')) {
      context.handle(
        _rootIdMeta,
        rootId.isAcceptableOrUnknown(data['root_id']!, _rootIdMeta),
      );
    } else if (isInserting) {
      context.missing(_rootIdMeta);
    }
    if (data.containsKey('folder')) {
      context.handle(
        _folderMeta,
        folder.isAcceptableOrUnknown(data['folder']!, _folderMeta),
      );
    } else if (isInserting) {
      context.missing(_folderMeta);
    }
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fileNameMeta);
    }
    if (data.containsKey('size')) {
      context.handle(
        _sizeMeta,
        size.isAcceptableOrUnknown(data['size']!, _sizeMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeMeta);
    }
    if (data.containsKey('modified')) {
      context.handle(
        _modifiedMeta,
        modified.isAcceptableOrUnknown(data['modified']!, _modifiedMeta),
      );
    } else if (isInserting) {
      context.missing(_modifiedMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    }
    if (data.containsKey('page_count')) {
      context.handle(
        _pageCountMeta,
        pageCount.isAcceptableOrUnknown(data['page_count']!, _pageCountMeta),
      );
    }
    if (data.containsKey('series')) {
      context.handle(
        _seriesMeta,
        series.isAcceptableOrUnknown(data['series']!, _seriesMeta),
      );
    }
    if (data.containsKey('number')) {
      context.handle(
        _numberMeta,
        number.isAcceptableOrUnknown(data['number']!, _numberMeta),
      );
    }
    if (data.containsKey('volume')) {
      context.handle(
        _volumeMeta,
        volume.isAcceptableOrUnknown(data['volume']!, _volumeMeta),
      );
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    }
    if (data.containsKey('publisher')) {
      context.handle(
        _publisherMeta,
        publisher.isAcceptableOrUnknown(data['publisher']!, _publisherMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('error')) {
      context.handle(
        _errorMeta,
        error.isAcceptableOrUnknown(data['error']!, _errorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {location};
  @override
  LibraryEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LibraryEntry(
      location: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location'],
      )!,
      rootId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}root_id'],
      )!,
      folder: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder'],
      )!,
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      )!,
      size: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size'],
      )!,
      modified: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}modified'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      ),
      pageCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page_count'],
      ),
      series: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}series'],
      ),
      number: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}number'],
      ),
      volume: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}volume'],
      ),
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      ),
      publisher: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}publisher'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      error: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error'],
      ),
    );
  }

  @override
  $LibraryEntriesTable createAlias(String alias) {
    return $LibraryEntriesTable(attachedDatabase, alias);
  }
}

class LibraryEntry extends DataClass implements Insertable<LibraryEntry> {
  /// File path, or on Android the document URI.
  final String location;
  final int rootId;

  /// Folder inside the root, `/`-separated; empty at the root itself.
  final String folder;
  final String fileName;
  final int size;

  /// Modification time, ms since the epoch (0 if unknown).
  final int modified;

  /// The book's [Books.id] (content fingerprint), once scanned.
  final String? bookId;
  final int? pageCount;
  final String? series;
  final String? number;
  final int? volume;
  final int? year;
  final String? publisher;
  final String? title;

  /// Why the last scan couldn't read this file, if it couldn't.
  final String? error;
  const LibraryEntry({
    required this.location,
    required this.rootId,
    required this.folder,
    required this.fileName,
    required this.size,
    required this.modified,
    this.bookId,
    this.pageCount,
    this.series,
    this.number,
    this.volume,
    this.year,
    this.publisher,
    this.title,
    this.error,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['location'] = Variable<String>(location);
    map['root_id'] = Variable<int>(rootId);
    map['folder'] = Variable<String>(folder);
    map['file_name'] = Variable<String>(fileName);
    map['size'] = Variable<int>(size);
    map['modified'] = Variable<int>(modified);
    if (!nullToAbsent || bookId != null) {
      map['book_id'] = Variable<String>(bookId);
    }
    if (!nullToAbsent || pageCount != null) {
      map['page_count'] = Variable<int>(pageCount);
    }
    if (!nullToAbsent || series != null) {
      map['series'] = Variable<String>(series);
    }
    if (!nullToAbsent || number != null) {
      map['number'] = Variable<String>(number);
    }
    if (!nullToAbsent || volume != null) {
      map['volume'] = Variable<int>(volume);
    }
    if (!nullToAbsent || year != null) {
      map['year'] = Variable<int>(year);
    }
    if (!nullToAbsent || publisher != null) {
      map['publisher'] = Variable<String>(publisher);
    }
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || error != null) {
      map['error'] = Variable<String>(error);
    }
    return map;
  }

  LibraryEntriesCompanion toCompanion(bool nullToAbsent) {
    return LibraryEntriesCompanion(
      location: Value(location),
      rootId: Value(rootId),
      folder: Value(folder),
      fileName: Value(fileName),
      size: Value(size),
      modified: Value(modified),
      bookId: bookId == null && nullToAbsent
          ? const Value.absent()
          : Value(bookId),
      pageCount: pageCount == null && nullToAbsent
          ? const Value.absent()
          : Value(pageCount),
      series: series == null && nullToAbsent
          ? const Value.absent()
          : Value(series),
      number: number == null && nullToAbsent
          ? const Value.absent()
          : Value(number),
      volume: volume == null && nullToAbsent
          ? const Value.absent()
          : Value(volume),
      year: year == null && nullToAbsent ? const Value.absent() : Value(year),
      publisher: publisher == null && nullToAbsent
          ? const Value.absent()
          : Value(publisher),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      error: error == null && nullToAbsent
          ? const Value.absent()
          : Value(error),
    );
  }

  factory LibraryEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LibraryEntry(
      location: serializer.fromJson<String>(json['location']),
      rootId: serializer.fromJson<int>(json['rootId']),
      folder: serializer.fromJson<String>(json['folder']),
      fileName: serializer.fromJson<String>(json['fileName']),
      size: serializer.fromJson<int>(json['size']),
      modified: serializer.fromJson<int>(json['modified']),
      bookId: serializer.fromJson<String?>(json['bookId']),
      pageCount: serializer.fromJson<int?>(json['pageCount']),
      series: serializer.fromJson<String?>(json['series']),
      number: serializer.fromJson<String?>(json['number']),
      volume: serializer.fromJson<int?>(json['volume']),
      year: serializer.fromJson<int?>(json['year']),
      publisher: serializer.fromJson<String?>(json['publisher']),
      title: serializer.fromJson<String?>(json['title']),
      error: serializer.fromJson<String?>(json['error']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'location': serializer.toJson<String>(location),
      'rootId': serializer.toJson<int>(rootId),
      'folder': serializer.toJson<String>(folder),
      'fileName': serializer.toJson<String>(fileName),
      'size': serializer.toJson<int>(size),
      'modified': serializer.toJson<int>(modified),
      'bookId': serializer.toJson<String?>(bookId),
      'pageCount': serializer.toJson<int?>(pageCount),
      'series': serializer.toJson<String?>(series),
      'number': serializer.toJson<String?>(number),
      'volume': serializer.toJson<int?>(volume),
      'year': serializer.toJson<int?>(year),
      'publisher': serializer.toJson<String?>(publisher),
      'title': serializer.toJson<String?>(title),
      'error': serializer.toJson<String?>(error),
    };
  }

  LibraryEntry copyWith({
    String? location,
    int? rootId,
    String? folder,
    String? fileName,
    int? size,
    int? modified,
    Value<String?> bookId = const Value.absent(),
    Value<int?> pageCount = const Value.absent(),
    Value<String?> series = const Value.absent(),
    Value<String?> number = const Value.absent(),
    Value<int?> volume = const Value.absent(),
    Value<int?> year = const Value.absent(),
    Value<String?> publisher = const Value.absent(),
    Value<String?> title = const Value.absent(),
    Value<String?> error = const Value.absent(),
  }) => LibraryEntry(
    location: location ?? this.location,
    rootId: rootId ?? this.rootId,
    folder: folder ?? this.folder,
    fileName: fileName ?? this.fileName,
    size: size ?? this.size,
    modified: modified ?? this.modified,
    bookId: bookId.present ? bookId.value : this.bookId,
    pageCount: pageCount.present ? pageCount.value : this.pageCount,
    series: series.present ? series.value : this.series,
    number: number.present ? number.value : this.number,
    volume: volume.present ? volume.value : this.volume,
    year: year.present ? year.value : this.year,
    publisher: publisher.present ? publisher.value : this.publisher,
    title: title.present ? title.value : this.title,
    error: error.present ? error.value : this.error,
  );
  LibraryEntry copyWithCompanion(LibraryEntriesCompanion data) {
    return LibraryEntry(
      location: data.location.present ? data.location.value : this.location,
      rootId: data.rootId.present ? data.rootId.value : this.rootId,
      folder: data.folder.present ? data.folder.value : this.folder,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      size: data.size.present ? data.size.value : this.size,
      modified: data.modified.present ? data.modified.value : this.modified,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      pageCount: data.pageCount.present ? data.pageCount.value : this.pageCount,
      series: data.series.present ? data.series.value : this.series,
      number: data.number.present ? data.number.value : this.number,
      volume: data.volume.present ? data.volume.value : this.volume,
      year: data.year.present ? data.year.value : this.year,
      publisher: data.publisher.present ? data.publisher.value : this.publisher,
      title: data.title.present ? data.title.value : this.title,
      error: data.error.present ? data.error.value : this.error,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LibraryEntry(')
          ..write('location: $location, ')
          ..write('rootId: $rootId, ')
          ..write('folder: $folder, ')
          ..write('fileName: $fileName, ')
          ..write('size: $size, ')
          ..write('modified: $modified, ')
          ..write('bookId: $bookId, ')
          ..write('pageCount: $pageCount, ')
          ..write('series: $series, ')
          ..write('number: $number, ')
          ..write('volume: $volume, ')
          ..write('year: $year, ')
          ..write('publisher: $publisher, ')
          ..write('title: $title, ')
          ..write('error: $error')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    location,
    rootId,
    folder,
    fileName,
    size,
    modified,
    bookId,
    pageCount,
    series,
    number,
    volume,
    year,
    publisher,
    title,
    error,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LibraryEntry &&
          other.location == this.location &&
          other.rootId == this.rootId &&
          other.folder == this.folder &&
          other.fileName == this.fileName &&
          other.size == this.size &&
          other.modified == this.modified &&
          other.bookId == this.bookId &&
          other.pageCount == this.pageCount &&
          other.series == this.series &&
          other.number == this.number &&
          other.volume == this.volume &&
          other.year == this.year &&
          other.publisher == this.publisher &&
          other.title == this.title &&
          other.error == this.error);
}

class LibraryEntriesCompanion extends UpdateCompanion<LibraryEntry> {
  final Value<String> location;
  final Value<int> rootId;
  final Value<String> folder;
  final Value<String> fileName;
  final Value<int> size;
  final Value<int> modified;
  final Value<String?> bookId;
  final Value<int?> pageCount;
  final Value<String?> series;
  final Value<String?> number;
  final Value<int?> volume;
  final Value<int?> year;
  final Value<String?> publisher;
  final Value<String?> title;
  final Value<String?> error;
  final Value<int> rowid;
  const LibraryEntriesCompanion({
    this.location = const Value.absent(),
    this.rootId = const Value.absent(),
    this.folder = const Value.absent(),
    this.fileName = const Value.absent(),
    this.size = const Value.absent(),
    this.modified = const Value.absent(),
    this.bookId = const Value.absent(),
    this.pageCount = const Value.absent(),
    this.series = const Value.absent(),
    this.number = const Value.absent(),
    this.volume = const Value.absent(),
    this.year = const Value.absent(),
    this.publisher = const Value.absent(),
    this.title = const Value.absent(),
    this.error = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LibraryEntriesCompanion.insert({
    required String location,
    required int rootId,
    required String folder,
    required String fileName,
    required int size,
    required int modified,
    this.bookId = const Value.absent(),
    this.pageCount = const Value.absent(),
    this.series = const Value.absent(),
    this.number = const Value.absent(),
    this.volume = const Value.absent(),
    this.year = const Value.absent(),
    this.publisher = const Value.absent(),
    this.title = const Value.absent(),
    this.error = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : location = Value(location),
       rootId = Value(rootId),
       folder = Value(folder),
       fileName = Value(fileName),
       size = Value(size),
       modified = Value(modified);
  static Insertable<LibraryEntry> custom({
    Expression<String>? location,
    Expression<int>? rootId,
    Expression<String>? folder,
    Expression<String>? fileName,
    Expression<int>? size,
    Expression<int>? modified,
    Expression<String>? bookId,
    Expression<int>? pageCount,
    Expression<String>? series,
    Expression<String>? number,
    Expression<int>? volume,
    Expression<int>? year,
    Expression<String>? publisher,
    Expression<String>? title,
    Expression<String>? error,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (location != null) 'location': location,
      if (rootId != null) 'root_id': rootId,
      if (folder != null) 'folder': folder,
      if (fileName != null) 'file_name': fileName,
      if (size != null) 'size': size,
      if (modified != null) 'modified': modified,
      if (bookId != null) 'book_id': bookId,
      if (pageCount != null) 'page_count': pageCount,
      if (series != null) 'series': series,
      if (number != null) 'number': number,
      if (volume != null) 'volume': volume,
      if (year != null) 'year': year,
      if (publisher != null) 'publisher': publisher,
      if (title != null) 'title': title,
      if (error != null) 'error': error,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LibraryEntriesCompanion copyWith({
    Value<String>? location,
    Value<int>? rootId,
    Value<String>? folder,
    Value<String>? fileName,
    Value<int>? size,
    Value<int>? modified,
    Value<String?>? bookId,
    Value<int?>? pageCount,
    Value<String?>? series,
    Value<String?>? number,
    Value<int?>? volume,
    Value<int?>? year,
    Value<String?>? publisher,
    Value<String?>? title,
    Value<String?>? error,
    Value<int>? rowid,
  }) {
    return LibraryEntriesCompanion(
      location: location ?? this.location,
      rootId: rootId ?? this.rootId,
      folder: folder ?? this.folder,
      fileName: fileName ?? this.fileName,
      size: size ?? this.size,
      modified: modified ?? this.modified,
      bookId: bookId ?? this.bookId,
      pageCount: pageCount ?? this.pageCount,
      series: series ?? this.series,
      number: number ?? this.number,
      volume: volume ?? this.volume,
      year: year ?? this.year,
      publisher: publisher ?? this.publisher,
      title: title ?? this.title,
      error: error ?? this.error,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (rootId.present) {
      map['root_id'] = Variable<int>(rootId.value);
    }
    if (folder.present) {
      map['folder'] = Variable<String>(folder.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (modified.present) {
      map['modified'] = Variable<int>(modified.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (pageCount.present) {
      map['page_count'] = Variable<int>(pageCount.value);
    }
    if (series.present) {
      map['series'] = Variable<String>(series.value);
    }
    if (number.present) {
      map['number'] = Variable<String>(number.value);
    }
    if (volume.present) {
      map['volume'] = Variable<int>(volume.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (publisher.present) {
      map['publisher'] = Variable<String>(publisher.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LibraryEntriesCompanion(')
          ..write('location: $location, ')
          ..write('rootId: $rootId, ')
          ..write('folder: $folder, ')
          ..write('fileName: $fileName, ')
          ..write('size: $size, ')
          ..write('modified: $modified, ')
          ..write('bookId: $bookId, ')
          ..write('pageCount: $pageCount, ')
          ..write('series: $series, ')
          ..write('number: $number, ')
          ..write('volume: $volume, ')
          ..write('year: $year, ')
          ..write('publisher: $publisher, ')
          ..write('title: $title, ')
          ..write('error: $error, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PairedDevicesTable extends PairedDevices
    with TableInfo<$PairedDevicesTable, PairedDevice> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PairedDevicesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tokenHashMeta = const VerificationMeta(
    'tokenHash',
  );
  @override
  late final GeneratedColumn<String> tokenHash = GeneratedColumn<String>(
    'token_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _addedMeta = const VerificationMeta('added');
  @override
  late final GeneratedColumn<DateTime> added = GeneratedColumn<DateTime>(
    'added',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSeenMeta = const VerificationMeta(
    'lastSeen',
  );
  @override
  late final GeneratedColumn<DateTime> lastSeen = GeneratedColumn<DateTime>(
    'last_seen',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, tokenHash, added, lastSeen];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'paired_devices';
  @override
  VerificationContext validateIntegrity(
    Insertable<PairedDevice> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('token_hash')) {
      context.handle(
        _tokenHashMeta,
        tokenHash.isAcceptableOrUnknown(data['token_hash']!, _tokenHashMeta),
      );
    } else if (isInserting) {
      context.missing(_tokenHashMeta);
    }
    if (data.containsKey('added')) {
      context.handle(
        _addedMeta,
        added.isAcceptableOrUnknown(data['added']!, _addedMeta),
      );
    } else if (isInserting) {
      context.missing(_addedMeta);
    }
    if (data.containsKey('last_seen')) {
      context.handle(
        _lastSeenMeta,
        lastSeen.isAcceptableOrUnknown(data['last_seen']!, _lastSeenMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PairedDevice map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PairedDevice(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      tokenHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}token_hash'],
      )!,
      added: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added'],
      )!,
      lastSeen: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_seen'],
      ),
    );
  }

  @override
  $PairedDevicesTable createAlias(String alias) {
    return $PairedDevicesTable(attachedDatabase, alias);
  }
}

class PairedDevice extends DataClass implements Insertable<PairedDevice> {
  final int id;
  final String name;

  /// SHA-256 of the device's token (the token itself isn't kept).
  final String tokenHash;
  final DateTime added;
  final DateTime? lastSeen;
  const PairedDevice({
    required this.id,
    required this.name,
    required this.tokenHash,
    required this.added,
    this.lastSeen,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['token_hash'] = Variable<String>(tokenHash);
    map['added'] = Variable<DateTime>(added);
    if (!nullToAbsent || lastSeen != null) {
      map['last_seen'] = Variable<DateTime>(lastSeen);
    }
    return map;
  }

  PairedDevicesCompanion toCompanion(bool nullToAbsent) {
    return PairedDevicesCompanion(
      id: Value(id),
      name: Value(name),
      tokenHash: Value(tokenHash),
      added: Value(added),
      lastSeen: lastSeen == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSeen),
    );
  }

  factory PairedDevice.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PairedDevice(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      tokenHash: serializer.fromJson<String>(json['tokenHash']),
      added: serializer.fromJson<DateTime>(json['added']),
      lastSeen: serializer.fromJson<DateTime?>(json['lastSeen']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'tokenHash': serializer.toJson<String>(tokenHash),
      'added': serializer.toJson<DateTime>(added),
      'lastSeen': serializer.toJson<DateTime?>(lastSeen),
    };
  }

  PairedDevice copyWith({
    int? id,
    String? name,
    String? tokenHash,
    DateTime? added,
    Value<DateTime?> lastSeen = const Value.absent(),
  }) => PairedDevice(
    id: id ?? this.id,
    name: name ?? this.name,
    tokenHash: tokenHash ?? this.tokenHash,
    added: added ?? this.added,
    lastSeen: lastSeen.present ? lastSeen.value : this.lastSeen,
  );
  PairedDevice copyWithCompanion(PairedDevicesCompanion data) {
    return PairedDevice(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      tokenHash: data.tokenHash.present ? data.tokenHash.value : this.tokenHash,
      added: data.added.present ? data.added.value : this.added,
      lastSeen: data.lastSeen.present ? data.lastSeen.value : this.lastSeen,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PairedDevice(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('tokenHash: $tokenHash, ')
          ..write('added: $added, ')
          ..write('lastSeen: $lastSeen')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, tokenHash, added, lastSeen);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PairedDevice &&
          other.id == this.id &&
          other.name == this.name &&
          other.tokenHash == this.tokenHash &&
          other.added == this.added &&
          other.lastSeen == this.lastSeen);
}

class PairedDevicesCompanion extends UpdateCompanion<PairedDevice> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> tokenHash;
  final Value<DateTime> added;
  final Value<DateTime?> lastSeen;
  const PairedDevicesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.tokenHash = const Value.absent(),
    this.added = const Value.absent(),
    this.lastSeen = const Value.absent(),
  });
  PairedDevicesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String tokenHash,
    required DateTime added,
    this.lastSeen = const Value.absent(),
  }) : name = Value(name),
       tokenHash = Value(tokenHash),
       added = Value(added);
  static Insertable<PairedDevice> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? tokenHash,
    Expression<DateTime>? added,
    Expression<DateTime>? lastSeen,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (tokenHash != null) 'token_hash': tokenHash,
      if (added != null) 'added': added,
      if (lastSeen != null) 'last_seen': lastSeen,
    });
  }

  PairedDevicesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? tokenHash,
    Value<DateTime>? added,
    Value<DateTime?>? lastSeen,
  }) {
    return PairedDevicesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      tokenHash: tokenHash ?? this.tokenHash,
      added: added ?? this.added,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (tokenHash.present) {
      map['token_hash'] = Variable<String>(tokenHash.value);
    }
    if (added.present) {
      map['added'] = Variable<DateTime>(added.value);
    }
    if (lastSeen.present) {
      map['last_seen'] = Variable<DateTime>(lastSeen.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PairedDevicesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('tokenHash: $tokenHash, ')
          ..write('added: $added, ')
          ..write('lastSeen: $lastSeen')
          ..write(')'))
        .toString();
  }
}

class $RemoteLibrariesTable extends RemoteLibraries
    with TableInfo<$RemoteLibrariesTable, RemoteLibrary> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RemoteLibrariesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addressMeta = const VerificationMeta(
    'address',
  );
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tokenMeta = const VerificationMeta('token');
  @override
  late final GeneratedColumn<String> token = GeneratedColumn<String>(
    'token',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncedUntilMeta = const VerificationMeta(
    'syncedUntil',
  );
  @override
  late final GeneratedColumn<DateTime> syncedUntil = GeneratedColumn<DateTime>(
    'synced_until',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sentUntilMeta = const VerificationMeta(
    'sentUntil',
  );
  @override
  late final GeneratedColumn<DateTime> sentUntil = GeneratedColumn<DateTime>(
    'sent_until',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    serverId,
    name,
    address,
    token,
    syncedUntil,
    sentUntil,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'remote_libraries';
  @override
  VerificationContext validateIntegrity(
    Insertable<RemoteLibrary> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    } else if (isInserting) {
      context.missing(_serverIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['address']!, _addressMeta),
      );
    } else if (isInserting) {
      context.missing(_addressMeta);
    }
    if (data.containsKey('token')) {
      context.handle(
        _tokenMeta,
        token.isAcceptableOrUnknown(data['token']!, _tokenMeta),
      );
    } else if (isInserting) {
      context.missing(_tokenMeta);
    }
    if (data.containsKey('synced_until')) {
      context.handle(
        _syncedUntilMeta,
        syncedUntil.isAcceptableOrUnknown(
          data['synced_until']!,
          _syncedUntilMeta,
        ),
      );
    }
    if (data.containsKey('sent_until')) {
      context.handle(
        _sentUntilMeta,
        sentUntil.isAcceptableOrUnknown(data['sent_until']!, _sentUntilMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RemoteLibrary map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RemoteLibrary(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      )!,
      token: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}token'],
      )!,
      syncedUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_until'],
      ),
      sentUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}sent_until'],
      ),
    );
  }

  @override
  $RemoteLibrariesTable createAlias(String alias) {
    return $RemoteLibrariesTable(attachedDatabase, alias);
  }
}

class RemoteLibrary extends DataClass implements Insertable<RemoteLibrary> {
  final int id;

  /// The computer's library ID (it stays when the address changes).
  final String serverId;
  final String name;

  /// `host:port` last reached at.
  final String address;
  final String token;

  /// The server's time of the last sync (changes after it are fetched
  /// next), or null before the first.
  final DateTime? syncedUntil;

  /// This device's time when it last sent its changes (changes after it go
  /// next), or null before the first.
  final DateTime? sentUntil;
  const RemoteLibrary({
    required this.id,
    required this.serverId,
    required this.name,
    required this.address,
    required this.token,
    this.syncedUntil,
    this.sentUntil,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['server_id'] = Variable<String>(serverId);
    map['name'] = Variable<String>(name);
    map['address'] = Variable<String>(address);
    map['token'] = Variable<String>(token);
    if (!nullToAbsent || syncedUntil != null) {
      map['synced_until'] = Variable<DateTime>(syncedUntil);
    }
    if (!nullToAbsent || sentUntil != null) {
      map['sent_until'] = Variable<DateTime>(sentUntil);
    }
    return map;
  }

  RemoteLibrariesCompanion toCompanion(bool nullToAbsent) {
    return RemoteLibrariesCompanion(
      id: Value(id),
      serverId: Value(serverId),
      name: Value(name),
      address: Value(address),
      token: Value(token),
      syncedUntil: syncedUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedUntil),
      sentUntil: sentUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(sentUntil),
    );
  }

  factory RemoteLibrary.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RemoteLibrary(
      id: serializer.fromJson<int>(json['id']),
      serverId: serializer.fromJson<String>(json['serverId']),
      name: serializer.fromJson<String>(json['name']),
      address: serializer.fromJson<String>(json['address']),
      token: serializer.fromJson<String>(json['token']),
      syncedUntil: serializer.fromJson<DateTime?>(json['syncedUntil']),
      sentUntil: serializer.fromJson<DateTime?>(json['sentUntil']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'serverId': serializer.toJson<String>(serverId),
      'name': serializer.toJson<String>(name),
      'address': serializer.toJson<String>(address),
      'token': serializer.toJson<String>(token),
      'syncedUntil': serializer.toJson<DateTime?>(syncedUntil),
      'sentUntil': serializer.toJson<DateTime?>(sentUntil),
    };
  }

  RemoteLibrary copyWith({
    int? id,
    String? serverId,
    String? name,
    String? address,
    String? token,
    Value<DateTime?> syncedUntil = const Value.absent(),
    Value<DateTime?> sentUntil = const Value.absent(),
  }) => RemoteLibrary(
    id: id ?? this.id,
    serverId: serverId ?? this.serverId,
    name: name ?? this.name,
    address: address ?? this.address,
    token: token ?? this.token,
    syncedUntil: syncedUntil.present ? syncedUntil.value : this.syncedUntil,
    sentUntil: sentUntil.present ? sentUntil.value : this.sentUntil,
  );
  RemoteLibrary copyWithCompanion(RemoteLibrariesCompanion data) {
    return RemoteLibrary(
      id: data.id.present ? data.id.value : this.id,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      name: data.name.present ? data.name.value : this.name,
      address: data.address.present ? data.address.value : this.address,
      token: data.token.present ? data.token.value : this.token,
      syncedUntil: data.syncedUntil.present
          ? data.syncedUntil.value
          : this.syncedUntil,
      sentUntil: data.sentUntil.present ? data.sentUntil.value : this.sentUntil,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RemoteLibrary(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('name: $name, ')
          ..write('address: $address, ')
          ..write('token: $token, ')
          ..write('syncedUntil: $syncedUntil, ')
          ..write('sentUntil: $sentUntil')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, serverId, name, address, token, syncedUntil, sentUntil);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RemoteLibrary &&
          other.id == this.id &&
          other.serverId == this.serverId &&
          other.name == this.name &&
          other.address == this.address &&
          other.token == this.token &&
          other.syncedUntil == this.syncedUntil &&
          other.sentUntil == this.sentUntil);
}

class RemoteLibrariesCompanion extends UpdateCompanion<RemoteLibrary> {
  final Value<int> id;
  final Value<String> serverId;
  final Value<String> name;
  final Value<String> address;
  final Value<String> token;
  final Value<DateTime?> syncedUntil;
  final Value<DateTime?> sentUntil;
  const RemoteLibrariesCompanion({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    this.name = const Value.absent(),
    this.address = const Value.absent(),
    this.token = const Value.absent(),
    this.syncedUntil = const Value.absent(),
    this.sentUntil = const Value.absent(),
  });
  RemoteLibrariesCompanion.insert({
    this.id = const Value.absent(),
    required String serverId,
    required String name,
    required String address,
    required String token,
    this.syncedUntil = const Value.absent(),
    this.sentUntil = const Value.absent(),
  }) : serverId = Value(serverId),
       name = Value(name),
       address = Value(address),
       token = Value(token);
  static Insertable<RemoteLibrary> custom({
    Expression<int>? id,
    Expression<String>? serverId,
    Expression<String>? name,
    Expression<String>? address,
    Expression<String>? token,
    Expression<DateTime>? syncedUntil,
    Expression<DateTime>? sentUntil,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverId != null) 'server_id': serverId,
      if (name != null) 'name': name,
      if (address != null) 'address': address,
      if (token != null) 'token': token,
      if (syncedUntil != null) 'synced_until': syncedUntil,
      if (sentUntil != null) 'sent_until': sentUntil,
    });
  }

  RemoteLibrariesCompanion copyWith({
    Value<int>? id,
    Value<String>? serverId,
    Value<String>? name,
    Value<String>? address,
    Value<String>? token,
    Value<DateTime?>? syncedUntil,
    Value<DateTime?>? sentUntil,
  }) {
    return RemoteLibrariesCompanion(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      name: name ?? this.name,
      address: address ?? this.address,
      token: token ?? this.token,
      syncedUntil: syncedUntil ?? this.syncedUntil,
      sentUntil: sentUntil ?? this.sentUntil,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (token.present) {
      map['token'] = Variable<String>(token.value);
    }
    if (syncedUntil.present) {
      map['synced_until'] = Variable<DateTime>(syncedUntil.value);
    }
    if (sentUntil.present) {
      map['sent_until'] = Variable<DateTime>(sentUntil.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RemoteLibrariesCompanion(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('name: $name, ')
          ..write('address: $address, ')
          ..write('token: $token, ')
          ..write('syncedUntil: $syncedUntil, ')
          ..write('sentUntil: $sentUntil')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $BooksTable books = $BooksTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $LibraryRootsTable libraryRoots = $LibraryRootsTable(this);
  late final $LibraryEntriesTable libraryEntries = $LibraryEntriesTable(this);
  late final $PairedDevicesTable pairedDevices = $PairedDevicesTable(this);
  late final $RemoteLibrariesTable remoteLibraries = $RemoteLibrariesTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    books,
    settings,
    libraryRoots,
    libraryEntries,
    pairedDevices,
    remoteLibraries,
  ];
}

typedef $$BooksTableCreateCompanionBuilder = BooksCompanion Function({
  required String id,
  required String path,
  required String title,
  required int pageCount,
  Value<int> currentPage,
  required DateTime lastOpened,
  Value<Uint8List?> cover,
  Value<String?> series,
  Value<String?> number,
  Value<int?> year,
  Value<String?> writer,
  Value<String?> artist,
  Value<String?> summary,
  Value<bool?> rightToLeft,
  Value<String?> publisher,
  Value<bool> finished,
  Value<DateTime?> progressUpdated,
  Value<String?> pageSizes,
  Value<String?> fitMode,
  Value<String?> layoutMode,
  Value<bool?> coverAlone,
  Value<int> rowid,
});
typedef $$BooksTableUpdateCompanionBuilder = BooksCompanion Function({
  Value<String> id,
  Value<String> path,
  Value<String> title,
  Value<int> pageCount,
  Value<int> currentPage,
  Value<DateTime> lastOpened,
  Value<Uint8List?> cover,
  Value<String?> series,
  Value<String?> number,
  Value<int?> year,
  Value<String?> writer,
  Value<String?> artist,
  Value<String?> summary,
  Value<bool?> rightToLeft,
  Value<String?> publisher,
  Value<bool> finished,
  Value<DateTime?> progressUpdated,
  Value<String?> pageSizes,
  Value<String?> fitMode,
  Value<String?> layoutMode,
  Value<bool?> coverAlone,
  Value<int> rowid,
});

class $$BooksTableFilterComposer extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pageCount => $composableBuilder(
    column: $table.pageCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currentPage => $composableBuilder(
    column: $table.currentPage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastOpened => $composableBuilder(
    column: $table.lastOpened,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get cover => $composableBuilder(
    column: $table.cover,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get series => $composableBuilder(
    column: $table.series,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get number => $composableBuilder(
    column: $table.number,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get writer => $composableBuilder(
    column: $table.writer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get rightToLeft => $composableBuilder(
    column: $table.rightToLeft,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get publisher => $composableBuilder(
    column: $table.publisher,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get finished => $composableBuilder(
    column: $table.finished,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get progressUpdated => $composableBuilder(
    column: $table.progressUpdated,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pageSizes => $composableBuilder(
    column: $table.pageSizes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fitMode => $composableBuilder(
    column: $table.fitMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get layoutMode => $composableBuilder(
    column: $table.layoutMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get coverAlone => $composableBuilder(
    column: $table.coverAlone,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BooksTableOrderingComposer
    extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pageCount => $composableBuilder(
    column: $table.pageCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentPage => $composableBuilder(
    column: $table.currentPage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastOpened => $composableBuilder(
    column: $table.lastOpened,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get cover => $composableBuilder(
    column: $table.cover,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get series => $composableBuilder(
    column: $table.series,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get number => $composableBuilder(
    column: $table.number,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get writer => $composableBuilder(
    column: $table.writer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get rightToLeft => $composableBuilder(
    column: $table.rightToLeft,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get publisher => $composableBuilder(
    column: $table.publisher,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get finished => $composableBuilder(
    column: $table.finished,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get progressUpdated => $composableBuilder(
    column: $table.progressUpdated,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pageSizes => $composableBuilder(
    column: $table.pageSizes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fitMode => $composableBuilder(
    column: $table.fitMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get layoutMode => $composableBuilder(
    column: $table.layoutMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get coverAlone => $composableBuilder(
    column: $table.coverAlone,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BooksTableAnnotationComposer
    extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get pageCount =>
      $composableBuilder(column: $table.pageCount, builder: (column) => column);

  GeneratedColumn<int> get currentPage => $composableBuilder(
    column: $table.currentPage,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastOpened => $composableBuilder(
    column: $table.lastOpened,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get cover =>
      $composableBuilder(column: $table.cover, builder: (column) => column);

  GeneratedColumn<String> get series =>
      $composableBuilder(column: $table.series, builder: (column) => column);

  GeneratedColumn<String> get number =>
      $composableBuilder(column: $table.number, builder: (column) => column);

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<String> get writer =>
      $composableBuilder(column: $table.writer, builder: (column) => column);

  GeneratedColumn<String> get artist =>
      $composableBuilder(column: $table.artist, builder: (column) => column);

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumn<bool> get rightToLeft => $composableBuilder(
    column: $table.rightToLeft,
    builder: (column) => column,
  );

  GeneratedColumn<String> get publisher =>
      $composableBuilder(column: $table.publisher, builder: (column) => column);

  GeneratedColumn<bool> get finished =>
      $composableBuilder(column: $table.finished, builder: (column) => column);

  GeneratedColumn<DateTime> get progressUpdated => $composableBuilder(
    column: $table.progressUpdated,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pageSizes =>
      $composableBuilder(column: $table.pageSizes, builder: (column) => column);

  GeneratedColumn<String> get fitMode =>
      $composableBuilder(column: $table.fitMode, builder: (column) => column);

  GeneratedColumn<String> get layoutMode => $composableBuilder(
    column: $table.layoutMode,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get coverAlone => $composableBuilder(
    column: $table.coverAlone,
    builder: (column) => column,
  );
}

class $$BooksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BooksTable,
          Book,
          $$BooksTableFilterComposer,
          $$BooksTableOrderingComposer,
          $$BooksTableAnnotationComposer,
          $$BooksTableCreateCompanionBuilder,
          $$BooksTableUpdateCompanionBuilder,
          (Book, BaseReferences<_$AppDatabase, $BooksTable, Book>),
          Book,
          PrefetchHooks Function()
        > {
  $$BooksTableTableManager(_$AppDatabase db, $BooksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BooksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BooksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BooksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int> pageCount = const Value.absent(),
                Value<int> currentPage = const Value.absent(),
                Value<DateTime> lastOpened = const Value.absent(),
                Value<Uint8List?> cover = const Value.absent(),
                Value<String?> series = const Value.absent(),
                Value<String?> number = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<String?> writer = const Value.absent(),
                Value<String?> artist = const Value.absent(),
                Value<String?> summary = const Value.absent(),
                Value<bool?> rightToLeft = const Value.absent(),
                Value<String?> publisher = const Value.absent(),
                Value<bool> finished = const Value.absent(),
                Value<DateTime?> progressUpdated = const Value.absent(),
                Value<String?> pageSizes = const Value.absent(),
                Value<String?> fitMode = const Value.absent(),
                Value<String?> layoutMode = const Value.absent(),
                Value<bool?> coverAlone = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BooksCompanion(
                id: id,
                path: path,
                title: title,
                pageCount: pageCount,
                currentPage: currentPage,
                lastOpened: lastOpened,
                cover: cover,
                series: series,
                number: number,
                year: year,
                writer: writer,
                artist: artist,
                summary: summary,
                rightToLeft: rightToLeft,
                publisher: publisher,
                finished: finished,
                progressUpdated: progressUpdated,
                pageSizes: pageSizes,
                fitMode: fitMode,
                layoutMode: layoutMode,
                coverAlone: coverAlone,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String path,
                required String title,
                required int pageCount,
                Value<int> currentPage = const Value.absent(),
                required DateTime lastOpened,
                Value<Uint8List?> cover = const Value.absent(),
                Value<String?> series = const Value.absent(),
                Value<String?> number = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<String?> writer = const Value.absent(),
                Value<String?> artist = const Value.absent(),
                Value<String?> summary = const Value.absent(),
                Value<bool?> rightToLeft = const Value.absent(),
                Value<String?> publisher = const Value.absent(),
                Value<bool> finished = const Value.absent(),
                Value<DateTime?> progressUpdated = const Value.absent(),
                Value<String?> pageSizes = const Value.absent(),
                Value<String?> fitMode = const Value.absent(),
                Value<String?> layoutMode = const Value.absent(),
                Value<bool?> coverAlone = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BooksCompanion.insert(
                id: id,
                path: path,
                title: title,
                pageCount: pageCount,
                currentPage: currentPage,
                lastOpened: lastOpened,
                cover: cover,
                series: series,
                number: number,
                year: year,
                writer: writer,
                artist: artist,
                summary: summary,
                rightToLeft: rightToLeft,
                publisher: publisher,
                finished: finished,
                progressUpdated: progressUpdated,
                pageSizes: pageSizes,
                fitMode: fitMode,
                layoutMode: layoutMode,
                coverAlone: coverAlone,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BooksTable, Book>(table),
                  BaseReferences<_$AppDatabase, $BooksTable, Book>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BooksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BooksTable,
      Book,
      $$BooksTableFilterComposer,
      $$BooksTableOrderingComposer,
      $$BooksTableAnnotationComposer,
      $$BooksTableCreateCompanionBuilder,
      $$BooksTableUpdateCompanionBuilder,
      (Book, BaseReferences<_$AppDatabase, $BooksTable, Book>),
      Book,
      PrefetchHooks Function()
    >;
typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          Setting,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
          Setting,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SettingsTable, Setting>(table),
                  BaseReferences<_$AppDatabase, $SettingsTable, Setting>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      Setting,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
      Setting,
      PrefetchHooks Function()
    >;
typedef $$LibraryRootsTableCreateCompanionBuilder =
    LibraryRootsCompanion Function({
      Value<int> id,
      required String location,
      required String name,
    });
typedef $$LibraryRootsTableUpdateCompanionBuilder =
    LibraryRootsCompanion Function({
      Value<int> id,
      Value<String> location,
      Value<String> name,
    });

class $$LibraryRootsTableFilterComposer
    extends Composer<_$AppDatabase, $LibraryRootsTable> {
  $$LibraryRootsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LibraryRootsTableOrderingComposer
    extends Composer<_$AppDatabase, $LibraryRootsTable> {
  $$LibraryRootsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LibraryRootsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LibraryRootsTable> {
  $$LibraryRootsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);
}

class $$LibraryRootsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LibraryRootsTable,
          LibraryRoot,
          $$LibraryRootsTableFilterComposer,
          $$LibraryRootsTableOrderingComposer,
          $$LibraryRootsTableAnnotationComposer,
          $$LibraryRootsTableCreateCompanionBuilder,
          $$LibraryRootsTableUpdateCompanionBuilder,
          (
            LibraryRoot,
            BaseReferences<_$AppDatabase, $LibraryRootsTable, LibraryRoot>,
          ),
          LibraryRoot,
          PrefetchHooks Function()
        > {
  $$LibraryRootsTableTableManager(_$AppDatabase db, $LibraryRootsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LibraryRootsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LibraryRootsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LibraryRootsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> location = const Value.absent(),
            Value<String> name = const Value.absent(),
          }) => LibraryRootsCompanion(id: id, location: location, name: name),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String location,
                required String name,
              }) => LibraryRootsCompanion.insert(
                id: id,
                location: location,
                name: name,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LibraryRootsTable, LibraryRoot>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LibraryRootsTable,
                    LibraryRoot
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LibraryRootsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LibraryRootsTable,
      LibraryRoot,
      $$LibraryRootsTableFilterComposer,
      $$LibraryRootsTableOrderingComposer,
      $$LibraryRootsTableAnnotationComposer,
      $$LibraryRootsTableCreateCompanionBuilder,
      $$LibraryRootsTableUpdateCompanionBuilder,
      (
        LibraryRoot,
        BaseReferences<_$AppDatabase, $LibraryRootsTable, LibraryRoot>,
      ),
      LibraryRoot,
      PrefetchHooks Function()
    >;
typedef $$LibraryEntriesTableCreateCompanionBuilder =
    LibraryEntriesCompanion Function({
      required String location,
      required int rootId,
      required String folder,
      required String fileName,
      required int size,
      required int modified,
      Value<String?> bookId,
      Value<int?> pageCount,
      Value<String?> series,
      Value<String?> number,
      Value<int?> volume,
      Value<int?> year,
      Value<String?> publisher,
      Value<String?> title,
      Value<String?> error,
      Value<int> rowid,
    });
typedef $$LibraryEntriesTableUpdateCompanionBuilder =
    LibraryEntriesCompanion Function({
      Value<String> location,
      Value<int> rootId,
      Value<String> folder,
      Value<String> fileName,
      Value<int> size,
      Value<int> modified,
      Value<String?> bookId,
      Value<int?> pageCount,
      Value<String?> series,
      Value<String?> number,
      Value<int?> volume,
      Value<int?> year,
      Value<String?> publisher,
      Value<String?> title,
      Value<String?> error,
      Value<int> rowid,
    });

class $$LibraryEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $LibraryEntriesTable> {
  $$LibraryEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rootId => $composableBuilder(
    column: $table.rootId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get folder => $composableBuilder(
    column: $table.folder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get modified => $composableBuilder(
    column: $table.modified,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pageCount => $composableBuilder(
    column: $table.pageCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get series => $composableBuilder(
    column: $table.series,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get number => $composableBuilder(
    column: $table.number,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get volume => $composableBuilder(
    column: $table.volume,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get publisher => $composableBuilder(
    column: $table.publisher,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LibraryEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $LibraryEntriesTable> {
  $$LibraryEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rootId => $composableBuilder(
    column: $table.rootId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get folder => $composableBuilder(
    column: $table.folder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get modified => $composableBuilder(
    column: $table.modified,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pageCount => $composableBuilder(
    column: $table.pageCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get series => $composableBuilder(
    column: $table.series,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get number => $composableBuilder(
    column: $table.number,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get volume => $composableBuilder(
    column: $table.volume,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get publisher => $composableBuilder(
    column: $table.publisher,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LibraryEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LibraryEntriesTable> {
  $$LibraryEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<int> get rootId =>
      $composableBuilder(column: $table.rootId, builder: (column) => column);

  GeneratedColumn<String> get folder =>
      $composableBuilder(column: $table.folder, builder: (column) => column);

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<int> get modified =>
      $composableBuilder(column: $table.modified, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<int> get pageCount =>
      $composableBuilder(column: $table.pageCount, builder: (column) => column);

  GeneratedColumn<String> get series =>
      $composableBuilder(column: $table.series, builder: (column) => column);

  GeneratedColumn<String> get number =>
      $composableBuilder(column: $table.number, builder: (column) => column);

  GeneratedColumn<int> get volume =>
      $composableBuilder(column: $table.volume, builder: (column) => column);

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<String> get publisher =>
      $composableBuilder(column: $table.publisher, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get error =>
      $composableBuilder(column: $table.error, builder: (column) => column);
}

class $$LibraryEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LibraryEntriesTable,
          LibraryEntry,
          $$LibraryEntriesTableFilterComposer,
          $$LibraryEntriesTableOrderingComposer,
          $$LibraryEntriesTableAnnotationComposer,
          $$LibraryEntriesTableCreateCompanionBuilder,
          $$LibraryEntriesTableUpdateCompanionBuilder,
          (
            LibraryEntry,
            BaseReferences<_$AppDatabase, $LibraryEntriesTable, LibraryEntry>,
          ),
          LibraryEntry,
          PrefetchHooks Function()
        > {
  $$LibraryEntriesTableTableManager(
    _$AppDatabase db,
    $LibraryEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LibraryEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LibraryEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LibraryEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> location = const Value.absent(),
                Value<int> rootId = const Value.absent(),
                Value<String> folder = const Value.absent(),
                Value<String> fileName = const Value.absent(),
                Value<int> size = const Value.absent(),
                Value<int> modified = const Value.absent(),
                Value<String?> bookId = const Value.absent(),
                Value<int?> pageCount = const Value.absent(),
                Value<String?> series = const Value.absent(),
                Value<String?> number = const Value.absent(),
                Value<int?> volume = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<String?> publisher = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LibraryEntriesCompanion(
                location: location,
                rootId: rootId,
                folder: folder,
                fileName: fileName,
                size: size,
                modified: modified,
                bookId: bookId,
                pageCount: pageCount,
                series: series,
                number: number,
                volume: volume,
                year: year,
                publisher: publisher,
                title: title,
                error: error,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String location,
                required int rootId,
                required String folder,
                required String fileName,
                required int size,
                required int modified,
                Value<String?> bookId = const Value.absent(),
                Value<int?> pageCount = const Value.absent(),
                Value<String?> series = const Value.absent(),
                Value<String?> number = const Value.absent(),
                Value<int?> volume = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<String?> publisher = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LibraryEntriesCompanion.insert(
                location: location,
                rootId: rootId,
                folder: folder,
                fileName: fileName,
                size: size,
                modified: modified,
                bookId: bookId,
                pageCount: pageCount,
                series: series,
                number: number,
                volume: volume,
                year: year,
                publisher: publisher,
                title: title,
                error: error,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LibraryEntriesTable, LibraryEntry>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LibraryEntriesTable,
                    LibraryEntry
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LibraryEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LibraryEntriesTable,
      LibraryEntry,
      $$LibraryEntriesTableFilterComposer,
      $$LibraryEntriesTableOrderingComposer,
      $$LibraryEntriesTableAnnotationComposer,
      $$LibraryEntriesTableCreateCompanionBuilder,
      $$LibraryEntriesTableUpdateCompanionBuilder,
      (
        LibraryEntry,
        BaseReferences<_$AppDatabase, $LibraryEntriesTable, LibraryEntry>,
      ),
      LibraryEntry,
      PrefetchHooks Function()
    >;
typedef $$PairedDevicesTableCreateCompanionBuilder =
    PairedDevicesCompanion Function({
      Value<int> id,
      required String name,
      required String tokenHash,
      required DateTime added,
      Value<DateTime?> lastSeen,
    });
typedef $$PairedDevicesTableUpdateCompanionBuilder =
    PairedDevicesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> tokenHash,
      Value<DateTime> added,
      Value<DateTime?> lastSeen,
    });

class $$PairedDevicesTableFilterComposer
    extends Composer<_$AppDatabase, $PairedDevicesTable> {
  $$PairedDevicesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tokenHash => $composableBuilder(
    column: $table.tokenHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get added => $composableBuilder(
    column: $table.added,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSeen => $composableBuilder(
    column: $table.lastSeen,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PairedDevicesTableOrderingComposer
    extends Composer<_$AppDatabase, $PairedDevicesTable> {
  $$PairedDevicesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tokenHash => $composableBuilder(
    column: $table.tokenHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get added => $composableBuilder(
    column: $table.added,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSeen => $composableBuilder(
    column: $table.lastSeen,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PairedDevicesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PairedDevicesTable> {
  $$PairedDevicesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get tokenHash =>
      $composableBuilder(column: $table.tokenHash, builder: (column) => column);

  GeneratedColumn<DateTime> get added =>
      $composableBuilder(column: $table.added, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSeen =>
      $composableBuilder(column: $table.lastSeen, builder: (column) => column);
}

class $$PairedDevicesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PairedDevicesTable,
          PairedDevice,
          $$PairedDevicesTableFilterComposer,
          $$PairedDevicesTableOrderingComposer,
          $$PairedDevicesTableAnnotationComposer,
          $$PairedDevicesTableCreateCompanionBuilder,
          $$PairedDevicesTableUpdateCompanionBuilder,
          (
            PairedDevice,
            BaseReferences<_$AppDatabase, $PairedDevicesTable, PairedDevice>,
          ),
          PairedDevice,
          PrefetchHooks Function()
        > {
  $$PairedDevicesTableTableManager(_$AppDatabase db, $PairedDevicesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PairedDevicesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PairedDevicesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PairedDevicesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> tokenHash = const Value.absent(),
                Value<DateTime> added = const Value.absent(),
                Value<DateTime?> lastSeen = const Value.absent(),
              }) => PairedDevicesCompanion(
                id: id,
                name: name,
                tokenHash: tokenHash,
                added: added,
                lastSeen: lastSeen,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String tokenHash,
                required DateTime added,
                Value<DateTime?> lastSeen = const Value.absent(),
              }) => PairedDevicesCompanion.insert(
                id: id,
                name: name,
                tokenHash: tokenHash,
                added: added,
                lastSeen: lastSeen,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PairedDevicesTable, PairedDevice>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $PairedDevicesTable,
                    PairedDevice
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PairedDevicesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PairedDevicesTable,
      PairedDevice,
      $$PairedDevicesTableFilterComposer,
      $$PairedDevicesTableOrderingComposer,
      $$PairedDevicesTableAnnotationComposer,
      $$PairedDevicesTableCreateCompanionBuilder,
      $$PairedDevicesTableUpdateCompanionBuilder,
      (
        PairedDevice,
        BaseReferences<_$AppDatabase, $PairedDevicesTable, PairedDevice>,
      ),
      PairedDevice,
      PrefetchHooks Function()
    >;
typedef $$RemoteLibrariesTableCreateCompanionBuilder =
    RemoteLibrariesCompanion Function({
      Value<int> id,
      required String serverId,
      required String name,
      required String address,
      required String token,
      Value<DateTime?> syncedUntil,
      Value<DateTime?> sentUntil,
    });
typedef $$RemoteLibrariesTableUpdateCompanionBuilder =
    RemoteLibrariesCompanion Function({
      Value<int> id,
      Value<String> serverId,
      Value<String> name,
      Value<String> address,
      Value<String> token,
      Value<DateTime?> syncedUntil,
      Value<DateTime?> sentUntil,
    });

class $$RemoteLibrariesTableFilterComposer
    extends Composer<_$AppDatabase, $RemoteLibrariesTable> {
  $$RemoteLibrariesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get token => $composableBuilder(
    column: $table.token,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedUntil => $composableBuilder(
    column: $table.syncedUntil,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get sentUntil => $composableBuilder(
    column: $table.sentUntil,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RemoteLibrariesTableOrderingComposer
    extends Composer<_$AppDatabase, $RemoteLibrariesTable> {
  $$RemoteLibrariesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get token => $composableBuilder(
    column: $table.token,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedUntil => $composableBuilder(
    column: $table.syncedUntil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get sentUntil => $composableBuilder(
    column: $table.sentUntil,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RemoteLibrariesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RemoteLibrariesTable> {
  $$RemoteLibrariesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<String> get token =>
      $composableBuilder(column: $table.token, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedUntil => $composableBuilder(
    column: $table.syncedUntil,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get sentUntil =>
      $composableBuilder(column: $table.sentUntil, builder: (column) => column);
}

class $$RemoteLibrariesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RemoteLibrariesTable,
          RemoteLibrary,
          $$RemoteLibrariesTableFilterComposer,
          $$RemoteLibrariesTableOrderingComposer,
          $$RemoteLibrariesTableAnnotationComposer,
          $$RemoteLibrariesTableCreateCompanionBuilder,
          $$RemoteLibrariesTableUpdateCompanionBuilder,
          (
            RemoteLibrary,
            BaseReferences<_$AppDatabase, $RemoteLibrariesTable, RemoteLibrary>,
          ),
          RemoteLibrary,
          PrefetchHooks Function()
        > {
  $$RemoteLibrariesTableTableManager(
    _$AppDatabase db,
    $RemoteLibrariesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RemoteLibrariesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RemoteLibrariesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RemoteLibrariesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> serverId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> address = const Value.absent(),
                Value<String> token = const Value.absent(),
                Value<DateTime?> syncedUntil = const Value.absent(),
                Value<DateTime?> sentUntil = const Value.absent(),
              }) => RemoteLibrariesCompanion(
                id: id,
                serverId: serverId,
                name: name,
                address: address,
                token: token,
                syncedUntil: syncedUntil,
                sentUntil: sentUntil,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String serverId,
                required String name,
                required String address,
                required String token,
                Value<DateTime?> syncedUntil = const Value.absent(),
                Value<DateTime?> sentUntil = const Value.absent(),
              }) => RemoteLibrariesCompanion.insert(
                id: id,
                serverId: serverId,
                name: name,
                address: address,
                token: token,
                syncedUntil: syncedUntil,
                sentUntil: sentUntil,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RemoteLibrariesTable, RemoteLibrary>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $RemoteLibrariesTable,
                    RemoteLibrary
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RemoteLibrariesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RemoteLibrariesTable,
      RemoteLibrary,
      $$RemoteLibrariesTableFilterComposer,
      $$RemoteLibrariesTableOrderingComposer,
      $$RemoteLibrariesTableAnnotationComposer,
      $$RemoteLibrariesTableCreateCompanionBuilder,
      $$RemoteLibrariesTableUpdateCompanionBuilder,
      (
        RemoteLibrary,
        BaseReferences<_$AppDatabase, $RemoteLibrariesTable, RemoteLibrary>,
      ),
      RemoteLibrary,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$BooksTableTableManager get books =>
      $$BooksTableTableManager(_db, _db.books);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$LibraryRootsTableTableManager get libraryRoots =>
      $$LibraryRootsTableTableManager(_db, _db.libraryRoots);
  $$LibraryEntriesTableTableManager get libraryEntries =>
      $$LibraryEntriesTableTableManager(_db, _db.libraryEntries);
  $$PairedDevicesTableTableManager get pairedDevices =>
      $$PairedDevicesTableTableManager(_db, _db.pairedDevices);
  $$RemoteLibrariesTableTableManager get remoteLibraries =>
      $$RemoteLibrariesTableTableManager(_db, _db.remoteLibraries);
}

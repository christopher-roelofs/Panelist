import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../app/providers.dart';
import '../core/imaging/thumbnail.dart';
import '../core/metadata/comic_info.dart';
import '../core/sources/open_source.dart';
import '../core/sources/page_source.dart';
import '../data/book_extensions.dart';
import '../data/database.dart';
import 'reader_screen.dart';

/// Opens [path] in the reader at its saved page, recording it in recents.
///
/// With [replace], the reader takes the place of the current route (used to
/// go from one issue straight to the next).
Future<void> openInReader(
  BuildContext context,
  WidgetRef ref,
  String path, {
  bool replace = false,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final navigator = Navigator.of(context);
  final db = ref.read(databaseProvider);
  final PageSource source;
  try {
    source = await openSource(path);
  } on Exception catch (e) {
    messenger?.showSnackBar(SnackBar(content: Text('$e')));
    return;
  }
  var book = await db.recordOpened(
    id: source.id,
    path: path.contains('://') ? path : p.absolute(path),
    title: source.title,
    pageCount: source.pageCount,
  );
  // Refresh ComicInfo metadata on every open (it's small and may change).
  try {
    final xml = await source.readComicInfo();
    final info = xml == null ? null : ComicInfo.parse(xml);
    if (info != null) {
      await db.saveMetadata(source.id, metadataFrom(info));
      book = (await db.book(source.id))!;
    }
  } on Object {
    // Metadata is optional.
  }
  if (book.cover == null) unawaited(_saveCover(db, source));
  final route = MaterialPageRoute<void>(
    builder: (_) =>
        ReaderScreen(source: source, book: book, initialPage: book.currentPage),
  );
  if (replace) {
    await navigator.pushReplacement(route);
  } else {
    await navigator.push(route);
  }
}

Future<void> _saveCover(AppDatabase db, PageSource source) async {
  try {
    final png = await renderThumbnail(source);
    if (png != null) await db.saveCover(source.id, png);
  } on Object {
    // A missing cover is cosmetic; the reader reports real page errors.
  }
}

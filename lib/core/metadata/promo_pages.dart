import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import '../../platform/comic_files.dart';
import '../sources/cbz_page_source.dart';
import 'comic_info.dart';

/// The pages at the end of a comic that look added rather than part of it,
/// such as a scan group's promo image.
///
/// A comic's pages are named alike (`Saga 001-000.jpg` … `Saga 001-023.jpg`,
/// or `00001.jpg` …): with digits stood in for, most share one pattern. The
/// last pages that don't (`zSoU-Nerd.jpg`, named to sort last) are the
/// candidates. Only the end is looked at, so an oddly named cover at the
/// start is never taken, and nothing is taken when the pages have no clear
/// common pattern (at least [minShare] of them, and at least [minPages]
/// pages). No names are special.
List<String> promoPages(
  List<String> pages, {
  double minShare = 0.75,
  int minPages = 4,
  int maxPromos = 3,
}) {
  if (pages.length < minPages) return const [];
  String pattern(String name) => p
      .basenameWithoutExtension(name)
      .toLowerCase()
      .replaceAll(RegExp(r'\d+'), '#');
  final counts = <String, int>{};
  for (final n in pages) {
    counts.update(pattern(n), (c) => c + 1, ifAbsent: () => 1);
  }
  final (top, count) = counts.entries
      .map((e) => (e.key, e.value))
      .reduce((a, b) => b.$2 > a.$2 ? b : a);
  // A pattern without a number isn't a page sequence.
  if (!top.contains('#') || count < pages.length * minShare) return const [];
  final out = <String>[];
  for (final n in pages.reversed) {
    if (pattern(n) == top) break;
    out.add(n);
  }
  return out.length > maxPromos ? const [] : out.reversed.toList();
}

/// Why pages couldn't be removed.
class PageRemovalException implements Exception {
  PageRemovalException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Removes the page entries named [remove] from the CBZ at [location] (a
/// path, or an Android library document) and returns its new book ID
/// (`file:` plus the pages' fingerprint).
///
/// Everything else is copied as it is. ComicInfo's PageCount and `<Pages>`
/// are updated to match. The new archive is written apart, checked (its
/// pages are exactly the old ones minus [remove], in order), and only then
/// replaces the original. Runs in a worker isolate.
Future<({String oldId, String newId})> removePagesFromCbz(
  String location,
  Set<String> remove,
) {
  final name = ComicFiles.nameOf(location);
  return ComicFiles.rewrite(
    location,
    (source, target) =>
        Isolate.run(() => _remove(source, target, name, remove)),
  );
}

({String oldId, String newId}) _remove(
  String path,
  String target,
  String name,
  Set<String> remove,
) {
  final temp = File(target);
  final input = InputFileStream(path);
  try {
    final Archive original;
    final decoder = ZipDecoder();
    try {
      original = decoder.decodeStream(input);
    } on Object {
      throw PageRemovalException('Not a CBZ (ZIP) file: $name');
    }
    final pages = cbzPages(original);
    final pageNames = [for (final f in pages) f.name];
    if (!remove.every(pageNames.contains)) {
      throw PageRemovalException('Those pages aren’t in the comic any more');
    }
    final kept = [
      for (final f in pages)
        if (!remove.contains(f.name)) f,
    ];
    if (kept.isEmpty) {
      throw PageRemovalException('That would remove every page');
    }
    final oldId = 'file:${cbzPagesFingerprint(pages)}';
    final newId = 'file:${cbzPagesFingerprint(kept)}';
    // Indices (in reading order) of the removed pages, for ComicInfo.
    final removedIndices = {
      for (final (i, n) in pageNames.indexed)
        if (remove.contains(n)) i,
    };

    final comment = decoder.directory.zipFileComment;
    final updated = Archive()..comment = comment.isEmpty ? null : comment;
    for (final f in original.files) {
      if (remove.contains(f.name)) continue;
      if (f.isFile && ComicInfo.isComicInfoName(f.name)) {
        final xml = _withoutPages(
          utf8.decode(f.readBytes()!, allowMalformed: true),
          removedIndices,
          kept.length,
        );
        if (xml != null) {
          updated.add(ArchiveFile.string(f.name, xml));
          continue;
        }
      }
      updated.add(f);
    }

    final out = OutputFileStream(temp.path);
    try {
      ZipEncoder().encodeStream(updated, out);
    } finally {
      out.closeSync();
    }

    final check = InputFileStream(temp.path);
    try {
      final after = cbzPages(ZipDecoder().decodeStream(check));
      if (after.length != kept.length ||
          'file:${cbzPagesFingerprint(after)}' != newId) {
        throw PageRemovalException('The saved copy’s pages didn’t match');
      }
    } finally {
      check.closeSync();
    }
    input.closeSync();
    return (oldId: oldId, newId: newId);
  } catch (e) {
    input.closeSync();
    if (temp.existsSync()) temp.deleteSync();
    if (e is PageRemovalException) rethrow;
    throw PageRemovalException('Couldn’t save $name: $e');
  }
}

/// [xml] with PageCount set to [count] and the `<Page>` entries for
/// [removed] dropped (the rest renumbered), or null if it has neither or
/// can't be read (it's then kept as it was).
String? _withoutPages(String xml, Set<int> removed, int count) {
  final XmlDocument doc;
  try {
    doc = XmlDocument.parse(xml);
  } on XmlException {
    return null;
  }
  final root = doc.rootElement;
  var changed = false;
  for (final e in root.findElements('PageCount')) {
    e.innerText = '$count';
    changed = true;
  }
  for (final list in root.findElements('Pages')) {
    for (final page in list.findElements('Page').toList()) {
      final image = int.tryParse(page.getAttribute('Image') ?? '');
      if (image == null) continue;
      if (removed.contains(image)) {
        page.remove();
      } else {
        final shift = removed.where((r) => r < image).length;
        if (shift > 0) page.setAttribute('Image', '${image - shift}');
      }
      changed = true;
    }
  }
  if (!changed) return null;
  return doc.toXmlString();
}

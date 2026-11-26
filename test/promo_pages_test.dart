import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panelist/core/metadata/promo_pages.dart';
import 'package:panelist/core/sources/cbz_page_source.dart';
import 'package:path/path.dart' as p;

List<String> seq(String prefix, int n, {int pad = 3, String ext = 'jpg'}) => [
  for (var i = 0; i < n; i++) '$prefix${'$i'.padLeft(pad, '0')}.$ext',
];

void main() {
  group('promoPages', () {
    test('a trailing page named unlike the rest', () {
      final pages = [
        ...seq('Hellboy in Hell - Nothing But Blood 02-', 23, pad: 4),
        'zSoU-Nerd.jpg',
      ];
      expect(promoPages(pages), ['zSoU-Nerd.jpg']);
    });

    test('folders and case don\'t matter; several at the end', () {
      final pages = [
        ...seq('Saga/Saga 001-', 20),
        'Saga/zzz-Empire.JPG',
        'Saga/zGGtag.png',
      ];
      expect(promoPages(pages), ['Saga/zzz-Empire.JPG', 'Saga/zGGtag.png']);
    });

    test('nothing when every page fits', () {
      expect(promoPages(seq('Batwoman 009-', 24)), isEmpty);
      expect(promoPages(seq('', 30, pad: 5)), isEmpty);
    });

    test('an oddly named cover at the start is kept', () {
      expect(promoPages(['cover.jpg', ...seq('Page ', 20)]), isEmpty);
    });

    test('nothing without a clear pattern, or too few pages', () {
      expect(
        promoPages(['front.jpg', 'inside.jpg', 'back.jpg', 'extra.jpg']),
        isEmpty,
      );
      expect(promoPages([...seq('a', 2), 'promo.jpg']), isEmpty);
      // Half the pages follow another pattern: no clear sequence.
      expect(promoPages([...seq('a-', 10), ...seq('b_x', 10)]), isEmpty);
    });

    test('a long run at the end is not taken as promos', () {
      final extras = ['pinup a.jpg', 'pinup b.jpg', 'sketch.jpg', 'back.jpg'];
      expect(promoPages([...seq('Story ', 20), ...extras]), isEmpty);
    });
  });

  group('removePagesFromCbz', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('panelist_promo'));
    tearDown(() => dir.deleteSync(recursive: true));

    String cbz(List<String> pages, {String? info, String? comment}) {
      final a = Archive()..comment = comment;
      for (final (i, n) in pages.indexed) {
        a.addFile(ArchiveFile.bytes(n, Uint8List.fromList([i, 1, 2, 3])));
      }
      if (info != null) a.addFile(ArchiveFile.string('ComicInfo.xml', info));
      final path = p.join(dir.path, 'c.cbz');
      File(path).writeAsBytesSync(ZipEncoder().encodeBytes(a));
      return path;
    }

    Archive read(String path) =>
        ZipDecoder().decodeBytes(File(path).readAsBytesSync());

    test('drops the pages, keeps the rest, updates ComicInfo', () async {
      final pages = [...seq('p', 5), 'zPromo.jpg'];
      final path = cbz(
        pages,
        comment: 'signed',
        info:
            '<ComicInfo><Series>S</Series><PageCount>6</PageCount><Pages>'
            '<Page Image="0" Type="FrontCover"/><Page Image="4"/>'
            '<Page Image="5"/></Pages></ComicInfo>',
      );
      final before = 'file:${cbzPagesFingerprint(cbzPages(read(path)))}';
      final ids = await removePagesFromCbz(path, {'zPromo.jpg'});
      final after = read(path);
      expect(ids.oldId, before);
      expect([for (final f in cbzPages(after)) f.name], seq('p', 5));
      expect(ids.newId, 'file:${cbzPagesFingerprint(cbzPages(after))}');
      expect(ids.newId, isNot(ids.oldId));
      final xml = utf8.decode(after.findFile('ComicInfo.xml')!.readBytes()!);
      expect(xml, contains('<PageCount>5</PageCount>'));
      expect(xml, contains('<Page Image="4"/>'));
      expect(xml, isNot(contains('Image="5"')));
      expect(xml, contains('<Series>S</Series>'));
      expect(dir.listSync(), hasLength(1)); // no temp left behind
    });

    test('renumbers ComicInfo pages after a removed one', () async {
      final path = cbz(
        seq('p', 4),
        info:
            '<ComicInfo><Pages><Page Image="2"/><Page Image="3"/>'
            '</Pages></ComicInfo>',
      );
      await removePagesFromCbz(path, {'p001.jpg'});
      final xml = utf8.decode(
        read(path).findFile('ComicInfo.xml')!.readBytes()!,
      );
      expect(xml, contains('<Page Image="1"/><Page Image="2"/>'));
    });

    test('refuses pages that aren\'t there, or every page', () async {
      final path = cbz(seq('p', 2));
      final bytes = File(path).readAsBytesSync();
      await expectLater(
        removePagesFromCbz(path, {'nope.jpg'}),
        throwsA(isA<PageRemovalException>()),
      );
      await expectLater(
        removePagesFromCbz(path, {'p000.jpg', 'p001.jpg'}),
        throwsA(isA<PageRemovalException>()),
      );
      expect(File(path).readAsBytesSync(), bytes);
    });
  });
}

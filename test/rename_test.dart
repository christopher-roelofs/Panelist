import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panelist/core/metadata/comic_info_document.dart';
import 'package:panelist/data/database.dart';
import 'package:panelist/library/library_model.dart';
import 'package:panelist/library/publisher_aliases.dart';
import 'package:panelist/library/rename_comics.dart';
import 'package:panelist/library/rename_template.dart';
import 'package:path/path.dart' as p;

void main() {
  group('renderTemplate', () {
    final saga = {
      'series': 'Saga',
      'number': '1',
      'year': '2012',
      'volume': '2012',
      'publisher': 'Image',
      'title': 'Chapter One',
    };

    test('the default pads the number', () {
      expect(renderTemplate(defaultRenameTemplate, saga), 'Saga 001 (2012)');
      expect(
        renderTemplate(defaultRenameTemplate, {...saga, 'number': '1.5'}),
        'Saga 001.5 (2012)',
      );
      expect(
        renderTemplate(defaultRenameTemplate, {...saga, 'number': '2509'}),
        'Saga 2509 (2012)',
      );
    });

    test('folders', () {
      expect(
        renderTemplate(
          '{publisher}/{series} ({volume})/{series} #{number:3}',
          saga,
        ),
        'Image/Saga (2012)/Saga #001',
      );
      // No publisher: that folder is left out.
      expect(
        renderTemplate('{publisher}/{series}/{series} {number}', {
          ...saga,
          'publisher': null,
        }),
        'Saga/Saga 1',
      );
    });

    test('missing values drop out with their brackets and separators', () {
      expect(
        renderTemplate(defaultRenameTemplate, {...saga, 'year': null}),
        'Saga 001',
      );
      expect(
        renderTemplate('{series} #{number} - {title}', {
          ...saga,
          'number': null,
          'title': '',
        }),
        'Saga',
      );
      expect(
        renderTemplate('{series} [{publisher}] {number}', {
          ...saga,
          'publisher': null,
        }),
        'Saga 1',
      );
      expect(renderTemplate('{title}', {...saga, 'title': null}), isNull);
    });

    test('values are made safe for file names', () {
      expect(
        renderTemplate('{series} {number}', {
          'series': 'Hellboy in Hell: Nothing But Blood',
          'number': '2',
        }),
        'Hellboy in Hell - Nothing But Blood 2',
      );
      expect(
        renderTemplate('{series}', {'series': 'AC/DC: "Live"? <1>*'}),
        'AC-DC - Live 1',
      );
      expect(renderTemplate('{series}', {'series': 'Vol. 1...'}), 'Vol. 1');
    });

    test('long titles are shortened at a word', () {
      final t = renderTemplate('{series} {number} - {title:30}', {
        'series': '2000 AD',
        'number': '2510',
        'title':
            'The New Future, Part Nine; Ghosted: Book Two, Part Ten; '
            'Hungry City, Part 10',
      });
      expect(t, '2000 AD 2510 - The New Future, Part Nine');
    });

    test('checkTemplate', () {
      expect(checkTemplate(defaultRenameTemplate), isNull);
      expect(checkTemplate('{publisher}/{series} {number}'), isNull);
      expect(checkTemplate(''), isNotNull);
      expect(checkTemplate('{seris}'), contains('Unknown'));
      expect(checkTemplate('{number:x}'), isNotNull);
      expect(checkTemplate('{series'), contains('Unmatched'));
      expect(checkTemplate('{series}/fixed'), isNotNull);
    });
  });

  group('planRenames and renameComics', () {
    late Directory dir;
    late AppDatabase db;
    setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
    setUp(() {
      dir = Directory.systemTemp.createTempSync('panelist_rename');
      db = AppDatabase(NativeDatabase.memory());
    });
    tearDown(() async {
      await db.close();
      dir.deleteSync(recursive: true);
    });

    LibraryComic comic(
      String relative, {
      String? series,
      String? number,
      int? year,
      String? publisher,
      String? bookId,
    }) {
      final path = p.join(dir.path, relative);
      File(path)
        ..createSync(recursive: true)
        ..writeAsStringSync(relative);
      return LibraryComic(
        LibraryEntry(
          location: path,
          rootId: 1,
          folder: p.dirname(relative) == '.' ? '' : p.dirname(relative),
          fileName: p.basename(relative),
          size: 1,
          modified: 0,
          bookId: bookId,
          series: series,
          number: number,
          year: year,
          publisher: publisher,
        ),
        null,
      );
    }

    test('renames in place, skipping clashes and existing files', () {
      final a = comic(
        'week/Saga 1.cbz',
        series: 'Saga',
        number: '1',
        year: 2012,
      );
      final b = comic(
        'week/saga_001.CBZ',
        series: 'Saga',
        number: '1',
        year: 2012,
      );
      final c = comic('week/Saga 002 (2012).cbz');
      final d = comic('week/x.cbz', series: 'Batman', number: '3', year: 2016);
      comic('week/Batman 003 (2016).cbz');
      final plans = planRenames(
        [a, b, c, d],
        defaultRenameTemplate,
        (_) => dir.path,
      );
      expect(
        [for (final r in plans) r.state],
        [
          RenameState.clash,
          RenameState.clash,
          RenameState.same,
          RenameState.exists,
        ],
      );
    });

    test(
      'organises into folders, keeps progress, removes empty folders',
      () async {
        final a = comic(
          '2026.11.18 Image Week/Saga 1.cbz',
          series: 'Saga',
          number: '1',
          year: 2012,
          publisher: 'Image',
          bookId: 'file:abc',
        );
        await db.moveBook('none', 'none', ''); // no-op on a missing book
        await db
            .into(db.books)
            .insert(
              BooksCompanion.insert(
                id: 'file:abc',
                path: a.location,
                title: 'Saga',
                pageCount: 20,
                lastOpened: DateTime(2026),
              ),
            );
        final plans = planRenames(
          [a],
          '{publisher}/{series}/{series} {number:3} ({year})',
          (_) => dir.path,
        );
        expect(plans.single.state, RenameState.rename);
        final r = await renameComics(db, plans, roots: {dir.path});
        expect(r.renamed, 1);
        final target = p.join(dir.path, 'Image', 'Saga', 'Saga 001 (2012).cbz');
        expect(File(target).existsSync(), isTrue);
        expect(File(a.location).existsSync(), isFalse);
        expect(
          Directory(p.join(dir.path, '2026.11.18 Image Week')).existsSync(),
          isFalse,
        );
        expect(Directory(dir.path).existsSync(), isTrue);
        expect((await db.book('file:abc'))!.path, target);
      },
    );

    test('a change of case only is a rename, not a clash', () {
      final a = comic(
        'saga 001 (2012).cbz',
        series: 'Saga',
        number: '1',
        year: 2012,
      );
      final plans = planRenames(
        [a],
        defaultRenameTemplate,
        (_) => dir.path,
        exists: (path) => path.toLowerCase() == a.location.toLowerCase(),
      );
      expect(plans.single.state, RenameState.rename);
    });
    test('organizing the library: nested folders emptied, Stop keeps what '
        'moved', () async {
      final a = comic(
        'old/week/a/Saga 1.cbz',
        series: 'Saga',
        number: '1',
        year: 2012,
        publisher: 'Image',
      );
      final b = comic(
        'old/week/b/Saga 2.cbz',
        series: 'Saga',
        number: '2',
        year: 2012,
        publisher: 'Image',
      );
      final keep = File(p.join(dir.path, 'old', 'notes.txt'))
        ..writeAsStringSync('mine');
      final plans = planRenames(
        [a, b],
        organizeLayouts.first.template,
        (_) => dir.path,
      );
      expect(plans.map((r) => p.relative(r.target!, from: dir.path)), [
        'Image/Saga/Saga 001 (2012).cbz',
        'Image/Saga/Saga 002 (2012).cbz',
      ]);
      var calls = 0;
      final r = await renameComics(
        db,
        plans,
        roots: {dir.path},
        shouldStop: () => calls++ > 0,
      );
      expect(r.renamed, 1);
      expect(File(plans.first.target!).existsSync(), isTrue);
      expect(File(b.location).existsSync(), isTrue);
      // a's folder went; b's is still in use; "old" keeps the notes.
      expect(Directory(p.dirname(a.location)).existsSync(), isFalse);
      expect(Directory(p.dirname(b.location)).existsSync(), isTrue);
      expect(keep.existsSync(), isTrue);

      final rest = await renameComics(db, [plans.last], roots: {dir.path});
      expect(rest.renamed, 1);
      expect(Directory(p.join(dir.path, 'old', 'week')).existsSync(), isFalse);
      expect(Directory(p.join(dir.path, 'old')).existsSync(), isTrue);
    });

    test('one library folder', () async {
      await db.addRoot('/a', 'a');
      await db.addRoot('/b', 'b');
      await db.setLibraryFolder('/c', 'c');
      expect([for (final r in await db.roots()) r.location], ['/c']);
      await db.setLibraryFolder('/c', 'c');
      expect(await db.roots(), hasLength(1));
    });

    test('withDetails uses what was just saved', () {
      final c = comic('x.cbz', series: 'Old', number: '9');
      final doc = ComicInfoDocument.parse(
        '<ComicInfo><Series>Saga</Series><Number>1</Number><Year>2012</Year>'
        '<Publisher>Image</Publisher></ComicInfo>',
      );
      final aliases = const PublisherAliases().withRule(
        'Image',
        'Image Comics',
      );
      final w = withDetails(c, doc, aliases: aliases);
      expect(
        renderTemplate(organizeLayouts.first.template, templateValues(w)),
        'Image Comics/Saga/Saga 001 (2012)',
      );
    });
  });
}

import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panelist/core/sources/archive_page_source.dart';
import 'package:panelist/core/sources/cbz_page_source.dart';
import 'package:panelist/core/sources/fd_file.dart';
import 'package:panelist/core/sources/fingerprint.dart';
import 'package:panelist/core/sources/pdf_page_source.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

final _open = DynamicLibrary.process()
    .lookupFunction<
      Int Function(Pointer<Utf8>, Int),
      int Function(Pointer<Utf8>, int)
    >('open');
final _close = DynamicLibrary.process()
    .lookupFunction<Int Function(Int), int Function(int)>('close');

/// Mimics an Android SAF document: an open descriptor whose
/// `/proc/self/fd/<n>` path cannot be reopened (the file is made
/// unreadable after opening, so any reopen fails with EACCES).
String openAsFd(String path) {
  final c = path.toNativeUtf8();
  final fd = _open(c, 0 /* O_RDONLY */);
  malloc.free(c);
  expect(fd, greaterThanOrEqualTo(0));
  addTearDown(() => _close(fd));
  File(path).statSync(); // exists
  Process.runSync('chmod', ['000', path]);
  addTearDown(() => Process.runSync('chmod', ['644', path]));
  return '/proc/self/fd/$fd';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('panelist_fd');
    ArchivePageSource.cacheRoot = Directory(p.join(dir.path, 'cache'));
    Pdfrx.cacheDirectoryPath ??= Directory.systemTemp.path;
  });
  tearDown(() => dir.deleteSync(recursive: true));

  final big = Uint8List.fromList(List.generate(200000, (i) => i % 13));

  String write(String name, List<int> bytes) {
    final path = p.join(dir.path, name);
    File(path).writeAsBytesSync(bytes);
    return path;
  }

  Archive pages() => Archive()
    ..addFile(ArchiveFile.bytes('2.jpg', [2]))
    ..addFile(ArchiveFile.bytes('1.png', big));

  test('fdOfPath', () {
    expect(fdOfPath('/proc/self/fd/42'), 42);
    expect(fdOfPath('/proc/self/fd/42/x'), isNull);
    expect(fdOfPath('/home/me/book.cbz'), isNull);
  });

  test('fingerprint and magic read through the descriptor', () {
    final path = write('a.bin', big);
    final expected = fileFingerprint(path);
    final fdPath = openAsFd(path);
    expect(() => File(fdPath).readAsBytesSync(), throwsA(anything));
    expect(fileFingerprint(fdPath), expected);
    expect(readMagic(fdPath, 3), big.sublist(0, 3));
  });

  test('CBZ', () async {
    final fdPath = openAsFd(write('x.cbz', ZipEncoder().encodeBytes(pages())));
    var closed = false;
    final src = await CbzPageSource.open(
      fdPath,
      name: 'Saga 01.cbz',
      onClose: () async => closed = true,
    );
    expect(src.title, 'Saga 01');
    expect(await src.page(0), big);
    expect(await src.page(1), [2]);
    await src.close();
    expect(closed, isTrue);
  });

  test('tar via libarchive', () async {
    final fdPath = openAsFd(write('x.cbt', TarEncoder().encodeBytes(pages())));
    final src = await ArchivePageSource.open(fdPath, name: 'Book.cbt');
    addTearDown(src.close);
    expect(src.title, 'Book');
    // Two passes (list, extract) both start from the beginning.
    expect(await src.page(0), big);
    expect(await src.page(1), [2]);
  });

  test('PDF', () async {
    // Smallest valid one-page PDF.
    const objs = [
      '<< /Type /Catalog /Pages 2 0 R >>',
      '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 300] >>',
    ];
    final b = StringBuffer('%PDF-1.4\n');
    final offsets = <int>[];
    for (var i = 0; i < objs.length; i++) {
      offsets.add(b.length);
      b.write('${i + 1} 0 obj\n${objs[i]}\nendobj\n');
    }
    final xref = b.length;
    b.write('xref\n0 4\n0000000000 65535 f \n');
    for (final o in offsets) {
      b.write('${o.toString().padLeft(10, '0')} 00000 n \n');
    }
    b.write('trailer\n<< /Size 4 /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n');

    final fdPath = openAsFd(write('x.pdf', b.toString().codeUnits));
    final src = await PdfPageSource.open(fdPath, name: 'Doc.pdf');
    addTearDown(src.close);
    expect(src.title, 'Doc');
    expect(src.pageCount, 1);
    final img = await src.render(0, 20, 30);
    expect((img.width, img.height), (20, 30));
  });
}

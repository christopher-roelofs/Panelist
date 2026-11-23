import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:panelist/core/sources/open_source.dart';
import 'package:panelist/core/sources/pdf_page_source.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

/// A minimal valid two-page PDF: a 200x300pt page and a 600x300pt spread.
String _pdf() {
  final objs = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R 4 0 R] /Count 2 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 300] >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 600 300] >>',
  ];
  final b = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[];
  for (var i = 0; i < objs.length; i++) {
    offsets.add(b.length);
    b.write('${i + 1} 0 obj\n${objs[i]}\nendobj\n');
  }
  final xref = b.length;
  b.write('xref\n0 ${objs.length + 1}\n0000000000 65535 f \n');
  for (final o in offsets) {
    b.write('${o.toString().padLeft(10, '0')} 00000 n \n');
  }
  b.write(
    'trailer\n<< /Size ${objs.length + 1} /Root 1 0 R >>\n'
    'startxref\n$xref\n%%EOF\n',
  );
  return b.toString();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('panelist_pdf');
    // Skip pdfrx's path_provider lookup, which has no plugin in tests.
    Pdfrx.cacheDirectoryPath ??= Directory.systemTemp.path;
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('opens, reports page sizes and renders at the requested size', () async {
    final path = p.join(dir.path, 'Comic.pdf');
    File(path).writeAsStringSync(_pdf());

    final src = await openSource(path) as PdfPageSource;
    addTearDown(src.close);
    expect(src.title, 'Comic');
    expect(src.pageCount, 2);
    expect(src.pageSize(0), const Size(200, 300));
    expect(src.pageSize(1), const Size(600, 300));
    expect(src.id, startsWith('file:'));

    final img = await src.render(1, 120, 60);
    expect((img.width, img.height), (120, 60));
    img.dispose();
  });
}

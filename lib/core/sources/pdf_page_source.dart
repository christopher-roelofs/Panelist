import 'dart:isolate';
import 'dart:ui' as ui;

import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

import 'fingerprint.dart';
import 'page_source.dart';

/// A PDF comic, rendered with PDFium (via pdfrx) at whatever resolution the
/// reader asks for, so zooming stays sharp.
class PdfPageSource implements RenderedPageSource {
  PdfPageSource._(this.path, this.id, this._doc);

  final String path;
  @override
  final String id;
  final PdfDocument _doc;
  bool _closed = false;

  static bool _initialized = false;

  static Future<PdfPageSource> open(String path) async {
    if (!_initialized) {
      await pdfrxFlutterInitialize();
      _initialized = true;
    }
    final name = p.basename(path);
    final PdfDocument doc;
    try {
      doc = await PdfDocument.openFile(path);
    } on PdfPasswordException {
      throw UnsupportedSourceException(
        'Password-protected PDFs are not supported yet: $name',
      );
    } on Exception catch (e) {
      throw UnsupportedSourceException('Not a readable PDF: $name ($e)');
    }
    if (doc.pages.isEmpty) {
      await doc.dispose();
      throw UnsupportedSourceException('This PDF has no pages: $name');
    }
    final fp = await Isolate.run(() => fileFingerprint(path));
    return PdfPageSource._(path, 'file:$fp', doc);
  }

  @override
  String get title => p.basenameWithoutExtension(path);

  @override
  int get pageCount => _doc.pages.length;

  @override
  ui.Size pageSize(int index) {
    final page = _doc.pages[index];
    return ui.Size(page.width, page.height);
  }

  @override
  Future<List<ui.Size?>> probePageSizes() async => [
    for (var i = 0; i < pageCount; i++) pageSize(i),
  ];

  @override
  Future<String?> readComicInfo() async => null;

  @override
  Future<ui.Image> render(int index, int width, int height) async {
    if (_closed) throw StateError('Source is closed');
    final image = await _doc.pages[index].render(
      width: width,
      height: height,
      fullWidth: width.toDouble(),
      fullHeight: height.toDouble(),
      backgroundColor: 0xFFFFFFFF,
    );
    if (image == null) throw Exception('Failed to render page ${index + 1}');
    try {
      return await image.createImage();
    } finally {
      image.dispose();
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _doc.dispose();
  }
}

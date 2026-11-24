import 'dart:isolate';
import 'dart:ui' as ui;

import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

import 'fd_file.dart';
import 'fingerprint.dart';
import 'page_source.dart';

/// A PDF comic, rendered with PDFium (via pdfrx) at whatever resolution the
/// reader asks for, so zooming stays sharp.
class PdfPageSource implements RenderedPageSource {
  PdfPageSource._(this.path, this.fileName, this._onClose, this.id, this._doc);

  final String path;

  /// The comic's file name, for display.
  final String fileName;
  final Future<void> Function()? _onClose;
  @override
  final String id;
  final PdfDocument _doc;
  bool _closed = false;

  static bool _initialized = false;

  /// [name] is the file name to show (defaults to [path]'s basename, which
  /// is meaningless for e.g. `/proc/self/fd/N`); [onClose] runs after
  /// [close] has released everything.
  static Future<PdfPageSource> open(
    String path, {
    String? name,
    Future<void> Function()? onClose,
  }) async {
    if (!_initialized) {
      await pdfrxFlutterInitialize();
      _initialized = true;
    }
    final fileName = name ?? p.basename(path);
    final PdfDocument doc;
    try {
      final fd = fdOfPath(path);
      if (fd == null) {
        doc = await PdfDocument.openFile(path);
      } else {
        // Can't be reopened by path on Android; read the descriptor.
        final reader = FdReader(fd);
        doc = await PdfDocument.openCustom(
          read: (buffer, position, size) =>
              reader.readInto(buffer, position, size),
          fileSize: reader.length,
          sourceName: 'fd:$fd:$fileName',
          onDispose: reader.dispose,
        );
      }
    } on PdfPasswordException {
      throw UnsupportedSourceException(
        'Password-protected PDFs are not supported yet: $fileName',
      );
    } on Exception catch (e) {
      throw UnsupportedSourceException('Not a readable PDF: $fileName ($e)');
    }
    if (doc.pages.isEmpty) {
      await doc.dispose();
      throw UnsupportedSourceException('This PDF has no pages: $fileName');
    }
    final fp = await Isolate.run(() => fileFingerprint(path));
    return PdfPageSource._(path, fileName, onClose, 'file:$fp', doc);
  }

  @override
  String get title => p.basenameWithoutExtension(fileName);

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
    await _onClose?.call();
  }
}

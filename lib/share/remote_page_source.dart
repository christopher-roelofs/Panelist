import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:path/path.dart' as p;

import '../core/sources/page_source.dart';
import 'share_client.dart';

/// A comic read straight from a computer's shared library: pages come over
/// the network as the reader asks for them (PDF pages rendered there).
class RemotePageSource implements EncodedPageSource {
  RemotePageSource._(this._client, this.id, this.title, this._sizes);

  /// Opens book [id] (named [fileName]) through [client].
  static Future<RemotePageSource> open(
    ShareClient client,
    String id, {
    required String fileName,
  }) async {
    final pages = await client.pages(id);
    return RemotePageSource._(
      client,
      id,
      p.basenameWithoutExtension(fileName),
      [
        for (final s in pages.sizes)
          s == null ? null : ui.Size(s.$1.toDouble(), s.$2.toDouble()),
      ],
    );
  }

  final ShareClient _client;
  final List<ui.Size?> _sizes;

  @override
  final String id;

  @override
  final String title;

  @override
  int get pageCount => _sizes.length;

  @override
  Future<List<ui.Size?>> probePageSizes() async => _sizes;

  @override
  Future<Uint8List> page(int index) => _client.page(id, index);

  /// The computer's library holds the details.
  @override
  Future<String?> readComicInfo() async => null;

  @override
  Future<void> close() async {}
}

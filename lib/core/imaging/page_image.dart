import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../sources/page_source.dart';

/// [ImageProvider] for one page of a [PageSource].
///
/// Cached by (source id, page index). Always wrap it with [pageImageAt] so
/// pages are decoded at display resolution instead of full scan resolution —
/// a 4000px page decoded at full size costs ~64MB of RAM.
@immutable
class PageImage extends ImageProvider<PageImage> {
  const PageImage(this.source, this.index);

  final PageSource source;
  final int index;

  @override
  Future<PageImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(PageImage key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _load(decode),
      scale: 1.0,
      debugLabel: '${source.title} p${index + 1}',
    );
  }

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    final bytes = await source.page(index);
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    return decode(buffer);
  }

  @override
  bool operator ==(Object other) =>
      other is PageImage &&
      other.source.id == source.id &&
      other.index == index;

  @override
  int get hashCode => Object.hash(source.id, index);
}

/// Page [index] decoded to fit inside [target] physical pixels
/// (aspect ratio kept, never upscaled).
ImageProvider pageImageAt(PageSource source, int index, Size target) {
  return ResizeImage(
    PageImage(source, index),
    width: target.width.round(),
    height: target.height.round(),
    policy: ResizeImagePolicy.fit,
  );
}

/// Rounds a physical display size up to a coarse bucket so that small window
/// resizes don't trigger re-decoding every page.
Size bucketDecodeSize(Size physical) {
  const step = 256.0;
  double up(double v) => (v / step).ceil() * step;
  return Size(up(physical.width), up(physical.height));
}

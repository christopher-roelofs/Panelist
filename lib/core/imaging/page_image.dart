import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../sources/page_source.dart';

/// [ImageProvider] for one page of a [PageSource], at full resolution.
///
/// Cached by (source id, page index). Wrap it in a [ResizeImage] so pages
/// are decoded at display resolution rather than scan resolution: a 4000px
/// page decoded at full size costs ~64MB of RAM.
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

/// Rounds a decode dimension (physical pixels) up to a coarse bucket so
/// small window resizes don't re-decode every page.
int bucketDimension(double physical) {
  const step = 256;
  return ((physical / step).ceil() * step).clamp(step, 1 << 15);
}

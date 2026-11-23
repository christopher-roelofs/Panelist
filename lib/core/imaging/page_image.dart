import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../sources/page_source.dart';

/// The image for page [index] of [source], fitted inside [width] × [height]
/// physical pixels. Either bound may be null (that axis is unconstrained);
/// with both null you get the page's natural resolution.
///
/// Encoded pages are decoded straight to the target size (never upscaled);
/// rendered pages (PDF) are rasterised at exactly that size.
ImageProvider pageImage(
  PageSource source,
  int index, {
  int? width,
  int? height,
}) {
  switch (source) {
    case EncodedPageSource():
      final base = EncodedPageImage(source, index);
      if (width == null && height == null) return base;
      return ResizeImage(
        base,
        width: width,
        height: height,
        policy: width != null && height != null
            ? ResizeImagePolicy.fit
            : ResizeImagePolicy.exact,
      );
    case RenderedPageSource():
      return RenderedPageImage(source, index, width: width, height: height);
  }
}

/// Rounds a decode dimension (physical pixels) up to a coarse bucket so
/// small window resizes don't re-decode every page.
int bucketDimension(double physical) {
  const step = 256;
  return ((physical / step).ceil() * step).clamp(step, 1 << 15);
}

/// [ImageProvider] for one page of an [EncodedPageSource], at full
/// resolution. Cached by (source id, page index).
@immutable
class EncodedPageImage extends ImageProvider<EncodedPageImage> {
  const EncodedPageImage(this.source, this.index);

  final EncodedPageSource source;
  final int index;

  @override
  Future<EncodedPageImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    EncodedPageImage key,
    ImageDecoderCallback decode,
  ) {
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
      other is EncodedPageImage &&
      other.source.id == source.id &&
      other.index == index;

  @override
  int get hashCode => Object.hash(source.id, index);
}

/// [ImageProvider] for one page of a [RenderedPageSource], rasterised to fit
/// the requested bounds. Cached by (source id, page index, bounds).
@immutable
class RenderedPageImage extends ImageProvider<RenderedPageImage> {
  const RenderedPageImage(this.source, this.index, {this.width, this.height});

  final RenderedPageSource source;
  final int index;
  final int? width;
  final int? height;

  /// Keeps a single rasterised page under ~160MB of RGBA.
  static const _maxPixels = 40e6;

  @override
  Future<RenderedPageImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    RenderedPageImage key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(
      _load(),
      informationCollector: () => [
        DiagnosticsProperty('Page', '${source.title} p${index + 1}'),
      ],
    );
  }

  Future<ImageInfo> _load() async {
    final pt = source.pageSize(index);
    final w = width;
    final h = height;
    var scale = switch ((w, h)) {
      (final int w, final int h) => math.min(w / pt.width, h / pt.height),
      (final int w, null) => w / pt.width,
      (null, final int h) => h / pt.height,
      (null, null) => 1.0,
    };
    final area = pt.width * pt.height * scale * scale;
    if (area > _maxPixels) scale *= math.sqrt(_maxPixels / area);
    final image = await source.render(
      index,
      math.max(1, (pt.width * scale).round()),
      math.max(1, (pt.height * scale).round()),
    );
    return ImageInfo(image: image);
  }

  @override
  bool operator ==(Object other) =>
      other is RenderedPageImage &&
      other.source.id == source.id &&
      other.index == index &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(source.id, index, width, height);
}

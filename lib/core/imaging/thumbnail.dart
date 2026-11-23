import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../sources/page_source.dart';
import 'page_image.dart';

/// Renders page [index] of [source] as a PNG [width] pixels wide.
Future<Uint8List?> renderThumbnail(
  PageSource source, {
  int index = 0,
  int width = 240,
}) async {
  final stream = pageImage(
    source,
    index,
    width: width,
  ).resolve(ImageConfiguration.empty);
  final completer = Completer<ui.Image>();
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, _) {
      stream.removeListener(listener);
      completer.complete(info.image);
    },
    onError: (error, stack) {
      stream.removeListener(listener);
      completer.completeError(error, stack);
    },
  );
  stream.addListener(listener);
  final image = await completer.future;
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

import 'package:material_ui/material_ui.dart';

import '../core/imaging/page_image.dart';
import '../core/sources/page_source.dart';

enum FitMode {
  screen('Fit screen', Icons.fit_screen),
  width('Fit width', Icons.swap_horiz),
  height('Fit height', Icons.height),
  original('Original size', Icons.crop_free);

  const FitMode(this.label, this.icon);

  final String label;
  final IconData icon;

  FitMode get next => values[(index + 1) % values.length];
}

/// The image provider for page [index] decoded at the resolution [fit]
/// needs on a [physicalViewport], times [zoom] (1, 2 or 4).
///
/// Width/height modes constrain only one axis, so neighbours can be
/// preloaded at the right resolution without knowing their aspect ratio.
/// The same arguments always produce an equal provider, so preloaded pages
/// are cache hits.
ImageProvider pageProvider(
  PageSource source,
  int index,
  FitMode fit,
  Size physicalViewport, {
  int zoom = 1,
}) {
  final base = PageImage(source, index);
  int dim(double v) => bucketDimension(v * zoom);
  return switch (fit) {
    FitMode.screen => ResizeImage(
      base,
      width: dim(physicalViewport.width),
      height: dim(physicalViewport.height),
      policy: ResizeImagePolicy.fit,
    ),
    FitMode.width => ResizeImage(base, width: dim(physicalViewport.width)),
    FitMode.height => ResizeImage(base, height: dim(physicalViewport.height)),
    FitMode.original => base,
  };
}

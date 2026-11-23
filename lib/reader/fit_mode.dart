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

/// The image provider for page [index] at the resolution [fit] needs on a
/// [viewport] (logical pixels) at [dpr], times [zoom] (1, 2 or 4).
///
/// Width/height modes constrain only one axis, so neighbours can be
/// preloaded at the right resolution without knowing their aspect ratio.
/// The same arguments always produce an equal provider, so preloaded pages
/// are cache hits.
ImageProvider pageProvider(
  PageSource source,
  int index,
  FitMode fit,
  Size viewport,
  double dpr, {
  int zoom = 1,
}) {
  int dim(double logical) => bucketDimension(logical * dpr * zoom);
  return switch (fit) {
    FitMode.screen => pageImage(
      source,
      index,
      width: dim(viewport.width),
      height: dim(viewport.height),
    ),
    FitMode.width => pageImage(source, index, width: dim(viewport.width)),
    FitMode.height => pageImage(source, index, height: dim(viewport.height)),
    // Encoded pages: their own pixels. Rendered pages: 1pt = 1 logical px.
    FitMode.original => switch (source) {
      EncodedPageSource() => pageImage(source, index),
      RenderedPageSource() => pageImage(
        source,
        index,
        width: (source.pageSize(index).width * dpr * zoom).round(),
      ),
    },
  };
}

/// [pageProvider] for a page shown as part of a unit of [unitLength] pages:
/// each page of a two-page spread gets half the viewport width.
ImageProvider unitPageProvider(
  PageSource source,
  int page,
  int unitLength,
  FitMode fit,
  Size viewport,
  double dpr, {
  int zoom = 1,
}) => pageProvider(
  source,
  page,
  fit,
  unitLength == 2 ? Size(viewport.width / 2, viewport.height) : viewport,
  dpr,
  zoom: zoom,
);

import 'dart:ui' show Size;

import 'package:material_ui/material_ui.dart' show IconData, Icons;

enum LayoutMode {
  single('Single page', Icons.crop_portrait),
  double('Two pages', Icons.menu_book),
  auto('Auto (two pages in landscape)', Icons.auto_awesome_mosaic);

  const LayoutMode(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// A page wider than it is tall is usually a pre-joined double spread and
/// is always shown on its own.
bool isWidePage(Size? size) => size != null && size.width > size.height;

/// Groups pages into reading units of one or two pages.
///
/// With [twoPages], portrait pages are paired; wide pages stand alone and
/// restart the pairing after them (so left/right stay aligned). With
/// [coverAlone] the first page is shown on its own, as it would be on the
/// right-hand side of a printed comic. Unknown sizes count as portrait.
List<List<int>> buildSpreads(
  List<Size?> sizes, {
  required bool twoPages,
  required bool coverAlone,
}) {
  final n = sizes.length;
  if (!twoPages) {
    return [
      for (var i = 0; i < n; i++) [i],
    ];
  }
  final units = <List<int>>[];
  var i = 0;
  if (coverAlone && n > 0) units.add([i++]);
  while (i < n) {
    if (isWidePage(sizes[i]) || i + 1 >= n || isWidePage(sizes[i + 1])) {
      units.add([i++]);
    } else {
      units.add([i, i + 1]);
      i += 2;
    }
  }
  return units;
}

/// Index of the unit containing [page].
int unitOfPage(List<List<int>> units, int page) {
  for (var u = 0; u < units.length; u++) {
    if (units[u].contains(page)) return u;
  }
  return units.isEmpty ? 0 : units.length - 1;
}

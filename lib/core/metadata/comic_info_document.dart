import 'package:xml/xml.dart';

/// A ComicInfo.xml document that can be edited without losing anything:
/// fields Panelist doesn't show (`<Pages>`, newer schema fields, unknown
/// elements and attributes) are kept as they were. New fields are placed in
/// schema order, so other tools that expect it are happy.
class ComicInfoDocument {
  ComicInfoDocument._(this._doc);

  /// Parses [xml], or starts an empty document if it's null or isn't
  /// ComicInfo.
  factory ComicInfoDocument.parse(String? xml) {
    if (xml != null) {
      try {
        final doc = XmlDocument.parse(xml);
        if (doc.rootElement.name.local == 'ComicInfo') {
          return ComicInfoDocument._(doc);
        }
      } on XmlException {
        // Start fresh: a broken file can't be edited field by field.
      }
    }
    return ComicInfoDocument.empty();
  }

  factory ComicInfoDocument.empty() => ComicInfoDocument._(
    XmlDocument.parse(
      '<?xml version="1.0" encoding="utf-8"?>\n'
      '<ComicInfo xmlns:xsd="http://www.w3.org/2001/XMLSchema" '
      'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"/>',
    ),
  );

  final XmlDocument _doc;

  XmlElement get _root => _doc.rootElement;

  /// The ComicInfo v2.0 schema's element order.
  static const schemaOrder = [
    'Title', 'Series', 'Number', 'Count', 'Volume', 'AlternateSeries', //
    'AlternateNumber', 'AlternateCount', 'Summary', 'Notes', 'Year', //
    'Month', 'Day', 'Writer', 'Penciller', 'Inker', 'Colorist', 'Letterer',
    'CoverArtist', 'Editor', 'Translator', 'Publisher', 'Imprint', 'Genre',
    'Tags', 'Web', 'PageCount', 'LanguageISO', 'Format', 'BlackAndWhite',
    'Manga', 'Characters', 'Teams', 'Locations', 'ScanInformation',
    'StoryArc', 'StoryArcNumber', 'SeriesGroup', 'AgeRating', 'Pages',
    'CommunityRating', 'MainCharacterOrTeam', 'Review', 'GTIN',
  ];

  /// The trimmed text of [field], or null if it's absent or blank.
  String? operator [](String field) {
    final v = _root.getElement(field)?.innerText.trim();
    return v == null || v.isEmpty ? null : v;
  }

  /// Sets [field]; null or blank removes it.
  void operator []=(String field, String? value) {
    final existing = _root.getElement(field);
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      existing?.remove();
      return;
    }
    if (existing != null) {
      existing.innerText = text;
      return;
    }
    final element = XmlElement.tag(field, children: [XmlText(text)]);
    final index = schemaOrder.indexOf(field);
    final before = index < 0
        ? null
        : _root.childElements.where((e) {
            final i = schemaOrder.indexOf(e.name.local);
            return i > index;
          }).firstOrNull;
    if (before == null) {
      _root.children.add(element);
    } else {
      _root.children.insert(_root.children.indexOf(before), element);
    }
  }

  /// Whether no fields are set (an empty document isn't worth writing).
  bool get isEmpty => _root.childElements.isEmpty;

  /// Pretty-printed XML with a declaration, as ComicRack writes it.
  String toXmlString() {
    // Re-indents structure but leaves field text (e.g. a summary's line
    // breaks) exactly as written.
    final body = _root.toXmlString(
      pretty: true,
      indent: '  ',
      preserveWhitespace: (node) =>
          node is XmlElement && node.childElements.isEmpty,
    );
    return '<?xml version="1.0" encoding="utf-8"?>\n$body\n';
  }
}

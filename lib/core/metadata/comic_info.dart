import 'package:xml/xml.dart';

/// The subset of ComicRack's ComicInfo.xml that Panelist uses.
/// Schema: https://anansi-project.github.io/docs/comicinfo/documentation
class ComicInfo {
  const ComicInfo({
    this.title,
    this.series,
    this.number,
    this.volume,
    this.year,
    this.writer,
    this.artist,
    this.publisher,
    this.summary,
    this.rightToLeft,
  });

  final String? title;
  final String? series;
  final String? number;
  final int? volume;
  final int? year;
  final String? writer;

  /// Penciller (or Artist / CoverArtist as fallbacks).
  final String? artist;
  final String? publisher;
  final String? summary;

  /// From `<Manga>`: true for `YesAndRightToLeft`, false for `No`, null if
  /// unspecified (plain `Yes` says it's manga but not the direction).
  final bool? rightToLeft;

  /// Name of the file inside a comic that holds this metadata.
  static bool isComicInfoName(String path) {
    final name = path.split(RegExp(r'[/\\]')).last.toLowerCase();
    return name == 'comicinfo.xml';
  }

  /// Parses ComicInfo XML. Returns null if it isn't a ComicInfo document.
  /// Unknown or malformed fields are ignored.
  static ComicInfo? parse(String xml) {
    final XmlDocument doc;
    try {
      doc = XmlDocument.parse(xml);
    } on XmlException {
      return null;
    }
    final root = doc.rootElement;
    if (root.name.local != 'ComicInfo') return null;

    String? text(String name) {
      final v = root.getElement(name)?.innerText.trim();
      return v == null || v.isEmpty ? null : v;
    }

    int? integer(String name) {
      final v = int.tryParse(text(name) ?? '');
      return v == null || v <= 0 ? null : v;
    }

    return ComicInfo(
      title: text('Title'),
      series: text('Series'),
      number: text('Number'),
      volume: integer('Volume'),
      year: integer('Year'),
      writer: text('Writer'),
      artist: text('Penciller') ?? text('Artist') ?? text('CoverArtist'),
      publisher: text('Publisher'),
      summary: text('Summary'),
      rightToLeft: switch (text('Manga')) {
        'YesAndRightToLeft' => true,
        'No' => false,
        _ => null,
      },
    );
  }
}

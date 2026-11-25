import 'package:material_ui/material_ui.dart';

import '../data/book_extensions.dart';
import '../data/database.dart';

/// Metadata for a book, from ComicInfo.xml where available.
class BookInfoDialog extends StatelessWidget {
  const BookInfoDialog({super.key, required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = <(String, String?)>[
      ('Series', book.series),
      ('Number', book.number),
      ('Year', book.year?.toString()),
      ('Publisher', book.publisher),
      ('Writer', book.writer),
      ('Artist', book.artist),
      (
        'Reading direction',
        switch (book.rightToLeft) {
          true => 'Right to left (manga)',
          false => 'Left to right',
          null => null,
        },
      ),
      ('Pages', '${book.pageCount}'),
      ('File', book.path),
    ];
    return AlertDialog(
      title: Text(book.displayTitle),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (label, value) in rows)
                if (value != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 140,
                          child: Text(label, style: theme.textTheme.bodySmall),
                        ),
                        Expanded(child: SelectableText(value)),
                      ],
                    ),
                  ),
              if (book.summary case final summary?) ...[
                const SizedBox(height: 8),
                Text(summary, style: theme.textTheme.bodyMedium),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

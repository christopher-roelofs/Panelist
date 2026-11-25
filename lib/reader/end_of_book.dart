import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../library/library_model.dart';
import '../library/library_providers.dart';
import '../library/library_view.dart' show LibraryCover;

/// The page after the last one: says the book is finished and offers the
/// next issue in its series, if the library has one.
class EndOfBook extends ConsumerWidget {
  const EndOfBook({
    super.key,
    required this.bookId,
    required this.title,
    required this.onOpenNext,
    required this.onClose,
  });

  final String bookId;
  final String title;
  final ValueChanged<LibraryComic> onOpenNext;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = nextInSeries(ref.watch(libraryComicsProvider), bookId);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const white = Colors.white;
    const dim = Color(0xB3FFFFFF);

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 40,
                  color: scheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  'Finished',
                  style: theme.textTheme.labelLarge?.copyWith(color: dim),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(color: white),
                ),
                const SizedBox(height: 32),
                if (next != null) ...[
                  Text(
                    'Next in ${next.series}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelLarge?.copyWith(color: dim),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => onOpenNext(next),
                    child: SizedBox(
                      width: 140,
                      child: AspectRatio(
                        aspectRatio: 2 / 3,
                        child: LibraryCover(comic: next),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => onOpenNext(next),
                    icon: const Icon(Icons.arrow_forward),
                    label: Text(
                      next.number == null
                          ? 'Read next'
                          : 'Read #${next.number}',
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                TextButton(
                  onPressed: onClose,
                  style: TextButton.styleFrom(foregroundColor: dim),
                  child: const Text('Back to library'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

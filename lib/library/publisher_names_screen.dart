import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'library_providers.dart';
import 'publisher_aliases.dart';

/// Lists the user's publisher rules, with suggestions from the library.
class PublisherNamesScreen extends ConsumerWidget {
  const PublisherNamesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final aliases =
        ref.watch(publisherAliasesProvider).value ?? const PublisherAliases();
    final counts = <String, int>{};
    for (final c in ref.watch(libraryComicsProvider)) {
      if (c.entry.publisher case final p?) {
        counts.update(p, (n) => n + 1, ifAbsent: () => 1);
      }
    }
    final suggestions = suggestAliases(counts, existing: aliases);
    String comics(String name) {
      final n = counts[name] ?? 0;
      return n == 1 ? '1 comic' : '$n comics';
    }

    Future<void> add(Iterable<(String, String)> rules) async {
      var a = aliases;
      for (final (from, to) in rules) {
        a = a.withRule(from, to);
      }
      await savePublisherAliases(ref, a);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Publisher names'),
        actions: [
          TextButton.icon(
            onPressed: () async {
              final rule = await showDialog<(String, String)>(
                context: context,
                builder: (_) => const _RuleDialog(),
              );
              if (rule != null) await add([rule]);
            },
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'One publisher can be written several ways (Image, Image '
              'Comics). A rule makes the library show one name, and is used '
              'when details are looked up and when files are renamed. Files '
              'keep what they say until they’re edited or looked up.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          if (suggestions.isNotEmpty) ...[
            ListTile(
              title: Text(
                'Suggested from your library',
                style: theme.textTheme.titleSmall,
              ),
              trailing: TextButton(
                onPressed: () => add(suggestions),
                child: const Text('Add all'),
              ),
            ),
            for (final (from, to) in suggestions)
              ListTile(
                leading: const Icon(Icons.lightbulb_outline),
                title: Text('$from  →  $to'),
                subtitle: Text('${comics(from)} · ${comics(to)}'),
                trailing: TextButton(
                  onPressed: () => add([(from, to)]),
                  child: const Text('Add'),
                ),
              ),
            const Divider(),
          ],
          ListTile(title: Text('Rules', style: theme.textTheme.titleSmall)),
          if (aliases.rules.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text('None yet.'),
            ),
          for (final MapEntry(key: from, value: to) in aliases.rules.entries)
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: Text('$from  →  $to'),
              trailing: IconButton(
                tooltip: 'Remove',
                icon: const Icon(Icons.delete_outline),
                onPressed: () =>
                    unawaited(savePublisherAliases(ref, aliases.without(from))),
              ),
            ),
        ],
      ),
    );
  }
}

class _RuleDialog extends StatefulWidget {
  const _RuleDialog();

  @override
  State<_RuleDialog> createState() => _RuleDialogState();
}

class _RuleDialogState extends State<_RuleDialog> {
  final _from = TextEditingController();
  final _to = TextEditingController();

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  bool get _ok =>
      _from.text.trim().isNotEmpty &&
      _to.text.trim().isNotEmpty &&
      _from.text.trim() != _to.text.trim();

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add publisher rule'),
    content: SizedBox(
      width: 400,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _from,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'When a comic says',
              hintText: 'Image',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _to,
            decoration: const InputDecoration(
              labelText: 'Use',
              hintText: 'Image Comics',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _ok
            ? () =>
                  Navigator.of(context)
                      .pop((_from.text.trim(), _to.text.trim()))
            : null,
        child: const Text('Add'),
      ),
    ],
  );
}

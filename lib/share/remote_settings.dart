import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../app/providers.dart';
import '../data/database.dart';
import '../platform/android_documents.dart';
import 'remote_library.dart';
import 'share_client.dart';
import 'share_settings.dart';

/// Settings → Libraries on this network: libraries this device reads from,
/// those found on the network, and adding one by its address.
class RemoteLibrariesScreen extends ConsumerStatefulWidget {
  const RemoteLibrariesScreen({super.key});

  @override
  ConsumerState<RemoteLibrariesScreen> createState() =>
      _RemoteLibrariesScreenState();
}

class _RemoteLibrariesScreenState extends ConsumerState<RemoteLibrariesScreen> {
  final _found = <FoundLibrary>[];
  StreamSubscription<FoundLibrary>? _discovery;
  bool _looking = true;
  String? _ownId;

  @override
  void initState() {
    super.initState();
    unawaited(() async {
      _ownId = await ref.read(databaseProvider).setting(shareIdKey);
    }());
    _look();
  }

  void _look() {
    unawaited(_discovery?.cancel());
    setState(() {
      _found.clear();
      _looking = true;
    });
    _discovery = discoverLibraries(timeout: const Duration(seconds: 30)).listen(
      (f) {
        if (!mounted) return;
        setState(() {
          _found
            ..removeWhere((o) => o.id == f.id)
            ..add(f);
        });
      },
      onDone: () {
        if (mounted) setState(() => _looking = false);
      },
    );
  }

  @override
  void dispose() {
    unawaited(_discovery?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paired = ref.watch(remoteLibrariesProvider).value ?? const [];
    final pairedIds = {for (final l in paired) l.serverId};
    final found = [
      for (final f in _found)
        if (!pairedIds.contains(f.id) && f.id != _ownId) f,
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Libraries on this network')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Read comics from a computer running Panelist with Share '
              'library turned on. Reading progress is kept in step both '
              'ways, and comics you download can be read without it.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          ListTile(title: Text('Added', style: theme.textTheme.titleSmall)),
          if (paired.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text('None yet.'),
            ),
          for (final l in paired) _PairedTile(library: l),
          const Divider(),
          ListTile(
            title: Text('On this network', style: theme.textTheme.titleSmall),
            trailing: _looking
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    tooltip: 'Look again',
                    icon: const Icon(Icons.refresh),
                    onPressed: _look,
                  ),
          ),
          if (found.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                _looking
                    ? 'Looking…'
                    : 'None found. Check that Share library is on, on the '
                          'computer, and that both are on the same network — '
                          'or enter its address.',
              ),
            ),
          for (final f in found)
            ListTile(
              leading: const Icon(Icons.computer_outlined),
              title: Text(f.name),
              subtitle: Text(f.address),
              trailing: const Icon(Icons.add),
              onTap: () => pairWithLibrary(context, ref, f.address),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final address = await showDialog<String>(
                      context: context,
                      builder: (_) => const _AddressDialog(),
                    );
                    if (address != null && context.mounted) {
                      await pairWithLibrary(context, ref, address);
                    }
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Enter an address…'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PairedTile extends ConsumerWidget {
  const _PairedTile({required this.library});
  final RemoteLibrary library;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = library;
    final state = ref.watch(remoteComicsProvider(l.id));
    final status =
        state.error ??
        (state.loading && state.comics.isEmpty
            ? 'Connecting…'
            : '${state.comics.length} comics');
    return ListTile(
      leading: Icon(
        state.error == null
            ? Icons.computer_outlined
            : Icons.cloud_off_outlined,
      ),
      title: Text(l.name),
      subtitle: Text('${l.address} · $status'),
      trailing: PopupMenuButton<String>(
        onSelected: (v) async {
          switch (v) {
            case 'pair':
              await pairWithLibrary(context, ref, l.address);
            case 'remove':
              await _remove(context, ref);
          }
        },
        itemBuilder: (_) => [
          if (state.unpaired)
            const PopupMenuItem(value: 'pair', child: Text('Add again…')),
          const PopupMenuItem(value: 'remove', child: Text('Remove')),
        ],
      ),
      onTap: () {
        ref.read(shownLibraryProvider.notifier).show(l.id);
        Navigator.of(context).popUntil((r) => r.isFirst);
      },
    );
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${library.name}?'),
        content: const Text(
          'Its comics leave this device’s list. Reading progress and '
          'downloaded comics are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (ref.read(shownLibraryProvider) == library.id) {
      ref.read(shownLibraryProvider.notifier).show(null);
    }
    await ref.read(databaseProvider).removeRemoteLibrary(library.id);
  }
}

class _AddressDialog extends StatefulWidget {
  const _AddressDialog();

  @override
  State<_AddressDialog> createState() => _AddressDialogState();
}

class _AddressDialogState extends State<_AddressDialog> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Enter an address'),
    content: SizedBox(
      width: 380,
      child: TextField(
        controller: _text,
        autofocus: true,
        keyboardType: TextInputType.url,
        decoration: const InputDecoration(
          labelText: 'Address',
          hintText: '192.168.1.20:8696',
          helperText: 'Shown in Share library on the computer',
          border: OutlineInputBorder(),
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: (v) {
          if (v.trim().isNotEmpty) Navigator.of(context).pop(v.trim());
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _text.text.trim().isEmpty
            ? null
            : () => Navigator.of(context).pop(_text.text.trim()),
        child: const Text('Next'),
      ),
    ],
  );
}

/// Connects to the library at [address], asks for the code shown on the
/// computer, and adds the library. Shows it in the library when done.
Future<void> pairWithLibrary(
  BuildContext context,
  WidgetRef ref,
  String address,
) async {
  final added = await showDialog<int>(
    context: context,
    builder: (_) => _PairDialog(address: address),
  );
  if (added == null || !context.mounted) return;
  ref.read(shownLibraryProvider.notifier).show(added);
  Navigator.of(context).popUntil((r) => r.isFirst);
}

/// A name for this device, as the computer lists it.
String _deviceName() {
  if (AndroidDocuments.isSupported) return 'Android device';
  try {
    final host = Platform.localHostname;
    if (host.isNotEmpty && host != 'localhost') return host;
  } on Object {
    // No name.
  }
  return 'Device';
}

class _PairDialog extends ConsumerStatefulWidget {
  const _PairDialog({required this.address});
  final String address;

  @override
  ConsumerState<_PairDialog> createState() => _PairDialogState();
}

class _PairDialogState extends ConsumerState<_PairDialog> {
  final _code = TextEditingController();
  final _name = TextEditingController(text: _deviceName());
  late final _client = ShareClient(widget.address);
  ShareInfo? _info;
  String? _error;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    unawaited(() async {
      try {
        final info = await _client.info();
        if (mounted) setState(() => _info = info);
      } on ShareException catch (e) {
        if (mounted) setState(() => _error = e.message);
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }());
  }

  @override
  void dispose() {
    _client.close();
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  String get _digits => _code.text.replaceAll(RegExp(r'\D'), '');

  Future<void> _pair() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await _client.pair(_digits, _name.text.trim());
      final id = await ref
          .read(databaseProvider)
          .saveRemoteLibrary(
            serverId: r.id,
            name: r.name,
            address: widget.address,
            token: r.token,
          );
      ref.invalidate(remoteComicsProvider(id));
      unawaited(ref.read(remoteAccessProvider).syncAll());
      if (mounted) Navigator.of(context).pop(id);
    } on ShareException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = _info;
    return AlertDialog(
      title: Text(info == null ? 'Connecting…' : 'Add ${info.name}'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (info == null && _busy)
              const LinearProgressIndicator()
            else if (info != null) ...[
              Text(
                'On the computer, open Settings → Share library → Add a '
                'device, and enter the code it shows.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _code,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d ]')),
                ],
                style: theme.textTheme.headlineSmall?.copyWith(
                  letterSpacing: 4,
                ),
                decoration: const InputDecoration(
                  labelText: 'Code',
                  hintText: '123 456',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) {
                  if (_digits.length == 6 && !_busy) unawaited(_pair());
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'This device’s name',
                  helperText: 'How the computer lists it',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            if (_error case final e?) ...[
              const SizedBox(height: 12),
              Text(e, style: TextStyle(color: theme.colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (info != null)
          FilledButton(
            onPressed: _digits.length == 6 && !_busy ? _pair : null,
            child: const Text('Add'),
          ),
      ],
    );
  }
}

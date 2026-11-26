import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../app/providers.dart';
import '../core/sources/open_source.dart';
import '../data/database.dart';
import '../library/library_scanner.dart';
import '../library/publisher_aliases.dart';
import 'library_server.dart';
import 'share_protocol.dart';

/// Computers share their library; any device running Panelist (phone,
/// tablet or another computer) can read from them.
final canShareLibrary =
    !kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS);

const shareLibraryKey = 'share.enabled';
const shareIdKey = 'share.id';

/// A random ID for this computer's shared library.
String newLibraryId() {
  final r = Random.secure();
  return List.generate(
    16,
    (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

/// Whether the library is being shared, and how to reach it.
class ShareState {
  const ShareState({
    this.enabled = false,
    this.port,
    this.addresses = const [],
    this.announced = false,
    this.error,
  });

  final bool enabled;

  /// The port served on, once running.
  final int? port;

  /// This computer's addresses on the network (IPv4), for typing in.
  final List<String> addresses;

  /// Whether devices can find it by themselves (mDNS).
  final bool announced;
  final String? error;

  bool get running => port != null;
}

final librarySharingProvider = NotifierProvider<LibrarySharing, ShareState>(
  LibrarySharing.new,
);

/// Runs the [LibraryServer] and announces it while sharing is on (it stays
/// on across restarts).
class LibrarySharing extends Notifier<ShareState> {
  LibraryServer? _server;
  BonsoirBroadcast? _broadcast;

  LibraryServer? get server => _server;

  @override
  ShareState build() {
    ref.onDispose(_stop);
    if (canShareLibrary) {
      unawaited(() async {
        final on =
            await ref.read(databaseProvider).setting(shareLibraryKey) == 'on';
        if (on && ref.mounted) await _start();
      }());
    }
    return const ShareState();
  }

  Future<void> setEnabled(bool on) async {
    await ref
        .read(databaseProvider)
        .setSetting(shareLibraryKey, on ? 'on' : 'off');
    if (on) {
      await _start();
    } else {
      await _stop();
      state = const ShareState();
    }
  }

  Future<void> _start() async {
    if (_server != null) return;
    final db = ref.read(databaseProvider);
    var id = await db.setting(shareIdKey);
    if (id == null) {
      id = newLibraryId();
      await db.setSetting(shareIdKey, id);
    }
    final server = LibraryServer(
      id: id,
      publisherName: (p) =>
          (ref.read(publisherAliasesProvider).value ?? const PublisherAliases())
              .apply(p),
      db: db,
      coversDir: ref.read(coversDirProvider),
      openSource: openSource,
    );
    final int port;
    try {
      port = await server.start();
    } on Object catch (e) {
      state = ShareState(enabled: true, error: 'Couldn’t start sharing: $e');
      return;
    }
    _server = server;
    state = ShareState(
      enabled: true,
      port: port,
      addresses: await _addresses(),
    );
    try {
      final broadcast = BonsoirBroadcast(
        service: BonsoirService(
          name: 'Panelist on ${server.name}',
          type: shareServiceType,
          port: port,
          attributes: {'api': '$apiVersion', 'id': id},
        ),
      );
      await broadcast.initialize();
      await broadcast.start();
      _broadcast = broadcast;
      if (ref.mounted) state = _copy(announced: true);
    } on Object catch (e) {
      // Devices can still type the address in.
      debugPrint('Couldn’t announce the library: $e');
    }
  }

  ShareState _copy({bool? announced}) => ShareState(
    enabled: state.enabled,
    port: state.port,
    addresses: state.addresses,
    announced: announced ?? state.announced,
    error: state.error,
  );

  Future<void> _stop() async {
    final broadcast = _broadcast;
    _broadcast = null;
    if (broadcast != null) {
      try {
        await broadcast.stop();
      } on Object {
        // Already gone.
      }
    }
    await _server?.stop();
    _server = null;
  }

  static Future<List<String>> _addresses() async {
    try {
      return [
        for (final i in await NetworkInterface.list(
          type: InternetAddressType.IPv4,
        ))
          for (final a in i.addresses)
            if (!a.isLoopback && !a.isLinkLocal) a.address,
      ];
    } on Object {
      return const [];
    }
  }
}

final pairedDevicesProvider = StreamProvider<List<PairedDevice>>(
  (ref) => ref.watch(databaseProvider).watchPairedDevices(),
);

/// Settings → Share library.
class ShareLibraryScreen extends ConsumerWidget {
  const ShareLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final share = ref.watch(librarySharingProvider);
    final devices = ref.watch(pairedDevicesProvider).value ?? const [];
    final sharing = ref.read(librarySharingProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Share library')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Devices on this network can browse and read your '
              'library, download comics, and keep reading progress in step '
              'with this computer. Only devices you add can connect. Panelist '
              'needs to be open here for them to reach it.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.wifi_tethering),
            title: const Text('Share on this network'),
            subtitle: Text(_status(share)),
            value: share.enabled,
            onChanged: (on) => sharing.setEnabled(on),
          ),
          if (share.running) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Wrap(
                children: [
                  FilledButton.icon(
                    onPressed: () => showPairingCode(context, ref),
                    icon: const Icon(Icons.add_to_home_screen),
                    label: const Text('Add a device…'),
                  ),
                ],
              ),
            ),
          ],
          ListTile(title: Text('Devices', style: theme.textTheme.titleSmall)),
          if (devices.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text('None yet.'),
            ),
          for (final d in devices)
            ListTile(
              leading: const Icon(Icons.devices_outlined),
              title: Text(d.name),
              subtitle: Text(
                d.lastSeen == null
                    ? 'Added ${_when(d.added)} · not connected yet'
                    : 'Last connected ${_when(d.lastSeen!)}',
              ),
              trailing: IconButton(
                tooltip: 'Remove',
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('Remove ${d.name}?'),
                      content: const Text(
                        'It can’t connect again until it’s added again. '
                        'Comics it downloaded stay on it.',
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
                  if (ok ?? false) {
                    await ref.read(databaseProvider).removePairedDevice(d.id);
                  }
                },
              ),
            ),
        ],
      ),
    );
  }

  static String _status(ShareState s) {
    if (s.error case final e?) return e;
    if (!s.enabled) return 'Off';
    if (!s.running) return 'Starting…';
    final where = s.addresses.isEmpty
        ? 'port ${s.port}'
        : s.addresses.map((a) => '$a:${s.port}').join(', ');
    return s.announced
        ? 'On · devices find it by themselves, or use $where'
        : 'On · on devices, enter $where';
  }
}

String _when(DateTime t) {
  final ago = DateTime.now().difference(t);
  if (ago.inMinutes < 1) return 'just now';
  if (ago.inHours < 1) return '${ago.inMinutes} min ago';
  if (ago.inDays < 1) return '${ago.inHours} h ago';
  if (ago.inDays < 7) return '${ago.inDays} days ago';
  return '${t.year}-${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')}';
}

/// Shows a pairing code until a device uses it, it expires, or the dialog
/// is closed.
Future<void> showPairingCode(BuildContext context, WidgetRef ref) async {
  final server = ref.read(librarySharingProvider.notifier).server;
  if (server == null) return;
  await showDialog<void>(
    context: context,
    builder: (_) => _PairingDialog(server: server),
  );
  server.cancelPairing();
}

class _PairingDialog extends StatefulWidget {
  const _PairingDialog({required this.server});
  final LibraryServer server;

  @override
  State<_PairingDialog> createState() => _PairingDialogState();
}

class _PairingDialogState extends State<_PairingDialog> {
  late String _code;
  late DateTime _expires;
  Timer? _tick;
  String? _paired;

  @override
  void initState() {
    super.initState();
    _newCode();
    widget.server.onPaired = (name) {
      if (mounted) setState(() => _paired = name);
    };
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_paired == null && widget.server.pairingCode == null) _newCode();
      setState(() {});
    });
  }

  void _newCode() {
    _code = widget.server.newPairingCode();
    _expires = DateTime.now().add(LibraryServer.codeLifetime);
  }

  @override
  void dispose() {
    _tick?.cancel();
    widget.server.onPaired = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final left = _expires.difference(DateTime.now());
    final paired = _paired;
    return AlertDialog(
      title: Text(paired == null ? 'Add a device' : 'Added $paired'),
      content: SizedBox(
        width: 380,
        child: paired != null
            ? Text(
                '$paired can now browse and read this library.',
                style: theme.textTheme.bodyMedium,
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'In Panelist on the other device, open Settings → '
                    'Libraries on this network, choose this computer, and '
                    'enter:',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: SelectableText(
                      '${_code.substring(0, 3)} ${_code.substring(3)}',
                      style: theme.textTheme.displayMedium?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'A new code in ${left.inMinutes}:'
                      '${(left.inSeconds % 60).toString().padLeft(2, '0')}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(paired == null ? 'Cancel' : 'Done'),
        ),
      ],
    );
  }
}

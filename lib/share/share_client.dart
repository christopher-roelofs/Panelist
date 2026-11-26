import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'share_protocol.dart';

/// Something went wrong talking to a shared library.
class ShareException implements Exception {
  const ShareException(this.message, {this.unpaired = false});
  final String message;

  /// The computer no longer knows this device (it was removed there).
  final bool unpaired;

  @override
  String toString() => message;
}

/// What a shared library says about itself.
typedef ShareInfo = ({String id, String name});

/// Talks to one computer's shared library at [address] (`host:port`).
class ShareClient {
  ShareClient(this.address, {this.token, HttpClient? http})
    : _http = http ?? (HttpClient()..connectionTimeout = _connectTimeout);

  static const _connectTimeout = Duration(seconds: 5);
  static const _timeout = Duration(seconds: 30);

  final String address;
  final String? token;
  final HttpClient _http;

  Uri _uri(String path, [Map<String, String>? query]) {
    final (host, port) = splitAddress(address);
    return Uri(
      scheme: 'http',
      host: host,
      port: port,
      path: '$apiPath/$path',
      queryParameters: query,
    );
  }

  Future<HttpClientResponse> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? headers,
    Map<String, String>? query,
  }) async {
    try {
      final req = await _http.openUrl(method, _uri(path, query));
      if (token != null) req.headers.set('authorization', 'Bearer $token');
      headers?.forEach(req.headers.set);
      if (body != null) {
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode(body));
      }
      final res = await req.close().timeout(_timeout);
      if (res.statusCode == 401) {
        await res.drain<void>();
        throw const ShareException(
          'This device was removed on the computer. Add it again.',
          unpaired: true,
        );
      }
      return res;
    } on SocketException catch (e) {
      throw ShareException(_cantReach(e));
    } on TimeoutException {
      throw ShareException('$address didn’t answer');
    } on HttpException catch (e) {
      throw ShareException('Lost the connection to $address: ${e.message}');
    }
  }

  /// Runs [read] (reading a response), turning lost connections into
  /// [ShareException]s.
  Future<T> _reading<T>(Future<T> Function() read) async {
    try {
      return await read().timeout(const Duration(minutes: 2));
    } on SocketException catch (e) {
      throw ShareException(_cantReach(e));
    } on HttpException catch (e) {
      throw ShareException('Lost the connection to $address: ${e.message}');
    } on TimeoutException {
      throw ShareException('$address stopped answering');
    }
  }

  String _cantReach(SocketException e) {
    final why = e.osError?.message ?? e.message;
    final hint = Platform.isAndroid
        ? ' Check that Share library is on on the computer, and that '
              'Panelist may use the network (App info → Mobile data & Wi‑Fi).'
        : ' Check that Share library is on on the computer.';
    return 'Can’t reach $address ($why).$hint';
  }

  Future<Map<String, Object?>> _json(HttpClientResponse res) async {
    final text = await _reading(() => res.transform(utf8.decoder).join());
    final Object? body;
    try {
      body = jsonDecode(text);
    } on FormatException {
      throw ShareException('$address isn’t a Panelist library');
    }
    if (body is! Map<String, Object?>) {
      throw ShareException('$address isn’t a Panelist library');
    }
    if (res.statusCode >= 400) {
      throw ShareException('${body['error'] ?? 'Error ${res.statusCode}'}');
    }
    return body;
  }

  Future<Uint8List> _bytes(HttpClientResponse res) async {
    if (res.statusCode != 200) {
      await res.drain<void>();
      throw ShareException('Not found on the computer (${res.statusCode})');
    }
    return _reading(() async {
      final b = BytesBuilder(copy: false);
      await for (final chunk in res) {
        b.add(chunk);
      }
      return b.takeBytes();
    });
  }

  Future<ShareInfo> info() async {
    final j = await _json(await _send('GET', 'info'));
    if (j['app'] != 'panelist' || j['id'] is! String) {
      throw ShareException('$address isn’t a Panelist library');
    }
    return (id: j['id']! as String, name: j['name'] as String? ?? address);
  }

  /// Pairs with the code the computer shows; returns the token.
  Future<({String token, String id, String name})> pair(
    String code,
    String device,
  ) async {
    final j = await _json(
      await _send('POST', 'pair', body: {'code': code, 'device': device}),
    );
    return (
      token: j['token']! as String,
      id: j['id']! as String,
      name: j['name'] as String? ?? address,
    );
  }

  /// The library, or null when it hasn't changed since [etag].
  Future<({List<RemoteComic> comics, String? etag})?> library({
    String? etag,
  }) async {
    final res = await _send(
      'GET',
      'library',
      headers: {'if-none-match': ?etag},
    );
    if (res.statusCode == 304) {
      await res.drain<void>();
      return null;
    }
    final j = await _json(res);
    return (
      comics: [
        for (final c in j['comics']! as List)
          RemoteComic.fromJson(c as Map<String, Object?>),
      ],
      etag: res.headers.value('etag'),
    );
  }

  Future<Uint8List> cover(String id) async =>
      _bytes(await _send('GET', 'books/$id/cover'));

  Future<({int count, List<(int, int)?> sizes})> pages(String id) async {
    final j = await _json(await _send('GET', 'books/$id/pages'));
    return (
      count: j['count']! as int,
      sizes: [
        for (final s in j['sizes']! as List)
          s is List ? (s[0] as int, s[1] as int) : null,
      ],
    );
  }

  Future<Uint8List> page(String id, int index, {int? width}) async => _bytes(
    await _send(
      'GET',
      'books/$id/pages/$index',
      query: width == null ? null : {'width': '$width'},
    ),
  );

  /// Downloads book [id] to [to], resuming a `.part` file left by an
  /// earlier try. [onProgress] gets (bytes so far, total).
  Future<void> download(
    String id,
    File to, {
    void Function(int done, int total)? onProgress,
    bool Function()? cancelled,
  }) async {
    final part = File('${to.path}.part');
    await part.parent.create(recursive: true);
    final have = part.existsSync() ? part.lengthSync() : 0;
    final res = await _send(
      'GET',
      'books/$id/file',
      headers: {if (have > 0) 'range': 'bytes=$have-'},
    );
    final int start;
    final int total;
    switch (res.statusCode) {
      case 206:
        start = have;
        total = int.parse(res.headers.value('content-range')!.split('/').last);
      case 200:
        start = 0;
        total = res.contentLength;
      default:
        await res.drain<void>();
        throw ShareException('Couldn’t download (${res.statusCode})');
    }
    final sink = part.openWrite(
      mode: start > 0 ? FileMode.append : FileMode.write,
    );
    var done = start;
    try {
      await for (final chunk in res.handleError((Object e) {
        throw ShareException('The download was cut off ($e); try again');
      })) {
        if (cancelled?.call() ?? false) {
          throw const ShareException('Download stopped');
        }
        sink.add(chunk);
        done += chunk.length;
        onProgress?.call(done, total);
      }
    } finally {
      await sink.close();
    }
    if (total > 0 && part.lengthSync() != total) {
      throw const ShareException('The download was cut short; try again');
    }
    await part.rename(to.path);
  }

  Future<ProgressSync> sync(ProgressSync mine) async => ProgressSync.fromJson(
    await _json(await _send('POST', 'progress', body: mine.toJson())),
  );

  /// Lets requests in progress finish.
  void close() => _http.close();
}

/// `host:port` (IPv6 in brackets) → parts; the default port if none.
(String, int) splitAddress(String address) {
  final a = address.trim();
  final v6 = RegExp(r'^\[(.+)\](?::(\d+))?$').firstMatch(a);
  if (v6 != null) {
    return (v6[1]!, int.tryParse(v6[2] ?? '') ?? defaultSharePort);
  }
  final i = a.lastIndexOf(':');
  if (i > 0 && !a.substring(0, i).contains(':')) {
    return (
      a.substring(0, i),
      int.tryParse(a.substring(i + 1)) ?? defaultSharePort,
    );
  }
  return (a, defaultSharePort);
}

/// [host] and [port] as an address (IPv6 in brackets).
String joinAddress(String host, int port) =>
    host.contains(':') ? '[$host]:$port' : '$host:$port';

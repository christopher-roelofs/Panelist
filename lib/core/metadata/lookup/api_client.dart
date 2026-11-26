import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'lookup_cache.dart';

/// Why looking something up failed.
class LookupException implements Exception {
  LookupException(this.message, {this.stopsProvider = false});
  final String message;

  /// The provider can't be used again this run (key refused, limit
  /// reached): later comics go straight to the next provider.
  final bool stopsProvider;

  @override
  String toString() => message;
}

/// One HTTP GET: status, headers (lower-case names) and body. Swappable so
/// tests don't need the network.
typedef HttpTransport =
    Future<({int status, Map<String, String> headers, String body})> Function(
      Uri uri,
      Map<String, String> headers,
    );

/// GETs JSON from a web API politely: one request at a time, spaced by
/// [spacing]; waits out "too many requests" (429, or Comic Vine's 420) as
/// long as asked; keeps answers in [cache].
class ApiClient {
  ApiClient({
    required this.name,
    required this.spacing,
    HttpTransport? transport,
    Future<void> Function(Duration)? sleep,
    LookupCache? cache,
  }) : _transport = transport ?? _httpGet,
       _sleep = sleep ?? Future<void>.delayed,
       cache = cache ?? LookupCache();

  /// The service's name, for messages ("Metron").
  final String name;
  final Duration spacing;
  final LookupCache cache;
  final HttpTransport _transport;
  final Future<void> Function(Duration) _sleep;
  DateTime? _last;
  Future<void> _queue = Future.value();

  static const userAgent = 'Panelist/1.0 (comic reader; metadata lookup)';

  /// Whether [key] has an answer younger than [maxAge].
  bool cached(Uri key, Duration maxAge) => cache.get(key, maxAge) != null;

  /// The decoded JSON at [uri]. [key] is what it's cached under (without
  /// secrets such as API keys; defaults to [uri]).
  Future<Object?> get(
    Uri uri, {
    required Duration maxAge,
    Uri? key,
    Map<String, String> headers = const {},
  }) {
    final k = key ?? uri;
    if (cache.get(k, maxAge) case final hit?) return Future.value(hit.body);
    final result = _queue.then((_) async {
      if (cache.get(k, maxAge) case final hit?) return hit.body;
      final body = await _fetch(uri, headers);
      cache.put(k, body);
      return body;
    });
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<Object?> _fetch(Uri uri, Map<String, String> headers) async {
    for (var attempt = 0; ; attempt++) {
      final last = _last;
      if (last != null) {
        final wait = spacing - DateTime.now().difference(last);
        if (wait > Duration.zero) await _sleep(wait);
      }
      _last = DateTime.now();
      final ({int status, Map<String, String> headers, String body}) r;
      try {
        r = await _transport(uri, {
          'Accept': 'application/json',
          'User-Agent': userAgent,
          ...headers,
        });
      } on SocketException catch (e) {
        throw LookupException('Couldn’t reach $name: ${e.message}');
      } on TimeoutException {
        throw LookupException('$name didn’t answer in time');
      } on HttpException catch (e) {
        throw LookupException('Couldn’t reach $name: ${e.message}');
      }
      switch (r.status) {
        case 200:
          try {
            return jsonDecode(r.body);
          } on FormatException {
            throw LookupException('$name sent an unreadable reply');
          }
        case 429 || 420 when attempt < 3:
          final seconds = int.tryParse(r.headers['retry-after'] ?? '') ?? 60;
          await _sleep(Duration(seconds: seconds.clamp(1, 3600)));
        case 429 || 420:
          throw LookupException(
            '$name’s request limit was reached; try again later',
            stopsProvider: true,
          );
        case 401 || 403:
          throw LookupException(
            '$name didn’t accept the API key (check it in Settings)',
            stopsProvider: true,
          );
        case 404:
          throw LookupException('Not found on $name');
        default:
          throw LookupException('$name answered with error ${r.status}');
      }
    }
  }

  static Future<({int status, Map<String, String> headers, String body})>
  _httpGet(Uri uri, Map<String, String> headers) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await client.getUrl(uri);
      headers.forEach(request.headers.set);
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 30));
      final out = <String, String>{};
      response.headers.forEach((name, values) {
        out[name.toLowerCase()] = values.join(',');
      });
      return (status: response.statusCode, headers: out, body: body);
    } finally {
      client.close();
    }
  }
}

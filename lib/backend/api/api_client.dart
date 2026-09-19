import 'dart:async';

import 'package:http/http.dart' as http;

import '../../constants/app_config.dart';

/// Thrown when every configured backend host is unreachable.
class ApiHostUnreachableException implements Exception {
  final List<String> tried;
  final Object? cause;
  ApiHostUnreachableException(this.tried, {this.cause});
  @override
  String toString() =>
      'Could not reach any backend host. Tried: ${tried.join(", ")}';
}

/// Shared HTTP client for the TradeZ backend.
///
/// Solves two real-world problems this app hits when installed as an APK on a
/// real device:
///
/// 1. The default `10.0.2.2` alias only works on the Android *emulator*. On a
///    physical phone it must talk to the dev machine's LAN IP instead. Rather
///    than failing on a single hard-coded host, [ApiClient] tries every host
///    from [AppConfig.apiBaseUrlCandidates] in order.
///
/// 2. Only a *connection* failure (unreachable host, timeout, DNS) falls
///    through to the next host. If a server answers — even with a 400/401/500
///    — we keep that response, because an HTTP error is meaningful and should
///    be surfaced to the user, not masked by retrying another host.
///
/// The first host that answers is remembered for the rest of the session so
/// subsequent calls go straight to it.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  static const Duration _timeout = Duration(seconds: 8);

  String? _cachedBase;

  Future<http.Response> get(
    String path, {
    Map<String, String>? query,
    Map<String, String>? headers,
  }) {
    return _send(
      (base) => http.get(_uri(base, path, query), headers: headers),
    );
  }

  Future<http.Response> post(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) {
    return _send(
      (base) => http.post(_uri(base, path), headers: headers, body: body),
    );
  }

  Future<http.Response> put(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) {
    return _send(
      (base) => http.put(_uri(base, path), headers: headers, body: body),
    );
  }

  Future<http.Response> delete(
    String path, {
    Map<String, String>? query,
    Map<String, String>? headers,
  }) {
    return _send(
      (base) => http.delete(_uri(base, path, query), headers: headers),
    );
  }

  /// Best-known base URL right now (no IO). Used by long-lived streams that
  /// can't easily retry mid-connection.
  Future<String> get bestBaseUrl async =>
      _cachedBase ?? (await AppConfig.apiBaseUrlCandidates()).first;

  /// Build a full URL against [base], appending the /api prefix + path.
  Uri _uri(String base, String path, [Map<String, String>? query]) {
    final u = Uri.parse('$base${AppConfig.apiPrefix}$path');
    return query == null ? u : u.replace(queryParameters: query);
  }

  /// Run [request] against each candidate host until one answers or all fail.
  Future<http.Response> _send(
    Future<http.Response> Function(String base) request,
  ) async {
    final candidates = await AppConfig.apiBaseUrlCandidates();
    final ordered = <String>[];
    if (_cachedBase != null) ordered.add(_cachedBase!);
    ordered.addAll(candidates);

    final seen = <String>{};
    final tried = <String>[];
    Object? lastError;

    for (final base in ordered) {
      if (!seen.add(base)) continue;
      tried.add(base);
      try {
        final res = await request(base).timeout(_timeout);
        _cachedBase = base;
        AppConfig.rememberLastGoodHost(base);
        return res;
      } on TimeoutException {
        lastError = TimeoutException('Timed out connecting to $base');
      } catch (e) {
        // SocketException / ClientException / handshake failure — server
        // unreachable, so fall through to the next candidate.
        lastError = e;
      }
    }

    throw ApiHostUnreachableException(tried, cause: lastError);
  }
}

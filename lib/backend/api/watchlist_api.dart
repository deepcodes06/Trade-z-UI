import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../services/secure_store.dart';
import 'api_client.dart';

class WatchlistApiException implements Exception {
  final String message;
  final int? statusCode;
  WatchlistApiException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

class WatchlistListData {
  final String id;
  final String name;
  final List<String> symbols;

  const WatchlistListData({
    required this.id,
    required this.name,
    required this.symbols,
  });
}

/// HTTP client for the authenticated `/api/watchlist` routes.
///
/// Mirrors the token-backed pattern in `profile_api.dart`: reads the stored
/// JWT (`auth_jwt_token`), sends it as a `Bearer` header, and throws a
/// user-friendly [WatchlistApiException] when the backend is unreachable.
class WatchlistApi {
  WatchlistApi._();
  static final WatchlistApi instance = WatchlistApi._();

  static const String _tokenKey = 'auth_jwt_token';

  Future<String> _getToken() async {
    final token = await SecureStore.readEncrypted(_tokenKey);
    if (token == null) throw WatchlistApiException('Not authenticated');
    return token;
  }

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  Future<http.Response> _send(
    Future<http.Response> Function() request,
  ) async {
    try {
      return await request().timeout(const Duration(seconds: 8));
    } on ApiHostUnreachableException catch (e) {
      throw WatchlistApiException(
        'Could not reach the server. Check your connection. (${e.cause})',
      );
    } on TimeoutException {
      throw WatchlistApiException(
        'Could not reach the server. Check your connection.',
      );
    }
  }

  Future<http.Response> _get(String path) async {
    final token = await _getToken();
    return _send(() => ApiClient.instance.get(path, headers: _headers(token)));
  }

  Future<http.Response> _post(String path, Map<String, dynamic> body) async {
    final token = await _getToken();
    return _send(
      () => ApiClient.instance.post(
        path,
        headers: _headers(token),
        body: jsonEncode(body),
      ),
    );
  }

  Future<http.Response> _put(String path, Map<String, dynamic> body) async {
    final token = await _getToken();
    return _send(
      () => ApiClient.instance.put(
        path,
        headers: _headers(token),
        body: jsonEncode(body),
      ),
    );
  }

  Future<http.Response> _delete(String path) async {
    final token = await _getToken();
    return _send(
      () => ApiClient.instance.delete(path, headers: _headers(token)),
    );
  }

  /// Fetches every watchlist for the logged-in user, including symbols.
  Future<List<WatchlistListData>> fetchWatchlists() async {
    final res = await _get('/watchlist');
    final body = _decode(res);
    if (res.statusCode != 200 || body['success'] != true) {
      throw WatchlistApiException(
        body['message']?.toString() ?? 'Failed to load watchlists',
        statusCode: res.statusCode,
      );
    }
    final lists = (body['watchlists'] as List?) ?? const [];
    return lists
        .whereType<Map>()
        .map((list) {
          final l = list.cast<String, dynamic>();
          final symbols = (l['symbols'] as List?) ?? const [];
          return WatchlistListData(
            id: l['id']?.toString() ?? '',
            name: l['name']?.toString() ?? 'My Watchlist',
            symbols: symbols
                .whereType<Map>()
                .map((s) => (s['symbol'] ?? '').toString())
                .toList(),
          );
        })
        .toList();
  }

  /// Creates a new (empty) named watchlist. Returns the persisted list.
  Future<WatchlistListData> createList(String name) async {
    final res = await _post('/watchlist', {'name': name});
    final body = _decode(res);
    if (res.statusCode != 201 || body['success'] != true) {
      throw WatchlistApiException(
        body['message']?.toString() ?? 'Failed to create watchlist',
        statusCode: res.statusCode,
      );
    }
    final w = (body['watchlist'] as Map?)?.cast<String, dynamic>() ?? const {};
    return WatchlistListData(
      id: w['id']?.toString() ?? '',
      name: w['name']?.toString() ?? name,
      symbols: const [],
    );
  }

  Future<void> renameList({
    required String listId,
    required String name,
  }) async {
    final res = await _put('/watchlist/$listId', {'name': name});
    final body = _decode(res);
    if (res.statusCode != 200 || body['success'] != true) {
      throw WatchlistApiException(
        body['message']?.toString() ?? 'Failed to rename watchlist',
        statusCode: res.statusCode,
      );
    }
  }

  Future<void> deleteList({required String listId}) async {
    final res = await _delete('/watchlist/$listId');
    final body = _decode(res);
    if (res.statusCode != 200 || body['success'] != true) {
      throw WatchlistApiException(
        body['message']?.toString() ?? 'Failed to delete watchlist',
        statusCode: res.statusCode,
      );
    }
  }

  Future<void> addSymbol({
    required String listId,
    required String symbol,
    String? company,
  }) async {
    final res = await _post(
      '/watchlist/$listId/symbols',
      {'symbol': symbol, 'company': ?company},
    );
    final body = _decode(res);
    // Accepted if the symbol was newly added OR already present (idempotent).
    if (res.statusCode != 201 && res.statusCode != 200) {
      throw WatchlistApiException(
        body['message']?.toString() ?? 'Failed to add stock',
        statusCode: res.statusCode,
      );
    }
  }

  Future<void> removeSymbol({
    required String listId,
    required String symbol,
  }) async {
    final res = await _delete('/watchlist/$listId/symbols/$symbol');
    final body = _decode(res);
    if (res.statusCode != 200 || body['success'] != true) {
      throw WatchlistApiException(
        body['message']?.toString() ?? 'Failed to remove stock',
        statusCode: res.statusCode,
      );
    }
  }

  Map<String, dynamic> _decode(http.Response res) {
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {'message': 'Unexpected server response'};
    } catch (_) {
      return {'message': 'Unexpected server response'};
    }
  }
}
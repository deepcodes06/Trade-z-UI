import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;

import 'package:http/http.dart' as http;

import '../../constants/app_config.dart';
import 'api_client.dart';

class MarketApiException implements Exception {
  final String message;
  final int? statusCode;
  MarketApiException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

/// Lightweight normalized quote for a single instrument (used for both indices
/// and individual stocks). The backend's responses vary slightly between
/// `/quote/:name`, `/quotes`, and `/dashboard`; the parsers below coerce
/// them all into this shape.
class QuoteResult {
  final String symbol;
  final String name;
  final double price;
  final double change;
  final double percentChange;
  final double volume;
  final double open;
  final double dayHigh;
  final double dayLow;
  final double previousClose;
  final double weekHigh52;
  final double weekLow52;

  const QuoteResult({
    required this.symbol,
    required this.name,
    required this.price,
    required this.change,
    required this.percentChange,
    required this.volume,
    this.open = 0,
    this.dayHigh = 0,
    this.dayLow = 0,
    this.previousClose = 0,
    this.weekHigh52 = 0,
    this.weekLow52 = 0,
  });

  @override
  String toString() =>
      'QuoteResult($symbol, name=$name, price=$price, change=$change, pct=$percentChange)';
}

/// HTTP client for the TradeZ backend's market routes (`/api/market/*`).
///
/// The backend wraps successful responses in `{ success: true, data: ... }`
/// and failures in `{ success: false, message: "..." }` (see
/// server/src/utils/response.js). This client unwraps that envelope and
/// normalizes the two slightly-different quote shapes (one symbol vs many)
/// into a list of [QuoteResult]s so the rest of the app never has to care.
class MarketApi {
  MarketApi._();
  static final MarketApi instance = MarketApi._();

  static const String _logName = 'MarketApi';

  void _log(String message, {Object? error, StackTrace? stackTrace}) {
    dev.log(message, name: _logName, error: error, stackTrace: stackTrace);
  }

  Map<String, String> _headers(String? token) => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  /// Build a URL against the currently-known base host (used by the SSE
  /// stream, which needs a concrete URL up front).
  Future<Uri> _u(String path, [Map<String, String>? query]) async {
    final base = await ApiClient.instance.bestBaseUrl;
    final u = Uri.parse('$base${AppConfig.apiPrefix}$path');
    return query == null ? u : u.replace(queryParameters: query);
  }

  /// One-time startup log so the very first thing in the log explains what
  /// the app is about to do.
  void logStartupStatus() {
    _log('MarketApi: talking to backend at ${AppConfig.apiBaseUrl}${AppConfig.apiPrefix}');
  }

  /// Fallback-friendly wrapper: throws a user-friendly [MarketApiException]
  /// when every backend host is unreachable.
  Future<http.Response> _get(
    String path, {
    Map<String, String>? query,
    Map<String, String>? headers,
  }) async {
    try {
      return await ApiClient.instance.get(path, query: query, headers: headers);
    } on ApiHostUnreachableException catch (e) {
      throw MarketApiException(
        'Could not reach the server. Check your connection. (${e.cause})',
      );
    }
  }

  Future<http.Response> _post(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    try {
      return await ApiClient.instance.post(path, headers: headers, body: body);
    } on ApiHostUnreachableException catch (e) {
      throw MarketApiException(
        'Could not reach the server. Check your connection. (${e.cause})',
      );
    }
  }

  /// The watchlist/stock detail endpoints are authenticated — when there's a
  /// stored JWT, every request will carry it. Market data itself is public
  /// on the backend (no auth middleware on /api/market/*), but we still
  /// forward the token if it's there in case the backend changes that later.
  Future<String?> _token() async => null;

  /// GET /api/market/dashboard → trending + nseMostActive + bseMostActive +
  /// priceShockers + indices + marketStatus. The home screen uses the
  /// indices as the "indices grid" and nseMostActive as the "top stocks"
  /// feed.
  Future<Map<String, dynamic>> getDashboard() async {
    final token = await _token();
    final sw = Stopwatch()..start();
    final res = await _get('/market/dashboard', headers: _headers(token));
    sw.stop();
    _log('GET /market/dashboard -> ${res.statusCode} in ${sw.elapsedMilliseconds}ms');
    return _unwrap(res, expected: 200) as Map<String, dynamic>;
  }

  /// POST /api/market/quotes — body `{ stocks: [symbol, ...] }`. Returns
  /// the backend's normalized quote array.
  Future<List<dynamic>> getQuotes(List<String> symbols) async {
    if (symbols.isEmpty) return const [];
    final token = await _token();
    final res = await _post(
      '/market/quotes',
      headers: _headers(token),
      body: jsonEncode({'stocks': symbols}),
    );
    _log('POST /market/quotes (${symbols.length}) -> ${res.statusCode}');
    final data = _unwrap(res, expected: 200);
    return data is List ? data : const [];
  }

  /// GET /api/market/quote/:stockName — used by the stock detail page when
  /// the watchlist only has a single symbol to refresh.
  Future<Map<String, dynamic>> getQuote(String stockName) async {
    final token = await _token();
    final res = await _get('/market/quote/$stockName', headers: _headers(token));
    _log('GET /market/quote/$stockName -> ${res.statusCode}');
    return _unwrap(res, expected: 200) as Map<String, dynamic>;
  }

  /// GET /api/market/history/:stockName?period=1yr&filter=default — used
  /// for the chart on the stock detail page.
  Future<List<dynamic>> getHistory(
    String stockName, {
    String period = '1yr',
    String filter = 'default',
  }) async {
    final token = await _token();
    final res = await _get(
      '/market/history/$stockName',
      query: {'period': period, 'filter': filter},
      headers: _headers(token),
    );
    _log('GET /market/history/$stockName?period=$period -> ${res.statusCode}');
    final data = _unwrap(res, expected: 200);
    if (data is List) return data;
    if (data is Map && data['values'] is List) return List<dynamic>.from(data['values'] as List);
    if (data is Map && data['data'] is List) return List<dynamic>.from(data['data'] as List);
    return const [];
  }

  /// GET /api/market/search?query=... — debounced typeahead on the search
  /// page. Returns whatever shape the backend's `search` controller yields.
  Future<List<dynamic>> search(String query) async {
    if (query.trim().isEmpty) return const [];
    final token = await _token();
    final res = await _get(
      '/market/search',
      query: {'query': query},
      headers: _headers(token),
    );
    _log('GET /market/search?query=$query -> ${res.statusCode}');
    final data = _unwrap(res, expected: 200);
    return data is List ? data : const [];
  }

  /// GET /api/market/indices/:symbol — a single live index with OHLC +
  /// 52-week levels derived from its stock basket (NIFTY, NIFTY50,
  /// BANKNIFTY, SENSEX).
  Future<Map<String, dynamic>> getIndexDetail(String symbol) async {
    final token = await _token();
    final res = await _get('/market/indices/$symbol', headers: _headers(token));
    _log('GET /market/indices/$symbol -> ${res.statusCode}');
    return _unwrap(res, expected: 200) as Map<String, dynamic>;
  }

  /// GET /api/market/index-history/:symbol?period=1yr&filter=default —
  /// synthesized candle series for an index chart (same chart ranges as
  /// stock history).
  Future<List<dynamic>> getIndexHistory(
    String symbol, {
    String period = '1yr',
    String filter = 'default',
  }) async {
    final token = await _token();
    final res = await _get(
      '/market/index-history/$symbol',
      query: {'period': period, 'filter': filter},
      headers: _headers(token),
    );
    _log('GET /market/index-history/$symbol?period=$period -> ${res.statusCode}');
    final data = _unwrap(res, expected: 200);
    if (data is List) return data;
    if (data is Map && data['data'] is List) return List<dynamic>.from(data['data'] as List);
    return const [];
  }

  /// Unwrap the standard `{ success, data, message }` envelope. Throws a
  /// [MarketApiException] with a useful message on either an HTTP error or
  /// an `success: false` payload.
  dynamic _unwrap(http.Response res, {required int expected}) {
    Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) {
        throw MarketApiException(
          'Unexpected response shape (status ${res.statusCode})',
          statusCode: res.statusCode,
        );
      }
      body = decoded;
    } catch (e) {
      throw MarketApiException(
        'Could not decode server response (status ${res.statusCode})',
        statusCode: res.statusCode,
      );
    }

    if (res.statusCode != expected || body['success'] == false) {
      final msg = body['message']?.toString() ??
          body['error']?.toString() ??
          'Request failed (status ${res.statusCode})';
      throw MarketApiException(msg, statusCode: res.statusCode);
    }
    return body['data'];
  }

  // ---------------------------------------------------------------------------
  // Live SSE stream — `/api/market/stream`
  //
  // Subscribes to the realtime simulator's per-second price ticks. The
  // server emits two named events:
  //   - `snapshot` — full quote list, sent once on connect
  //   - `tick`     — payload sent every ~1s with current prices + tickAt
  //
  // Usage:
  //   final sub = MarketApi.instance.subscribeToStream(
  //     onSnapshot: (quotes) => ...,
  //     onTick:     (payload) => ...,
  //     onError:    (err) => ...,
  //   );
  //   ...
  //   await sub.cancel();
  // ---------------------------------------------------------------------------

  StreamSubscription<String> subscribeToStream({
    void Function(List<Map<String, dynamic>> quotes)? onSnapshot,
    void Function(Map<String, dynamic> payload)? onTick,
    void Function(Object error)? onError,
  }) {
    final client = http.Client();
    var cancelled = false;

    final controller = StreamController<String>(
      onCancel: () async {
        cancelled = true;
        client.close();
      },
    );

    Future<void> run() async {
      try {
        final request = http.Request('GET', await _u('/market/stream'))
          ..headers.addAll({
            'Accept': 'text/event-stream',
            'Cache-Control': 'no-cache',
          });
        final response = await client.send(request);
        if (cancelled) {
          await response.stream.drain<void>();
          return;
        }
        if (response.statusCode != 200) {
          await response.stream.drain<void>();
          throw MarketApiException(
            'SSE stream returned ${response.statusCode}',
            statusCode: response.statusCode,
          );
        }

        var currentEvent = 'message';
        final buffer = StringBuffer();

        void dispatch() {
          final data = buffer.toString();
          buffer.clear();
          if (data.isEmpty) return;
          try {
            final decoded = jsonDecode(data);
            if (decoded is! Map<String, dynamic>) return;
            final body = decoded['data'] ?? decoded;
            if (currentEvent == 'snapshot' && body is List && onSnapshot != null) {
              onSnapshot(body.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList());
            } else if (currentEvent == 'tick' && body is Map<String, dynamic> && onTick != null) {
              onTick(body);
            }
          } catch (e) {
            if (onError != null) onError(e);
          }
        }

        await for (final line in response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
          if (cancelled) break;
          if (line.isEmpty) {
            dispatch();
            currentEvent = 'message';
            continue;
          }
          if (line.startsWith(':')) continue;
          if (line.startsWith('event: ')) {
            currentEvent = line.substring(7).trim();
          } else if (line.startsWith('data: ')) {
            if (buffer.isNotEmpty) buffer.write('\n');
            buffer.write(line.substring(6));
          }
          if (!controller.isClosed) controller.add(line);
        }
        dispatch();
      } catch (e) {
        if (onError != null) onError(e);
        if (!controller.isClosed) controller.addError(e);
      } finally {
        if (!controller.isClosed) controller.close();
      }
    }

    run();
    return controller.stream.listen(
      (_) {},
      onError: onError,
    );
  }
}

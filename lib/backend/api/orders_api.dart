import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/order_model.dart';
import '../models/portfolio_holding_model.dart';
import '../services/secure_store.dart';
import 'api_client.dart';
import 'market_api.dart';

class OrdersApiException implements Exception {
  final String message;
  final int? statusCode;
  OrdersApiException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

class OrdersApi {
  OrdersApi._();
  static final OrdersApi instance = OrdersApi._();

  static const String _tokenKey = 'auth_jwt_token';

  Future<String> _getToken() async {
    final token = await SecureStore.readEncrypted(_tokenKey);
    if (token == null) throw OrdersApiException('Not authenticated');
    return token;
  }

  Future<http.Response> _get(String path, {Map<String, String>? headers}) async {
    try {
      return await ApiClient.instance.get(path, headers: headers);
    } on ApiHostUnreachableException catch (e) {
      throw OrdersApiException(
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
      throw OrdersApiException(
        'Could not reach the server. Check your connection. (${e.cause})',
      );
    }
  }

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  /// GET /api/trade/history — the user's order/trade book.
  Future<List<OrderModel>> fetchOrders() async {
    final token = await _getToken();
    final res = await _get('/trade/history', headers: _headers(token));
    final body = _decode(res);
    if (res.statusCode != 200 || body['success'] != true) {
      throw OrdersApiException(
        body['message']?.toString() ?? 'Failed to fetch orders',
        statusCode: res.statusCode,
      );
    }
    final list = (body['history'] as List?) ?? const [];
    return list
        .whereType<Map>()
        .map((m) => _orderFromMap(m.cast<String, dynamic>()))
        .toList();
  }

  /// GET /api/portfolio — current open positions (the backend also returns
  /// the same shape for any historical record, but conceptually this is the
  /// "what do I hold right now" endpoint).
  Future<List<PositionModel>> fetchPositions() async {
    final token = await _getToken();
    final res = await _get('/portfolio', headers: _headers(token));
    final body = _decode(res);
    if (res.statusCode != 200 || body['success'] != true) {
      throw OrdersApiException(
        body['message']?.toString() ?? 'Failed to fetch positions',
        statusCode: res.statusCode,
      );
    }
    final list = (body['portfolio'] as List?) ?? const [];
    return list
        .whereType<Map>()
        .map((m) => _positionFromMap(m.cast<String, dynamic>()))
        .toList();
  }

  /// GET /api/portfolio enriched with live market quotes. Returns
  /// [PortfolioHoldingModel]s with real-time P&L computed against
  /// the live LTP and yesterday's close.
  Future<List<PortfolioHoldingModel>> fetchPortfolioHoldings() async {
    final token = await _getToken();
    final res = await _get('/portfolio', headers: _headers(token));
    final body = _decode(res);
    if (res.statusCode != 200 || body['success'] != true) {
      throw OrdersApiException(
        body['message']?.toString() ?? 'Failed to fetch portfolio',
        statusCode: res.statusCode,
      );
    }
    final rawList = (body['portfolio'] as List?) ?? const [];
    if (rawList.isEmpty) return const [];

    final rawHoldings = rawList
        .whereType<Map>()
        .map((m) => m.cast<String, dynamic>())
        .toList();

    final symbols = rawHoldings.map((m) => (m['symbol']?.toString() ?? '')).where((s) => s.isNotEmpty).toList();

    List<Map<String, dynamic>> quotes = const [];
    if (symbols.isNotEmpty) {
      try {
        final quoteRes = await MarketApi.instance.getQuotes(symbols);
        quotes = quoteRes.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
      } catch (_) {}
    }

    final quoteMap = <String, Map<String, dynamic>>{};
    for (final q in quotes) {
      final s = (q['symbol'] ?? q['ticker'] ?? '').toString();
      if (s.isNotEmpty) quoteMap[s] = q;
    }

    return rawHoldings.map((m) {
      final symbol = (m['symbol'] ?? '').toString();
      final company = (m['company'] ?? symbol).toString();
      final qty = m['quantity'] is int ? m['quantity'] as int : int.tryParse(m['quantity'].toString()) ?? 0;
      final avg = _toDouble(m['avgPrice']);
      final invested = _toDouble(m['invested']);
      final q = quoteMap[symbol];
      final ltp = q != null ? _toDouble(q['currentPrice'] ?? q['price'] ?? q['ltp']) : avg;
      final prevClose = q != null ? _toDouble(q['previousClose'] ?? q['prevClose']) : avg;
      final dayChange = ltp - prevClose;
      final dayChangePct = prevClose > 0 ? (dayChange / prevClose) * 100 : 0.0;
      final overallPnl = (ltp - avg) * qty;
      final overallPnlPct = avg > 0 ? ((ltp - avg) / avg) * 100 : 0.0;
      return PortfolioHoldingModel(
        symbol: symbol,
        company: company,
        quantity: qty,
        avgPrice: avg,
        invested: invested,
        currentLtp: ltp,
        previousClose: prevClose,
        dayChange: dayChange,
        dayChangePct: dayChangePct,
        overallPnl: overallPnl,
        overallPnlPct: overallPnlPct,
      );
    }).toList();
  }

  /// POST /api/trade/buy — places a market/limit BUY order server-side.
  /// `company` is optional; the backend will store whatever you pass.
  Future<void> buyStock({
    required String symbol,
    String? company,
    required int quantity,
    required double price,
  }) async {
    final token = await _getToken();
    final res = await _post(
      '/trade/buy',
      headers: _headers(token),
      body: jsonEncode({
        'symbol': symbol,
        if (company != null) 'company': company, // ignore: use_null_aware_elements
        'quantity': quantity,
        'price': price,
      }),
    );
    final body = _decode(res);
    if ((res.statusCode != 200 && res.statusCode != 201) ||
        body['success'] != true) {
      throw OrdersApiException(
        body['message']?.toString() ?? 'Buy order failed',
        statusCode: res.statusCode,
      );
    }
  }

  /// POST /api/trade/sell — places a SELL order. Quantity/price required;
  /// the backend rejects the request if the user doesn't hold enough.
  Future<void> sellStock({
    required String symbol,
    required int quantity,
    required double price,
  }) async {
    final token = await _getToken();
    final res = await _post(
      '/trade/sell',
      headers: _headers(token),
      body: jsonEncode({
        'symbol': symbol,
        'quantity': quantity,
        'price': price,
      }),
    );
    final body = _decode(res);
    if (res.statusCode != 200 || body['success'] != true) {
      throw OrdersApiException(
        body['message']?.toString() ?? 'Sell order failed',
        statusCode: res.statusCode,
      );
    }
  }

  OrderModel _orderFromMap(Map<String, dynamic> m) {
    return OrderModel(
      id: m['id']?.toString() ?? '',
      symbol: m['symbol']?.toString() ?? '',
      side: _parseOrderSide(m['type']),
      type: OrderType.market,
      qty: m['quantity'] is int
          ? m['quantity'] as int
          : int.tryParse(m['quantity'].toString()) ?? 0,
      price: _toDouble(m['price']),
      status: OrderStatus.executed,
      time: m['createdAt'] != null
          ? DateTime.tryParse(m['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  PositionModel _positionFromMap(Map<String, dynamic> m) {
    final qty = m['quantity'] is int
        ? m['quantity'] as int
        : int.tryParse(m['quantity'].toString()) ?? 0;
    final avg = _toDouble(m['avgPrice']);
    final invested = _toDouble(m['invested']);
    // LTP isn't stored on the portfolio record; the detail page will
    // refresh it from the market endpoint. We use avgPrice as a placeholder
    // so the "current value" never looks like 0 if the live refresh is
    // still pending.
    final ltp = avg;
    return PositionModel(
      symbol: m['symbol']?.toString() ?? '',
      qty: qty,
      avgPrice: avg,
      ltp: ltp,
      pnl: ltp * qty - invested,
    );
  }

  OrderSide _parseOrderSide(dynamic v) {
    if (v is OrderSide) return v;
    final str = v?.toString().toUpperCase();
    if (str == 'BUY') return OrderSide.buy;
    if (str == 'SELL') return OrderSide.sell;
    return OrderSide.buy;
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

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
}

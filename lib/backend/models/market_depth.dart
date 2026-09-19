import 'package:equatable/equatable.dart';

/// One level of the order book (market depth) — what you see in a typical
/// broker app's bid/ask ladder. [price] is the limit price, [quantity] is the
/// total shares queued at that level, [orders] is how many individual orders
/// make up that quantity.
class DepthLevel extends Equatable {
  final double price;
  final int quantity;
  final int orders;

  const DepthLevel({
    required this.price,
    required this.quantity,
    required this.orders,
  });

  factory DepthLevel.fromMap(Map<String, dynamic> m) => DepthLevel(
        price: _d(m['price']),
        quantity: (_d(m['quantity'])).round(),
        orders: (_d(m['orders'])).round(),
      );

  static double _d(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  @override
  List<Object?> get props => [price, quantity, orders];
}

/// The full 5-level bid/ask ladder plus totals. Rendered by the Stock
/// Detail page's `_MarketDepthCard`. Order books come from the simulator's
/// per-tick depth refresh.
class MarketDepth extends Equatable {
  final List<DepthLevel> bids;
  final List<DepthLevel> asks;
  final int totalBuyQty;
  final int totalSellQty;

  const MarketDepth({
    required this.bids,
    required this.asks,
    required this.totalBuyQty,
    required this.totalSellQty,
  });

  bool get isEmpty =>
      bids.isEmpty && asks.isEmpty && totalBuyQty == 0 && totalSellQty == 0;

  factory MarketDepth.fromMap(Map<String, dynamic> m) {
    final bids = ((m['bids'] as List?) ?? const [])
        .whereType<Map>()
        .map((b) => DepthLevel.fromMap(b.cast<String, dynamic>()))
        .toList();
    final asks = ((m['asks'] as List?) ?? const [])
        .whereType<Map>()
        .map((a) => DepthLevel.fromMap(a.cast<String, dynamic>()))
        .toList();
    return MarketDepth(
      bids: bids,
      asks: asks,
      totalBuyQty: (DepthLevel._d(m['totalBuyQty'])).round(),
      totalSellQty: (DepthLevel._d(m['totalSellQty'])).round(),
    );
  }

  /// Empty depth used when the server didn't provide one.
  static const MarketDepth empty = MarketDepth(
    bids: [],
    asks: [],
    totalBuyQty: 0,
    totalSellQty: 0,
  );

  @override
  List<Object?> get props => [bids, asks, totalBuyQty, totalSellQty];
}
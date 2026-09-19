import 'package:equatable/equatable.dart';

enum OrderSide { buy, sell }

enum OrderStatus { pending, executed, rejected, cancelled }

enum OrderType { market, limit, sl, slM }

class OrderModel extends Equatable {
  final String id;
  final String symbol;
  final OrderSide side;
  final OrderType type;
  final int qty;
  final double price;
  final OrderStatus status;
  final DateTime time;

  const OrderModel({
    required this.id,
    required this.symbol,
    required this.side,
    required this.type,
    required this.qty,
    required this.price,
    required this.status,
    required this.time,
  });

  @override
  List<Object?> get props =>
      [id, symbol, side, type, qty, price, status, time];
}

class PositionModel extends Equatable {
  final String symbol;
  final int qty;
  final double avgPrice;
  final double ltp;
  final double pnl;

  const PositionModel({
    required this.symbol,
    required this.qty,
    required this.avgPrice,
    required this.ltp,
    required this.pnl,
  });

  @override
  List<Object?> get props => [symbol, qty, avgPrice, ltp, pnl];
}

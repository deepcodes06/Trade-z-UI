import 'package:equatable/equatable.dart';

class PortfolioHoldingModel extends Equatable {
  final String symbol;
  final String company;
  final int quantity;
  final double avgPrice;
  final double invested;
  final double currentLtp;
  final double previousClose;
  final double dayChange;
  final double dayChangePct;
  final double overallPnl;
  final double overallPnlPct;

  const PortfolioHoldingModel({
    required this.symbol,
    required this.company,
    required this.quantity,
    required this.avgPrice,
    required this.invested,
    required this.currentLtp,
    required this.previousClose,
    required this.dayChange,
    required this.dayChangePct,
    required this.overallPnl,
    required this.overallPnlPct,
  });

  double get currentValue => currentLtp * quantity;
  double get dayPnl => (currentLtp - previousClose) * quantity;
  bool get dayPnlPositive => dayPnl >= 0;
  bool get overallPnlPositive => overallPnl >= 0;

  @override
  List<Object?> get props => [
        symbol,
        company,
        quantity,
        avgPrice,
        invested,
        currentLtp,
        previousClose,
        dayChange,
        dayChangePct,
        overallPnl,
        overallPnlPct,
      ];
}

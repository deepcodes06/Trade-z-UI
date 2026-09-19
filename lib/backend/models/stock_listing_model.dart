import 'package:equatable/equatable.dart';

/// A lightweight entry from Twelve Data's `/stocks` symbol catalog — used to
/// power local, instant search across the full NSE + BSE symbol list rather
/// than hitting the network on every keystroke.
class StockListing extends Equatable {
  final String symbol;
  final String name;
  final String exchange; // 'NSE' or 'BSE'
  final String type; // e.g. 'Common Stock', 'ETF'

  const StockListing({
    required this.symbol,
    required this.name,
    required this.exchange,
    this.type = 'Common Stock',
  });

  @override
  List<Object?> get props => [symbol, name, exchange, type];
}

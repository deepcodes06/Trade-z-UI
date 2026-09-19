import 'package:equatable/equatable.dart';

class IndexModel extends Equatable {
  final String symbol;
  final String name;
  final double last;
  final double change;
  final double percentChange;
  final double open;
  final double dayHigh;
  final double dayLow;
  final double previousClose;
  final double weekHigh52;
  final double weekLow52;

  const IndexModel({
    required this.symbol,
    required this.name,
    required this.last,
    required this.change,
    required this.percentChange,
    this.open = 0,
    this.dayHigh = 0,
    this.dayLow = 0,
    this.previousClose = 0,
    this.weekHigh52 = 0,
    this.weekLow52 = 0,
  });

  bool get isUp => change >= 0;

  @override
  List<Object?> get props => [
        symbol,
        name,
        last,
        change,
        percentChange,
        open,
        dayHigh,
        dayLow,
        previousClose,
        weekHigh52,
        weekLow52,
      ];
}
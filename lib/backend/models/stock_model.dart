import 'package:equatable/equatable.dart';

class StockModel extends Equatable {
  final String symbol;
  final String name;
  final double ltp;
  final double change;
  final double percentChange;
  final double volume;
  final bool isBlowUpSignal;

  const StockModel({
    required this.symbol,
    required this.name,
    required this.ltp,
    required this.change,
    required this.percentChange,
    required this.volume,
    this.isBlowUpSignal = false,
  });

  bool get isUp => change >= 0;

  StockModel copyWith({bool? isBlowUpSignal}) => StockModel(
        symbol: symbol,
        name: name,
        ltp: ltp,
        change: change,
        percentChange: percentChange,
        volume: volume,
        isBlowUpSignal: isBlowUpSignal ?? this.isBlowUpSignal,
      );

  @override
  List<Object?> get props =>
      [symbol, name, ltp, change, percentChange, volume, isBlowUpSignal];
}

import 'package:equatable/equatable.dart';

class CandleModel extends Equatable {
  final DateTime time;
  final double close;
  final double high;
  final double low;
  final double volume;

  const CandleModel({
    required this.time,
    required this.close,
    required this.high,
    required this.low,
    this.volume = 0,
  });

  @override
  List<Object?> get props => [time, close, high, low, volume];
}

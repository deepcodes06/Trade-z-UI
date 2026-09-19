import 'package:equatable/equatable.dart';
import '../../models/index_model.dart';
import '../../models/stock_model.dart';

enum HomeStatus { initial, loading, success, failure }

class HomeState extends Equatable {
  final HomeStatus status;
  final List<IndexModel> indices;
  final List<StockModel> topStocks;
  final String? error;
  final bool isLive;
  final bool isMarketOpen;
  final DateTime? lastUpdated;

  const HomeState({
    this.status = HomeStatus.initial,
    this.indices = const [],
    this.topStocks = const [],
    this.error,
    this.isLive = false,
    this.isMarketOpen = true,
    this.lastUpdated,
  });

  HomeState copyWith({
    HomeStatus? status,
    List<IndexModel>? indices,
    List<StockModel>? topStocks,
    String? error,
    bool? isLive,
    bool? isMarketOpen,
    DateTime? lastUpdated,
  }) =>
      HomeState(
        status: status ?? this.status,
        indices: indices ?? this.indices,
        topStocks: topStocks ?? this.topStocks,
        error: error,
        isLive: isLive ?? this.isLive,
        isMarketOpen: isMarketOpen ?? this.isMarketOpen,
        lastUpdated: lastUpdated ?? this.lastUpdated,
      );

  @override
  List<Object?> get props =>
      [status, indices, topStocks, error, isLive, isMarketOpen, lastUpdated];
}

import 'package:equatable/equatable.dart';
import '../../models/stock_model.dart';
import '../../models/watchlist_model.dart';

enum WatchlistStatus { initial, loading, ready, failure }

class WatchlistState extends Equatable {
  static const int maxLists = 5;
  static const int maxStocksPerList = 50;

  final WatchlistStatus status;
  final List<WatchlistModel> lists;
  final String? activeId;
  final String? error;
  final List<StockModel> activeStocks;
  final bool isLive;
  final DateTime? lastUpdated;

  const WatchlistState({
    this.status = WatchlistStatus.initial,
    this.lists = const [],
    this.activeId,
    this.error,
    this.activeStocks = const [],
    this.isLive = false,
    this.lastUpdated,
  });

  WatchlistState copyWith({
    WatchlistStatus? status,
    List<WatchlistModel>? lists,
    String? activeId,
    String? error,
    bool clearActive = false,
    List<StockModel>? activeStocks,
    bool? isLive,
    DateTime? lastUpdated,
  }) =>
      WatchlistState(
        status: status ?? this.status,
        lists: lists ?? this.lists,
        activeId: clearActive ? null : (activeId ?? this.activeId),
        error: error,
        activeStocks: activeStocks ?? this.activeStocks,
        isLive: isLive ?? this.isLive,
        lastUpdated: lastUpdated ?? this.lastUpdated,
      );

  @override
  List<Object?> get props =>
      [status, lists, activeId, error, activeStocks, isLive, lastUpdated];
}

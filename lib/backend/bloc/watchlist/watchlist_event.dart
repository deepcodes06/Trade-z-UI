import 'package:equatable/equatable.dart';

abstract class WatchlistEvent extends Equatable {
  const WatchlistEvent();
  @override
  List<Object?> get props => [];
}

class WatchlistsLoadRequested extends WatchlistEvent {
  const WatchlistsLoadRequested();
}

class WatchlistCreateRequested extends WatchlistEvent {
  final String name;
  const WatchlistCreateRequested(this.name);
  @override
  List<Object?> get props => [name];
}

class WatchlistRenameRequested extends WatchlistEvent {
  final String id;
  final String name;
  const WatchlistRenameRequested({required this.id, required this.name});
  @override
  List<Object?> get props => [id, name];
}

class WatchlistDeleteRequested extends WatchlistEvent {
  final String id;
  const WatchlistDeleteRequested(this.id);
  @override
  List<Object?> get props => [id];
}

class WatchlistAddStockRequested extends WatchlistEvent {
  final String watchlistId;
  final String symbol;
  const WatchlistAddStockRequested({required this.watchlistId, required this.symbol});
  @override
  List<Object?> get props => [watchlistId, symbol];
}

class WatchlistRemoveStockRequested extends WatchlistEvent {
  final String watchlistId;
  final String symbol;
  const WatchlistRemoveStockRequested({required this.watchlistId, required this.symbol});
  @override
  List<Object?> get props => [watchlistId, symbol];
}

class WatchlistActiveStocksRequested extends WatchlistEvent {
  final String watchlistId;
  const WatchlistActiveStocksRequested(this.watchlistId);
  @override
  List<Object?> get props => [watchlistId];
}

class WatchlistRefreshRequested extends WatchlistEvent {
  const WatchlistRefreshRequested();
}

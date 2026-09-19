import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../repositories/market_repository.dart';
import '../../../utils/market_hours.dart';
import 'home_event.dart';
import 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  static const String _logName = 'HomeBloc';
  // 20s (not 15s) - see the matching comment in WatchlistBloc for why.
  static const Duration _refreshInterval = Duration(seconds: 20);

  final MarketRepository _repo;
  Timer? _refreshTimer;

  HomeBloc({MarketRepository? repository})
      : _repo = repository ?? MarketRepository(),
        super(const HomeState()) {
    on<HomeLoadRequested>(_onLoad);
    on<HomeRefreshRequested>(_onRefresh);
    on<_HomeAutoTick>(_onAutoTick);
  }

  void _log(String msg) => dev.log(msg, name: _logName);

  void startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      if (isClosed) return;
      add(const _HomeAutoTick());
    });
    _log('auto-refresh started (${_refreshInterval.inSeconds}s)');
  }

  @override
  Future<void> close() {
    _refreshTimer?.cancel();
    return super.close();
  }

  Future<void> _onLoad(HomeLoadRequested e, Emitter<HomeState> emit) async {
    _log('HomeLoadRequested');
    emit(state.copyWith(status: HomeStatus.loading));
    await _fetch(emit, source: 'load', forceRefresh: false);
    startAutoRefresh();
  }

  Future<void> _onRefresh(HomeRefreshRequested e, Emitter<HomeState> emit) async {
    _log('HomeRefreshRequested');
    await _fetch(emit, source: 'refresh', forceRefresh: true);
  }

  Future<void> _onAutoTick(_HomeAutoTick e, Emitter<HomeState> emit) async {
    // Outside NSE hours the market is settled: don't hammer the server, just
    // keep showing the last known prices.
    if (!MarketHours.isOpen()) return;
    _log('auto tick');
    await _fetch(emit, source: 'auto');
  }

  Future<void> _fetch(Emitter<HomeState> emit, {required String source, bool forceRefresh = false}) async {
    try {
      final indices = await _repo.fetchIndices(forceRefresh: forceRefresh);
      final stocks = await _repo.fetchTopStocks(forceRefresh: forceRefresh);
      _log('[$source] indices=${indices.length} stocks=${stocks.length}');
      emit(state.copyWith(
        status: HomeStatus.success,
        indices: indices,
        topStocks: stocks,
        isLive: _repo.isLive,
        isMarketOpen: _repo.isMarketOpen,
        lastUpdated: DateTime.now(),
      ));
    } catch (e, st) {
      _log('[$source] failed: $e\n$st');
      emit(state.copyWith(status: HomeStatus.failure, error: e.toString()));
    }
  }
}

class _HomeAutoTick extends HomeEvent {
  const _HomeAutoTick();
}

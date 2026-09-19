import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../api/watchlist_api.dart';
import '../../models/stock_model.dart';
import '../../repositories/market_repository.dart';
import '../../models/watchlist_model.dart';
import '../../services/notification_service.dart';
import '../../../utils/market_hours.dart';
import 'watchlist_event.dart';
import 'watchlist_state.dart';

class WatchlistBloc extends Bloc<WatchlistEvent, WatchlistState> {
  static const String _logName = 'WatchlistBloc';
  // 20s (not 15s) to leave more of the backend rate budget for other screens
  // (Home, Stock Detail) polling at the same time.
  static const Duration _refreshInterval = Duration(seconds: 20);

  final MarketRepository _repo;
  final WatchlistApi _api;
  Timer? _refreshTimer;
  final Set<String> _notifiedSymbols = <String>{};

  WatchlistBloc({MarketRepository? repository, WatchlistApi? api})
      : _repo = repository ?? MarketRepository(),
        _api = api ?? WatchlistApi.instance,
        super(const WatchlistState()) {
    on<WatchlistsLoadRequested>(_onLoad);
    on<WatchlistCreateRequested>(_onCreate);
    on<WatchlistRenameRequested>(_onRename);
    on<WatchlistDeleteRequested>(_onDelete);
    on<WatchlistAddStockRequested>(_onAdd);
    on<WatchlistRemoveStockRequested>(_onRemove);
    on<WatchlistActiveStocksRequested>(_onFetchActive);
    on<WatchlistRefreshRequested>(_onRefresh);
    on<_WatchlistAutoTick>(_onAutoTick);
  }

  void _log(String msg) => dev.log(msg, name: _logName);

  void startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      if (isClosed) return;
      add(const _WatchlistAutoTick());
    });
    _log('auto-refresh started (${_refreshInterval.inSeconds}s)');
  }

  @override
  Future<void> close() {
    _refreshTimer?.cancel();
    return super.close();
  }

  void _maybeNotifyForBlowUp(List<StockModel> stocks) {
    for (final stock in stocks) {
      if (!stock.isBlowUpSignal || _notifiedSymbols.contains(stock.symbol)) continue;
      _notifiedSymbols.add(stock.symbol);
      unawaited(NotificationService.instance.showBlowUp(stock.symbol));
    }
  }

  // Users on a real trading app have their watchlists stored on the server, so
  // removed stocks never silently come back. We hydrate from the backend and
  // only create a default (empty) list the very first time the account shows
  // no watchlist at all.
  Future<void> _onLoad(
      WatchlistsLoadRequested e, Emitter<WatchlistState> emit) async {
    _log('WatchlistsLoadRequested');
    emit(state.copyWith(status: WatchlistStatus.loading));

    List<WatchlistModel> lists;
    try {
      lists = await fetchWatchlistsFromServer();
    } catch (err) {
      _log('failed to hydrate watchlists: $err');
      emit(state.copyWith(
        status: WatchlistStatus.failure,
        error: _friendlyError(err, fallback: 'Could not load watchlists'),
      ));
      startAutoRefresh();
      return;
    }

    final activeId = state.activeId != null &&
            lists.any((w) => w.id == state.activeId)
        ? state.activeId
        : (lists.isNotEmpty ? lists.first.id : null);

    final activeList = lists.isEmpty
        ? null
        : lists.firstWhere(
            (w) => w.id == activeId,
            orElse: () => lists.first,
          );

    final List<StockModel> active;
    try {
      active = await _repo.fetchStocks(activeList?.symbols ?? const []);
      _maybeNotifyForBlowUp(active);
    } catch (err) {
      _log('failed to fetch active quotes: $err');
      emit(state.copyWith(
        status: WatchlistStatus.ready,
        lists: lists,
        activeId: activeId,
        error: _friendlyError(err, fallback: 'Could not refresh quotes'),
      ));
      startAutoRefresh();
      return;
    }

    _log('hydrated ${lists.length} lists, active stocks: ${active.length}');
    emit(state.copyWith(
      status: WatchlistStatus.ready,
      lists: lists,
      activeId: activeId,
      activeStocks: active,
      isLive: _repo.isLive,
      lastUpdated: DateTime.now(),
      error: null,
    ));
    startAutoRefresh();
  }

  Future<List<WatchlistModel>> fetchWatchlistsFromServer() async {
    var remote = await _api.fetchWatchlists();
    if (remote.isEmpty) {
      _log('no watchlists on server — creating default');
      final created = await _api.createList('My Watchlist');
      remote = [created];
    }
    return remote
        .map((r) => WatchlistModel(
              id: r.id,
              name: r.name,
              symbols: r.symbols,
            ))
        .toList();
  }

  Future<void> _onCreate(
      WatchlistCreateRequested e, Emitter<WatchlistState> emit) async {
    if (state.lists.length >= WatchlistState.maxLists) {
      _log('max watchlists reached');
      emit(state.copyWith(error: 'Maximum ${WatchlistState.maxLists} watchlists reached'));
      return;
    }
    final name = e.name.trim().isEmpty
        ? 'Watchlist ${state.lists.length + 1}'
        : e.name.trim();

    try {
      final created = await _api.createList(name);
      final newList = WatchlistModel(
        id: created.id,
        name: created.name,
        symbols: created.symbols,
      );
      emit(state.copyWith(
        lists: [...state.lists, newList],
        activeId: newList.id,
        activeStocks: const [],
        error: null,
      ));
    } catch (err) {
      emit(state.copyWith(
        error: _friendlyError(err, fallback: 'Could not create watchlist'),
      ));
    }
  }

  Future<void> _onRename(
      WatchlistRenameRequested e, Emitter<WatchlistState> emit) async {
    try {
      await _api.renameList(listId: e.id, name: e.name);
      final updated = state.lists
          .map((w) => w.id == e.id ? w.copyWith(name: e.name) : w)
          .toList();
      emit(state.copyWith(lists: updated, error: null));
    } catch (err) {
      emit(state.copyWith(
        error: _friendlyError(err, fallback: 'Could not rename watchlist'),
      ));
    }
  }

  Future<void> _onDelete(
      WatchlistDeleteRequested e, Emitter<WatchlistState> emit) async {
    try {
      await _api.deleteList(listId: e.id);
    } catch (err) {
      emit(state.copyWith(
        error: _friendlyError(err, fallback: 'Could not delete watchlist'),
      ));
      return;
    }
    final updated = state.lists.where((w) => w.id != e.id).toList();
    emit(state.copyWith(
      lists: updated,
      activeId: state.activeId == e.id
          ? (updated.isNotEmpty ? updated.first.id : null)
          : state.activeId,
      clearActive: updated.isEmpty,
      activeStocks: state.activeId == e.id ? const [] : state.activeStocks,
    ));
  }

  Future<void> _onAdd(
      WatchlistAddStockRequested e, Emitter<WatchlistState> emit) async {
    final list = state.lists.firstWhere(
      (w) => w.id == e.watchlistId,
      orElse: () => const WatchlistModel(id: '', name: '', symbols: []),
    );
    if (list.id.isEmpty) return;

    if (list.symbols.length >= WatchlistState.maxStocksPerList) {
      emit(state.copyWith(error: 'Max ${WatchlistState.maxStocksPerList} stocks per list'));
      return;
    }
    if (list.symbols.contains(e.symbol)) {
      emit(state.copyWith(error: 'Stock already in this watchlist'));
      return;
    }

    try {
      await _api.addSymbol(listId: e.watchlistId, symbol: e.symbol);
    } catch (err) {
      emit(state.copyWith(
        error: _friendlyError(err, fallback: 'Could not add stock'),
      ));
      return;
    }

    final updated = state.lists
        .map((w) => w.id == e.watchlistId
            ? w.copyWith(symbols: [...w.symbols, e.symbol])
            : w)
        .toList();
    final newSymbols = updated
        .firstWhere((w) => w.id == e.watchlistId)
        .symbols;

    List<StockModel> stocks = state.activeStocks;
    try {
      stocks = await _repo.fetchStocks(newSymbols);
      _maybeNotifyForBlowUp(stocks);
    } catch (err) {
      // keep previous quotes on quote-fetch failure; the symbol was still
      // persisted on the server.
    }
    emit(state.copyWith(
      lists: updated,
      activeStocks: state.activeId == e.watchlistId ? stocks : state.activeStocks,
      error: null,
    ));
  }

  Future<void> _onRemove(
      WatchlistRemoveStockRequested e, Emitter<WatchlistState> emit) async {
    try {
      await _api.removeSymbol(listId: e.watchlistId, symbol: e.symbol);
    } catch (err) {
      emit(state.copyWith(
        error: _friendlyError(err, fallback: 'Could not remove stock'),
      ));
      return;
    }
    final updated = state.lists.map((w) {
      if (w.id != e.watchlistId) return w;
      return w.copyWith(symbols: w.symbols.where((s) => s != e.symbol).toList());
    }).toList();
    final stocks = state.activeStocks.where((s) => s.symbol != e.symbol).toList();
    emit(state.copyWith(
      lists: updated,
      activeStocks: state.activeId == e.watchlistId ? stocks : state.activeStocks,
      error: null,
    ));
  }

  Future<void> _onFetchActive(
      WatchlistActiveStocksRequested e, Emitter<WatchlistState> emit) async {
    final list = state.lists.firstWhere(
      (w) => w.id == e.watchlistId,
      orElse: () => const WatchlistModel(id: '', name: '', symbols: []),
    );
    if (list.id.isEmpty) return;
    final stocks = await _repo.fetchStocks(list.symbols);
    _maybeNotifyForBlowUp(stocks);
    emit(state.copyWith(
      activeId: list.id,
      activeStocks: stocks,
      isLive: _repo.isLive,
      lastUpdated: DateTime.now(),
      error: null,
    ));
  }

  Future<void> _onRefresh(
      WatchlistRefreshRequested e, Emitter<WatchlistState> emit) async {
    _log('WatchlistRefreshRequested');

    // Re-sync list membership from the server before refreshing quotes, so a
    // removal made on another session (or this one) is reflected here.
    try {
      final fresh = await fetchWatchlistsFromServer();
      final updatedLists = fresh.isEmpty ? state.lists : fresh;
      emit(state.copyWith(lists: updatedLists));
    } catch (err) {
      _log('refresh list sync failed: $err');
    }

    if (state.activeId == null) return;
    final list = state.lists.firstWhere((w) => w.id == state.activeId);
    final stocks = await _repo.fetchStocks(list.symbols);
    _maybeNotifyForBlowUp(stocks);
    _log('refreshed: ${stocks.length}/${list.symbols.length} ok');
    emit(state.copyWith(activeStocks: stocks, lastUpdated: DateTime.now()));
  }

  Future<void> _onAutoTick(
      _WatchlistAutoTick e, Emitter<WatchlistState> emit) async {
    // Market settled: keep showing last prices, stop live polling.
    if (!MarketHours.isOpen()) return;
    final id = state.activeId;
    if (id == null) return;
    final list = state.lists.firstWhere(
      (w) => w.id == id,
      orElse: () => const WatchlistModel(id: '', name: '', symbols: []),
    );
    if (list.id.isEmpty || list.symbols.isEmpty) return;
    final stocks = await _repo.fetchStocks(list.symbols);
    _maybeNotifyForBlowUp(stocks);
    emit(state.copyWith(activeStocks: stocks, lastUpdated: DateTime.now()));
  }

  String _friendlyError(Object err, {required String fallback}) {
    final apiErr = err is WatchlistApiException;
    if (apiErr) return err.message;
    return fallback;
  }
}

class _WatchlistAutoTick extends WatchlistEvent {
  const _WatchlistAutoTick();
}
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../api/orders_api.dart';
import 'portfolio_event.dart';
import 'portfolio_state.dart';

class PortfolioBloc extends Bloc<PortfolioEvent, PortfolioState> {
  final OrdersApi _api;
  PortfolioBloc({OrdersApi? api})
      : _api = api ?? OrdersApi.instance,
        super(const PortfolioState()) {
    on<PortfolioLoadRequested>(_onLoad);
    on<PortfolioRefreshRequested>(_onRefresh);
  }

  Future<void> _onLoad(
    PortfolioLoadRequested e,
    Emitter<PortfolioState> emit,
  ) async {
    emit(state.copyWith(status: PortfolioStatus.loading));
    try {
      final holdings = await _api.fetchPortfolioHoldings();
      emit(state.copyWith(
        status: PortfolioStatus.ready,
        holdings: holdings,
      ));
    } catch (error) {
      emit(state.copyWith(
        status: PortfolioStatus.failure,
        error: error.toString(),
      ));
    }
  }

  Future<void> _onRefresh(
    PortfolioRefreshRequested e,
    Emitter<PortfolioState> emit,
  ) async {
    try {
      final holdings = await _api.fetchPortfolioHoldings();
      emit(state.copyWith(
        status: PortfolioStatus.ready,
        holdings: holdings,
      ));
    } catch (_) {}
  }
}

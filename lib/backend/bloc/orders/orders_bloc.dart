import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../backend/api/orders_api.dart';
import 'orders_event.dart';
import 'orders_state.dart';

class OrdersBloc extends Bloc<OrdersEvent, OrdersState> {
  final OrdersApi _api;
  OrdersBloc({OrdersApi? api}) : _api = api ?? OrdersApi.instance, super(const OrdersState()) {
    on<OrdersLoadRequested>(_onLoad);
    on<OrdersTabChanged>((e, emit) => emit(state.copyWith(tab: e.tab)));
    on<OrdersPlaceBuy>(_onBuy);
    on<OrdersPlaceSell>(_onSell);
  }

  Future<void> _onLoad(OrdersLoadRequested e, Emitter<OrdersState> emit) async {
    emit(state.copyWith(status: OrdersStatus.loading));
    try {
      final orders = await _api.fetchOrders();
      final positions = await _api.fetchPositions();
      emit(state.copyWith(
        status: OrdersStatus.ready,
        orders: orders,
        positions: positions,
      ));
    } catch (error) {
      emit(state.copyWith(
        status: OrdersStatus.failure,
        error: error.toString(),
      ));
    }
  }

  Future<void> _onBuy(OrdersPlaceBuy e, Emitter<OrdersState> emit) async {
    try {
      await _api.buyStock(
        symbol: e.symbol,
        company: e.company,
        quantity: e.quantity,
        price: e.price,
      );
      // Reload orders + positions after a successful buy.
      final orders = await _api.fetchOrders();
      final positions = await _api.fetchPositions();
      emit(state.copyWith(
        status: OrdersStatus.ready,
        orders: orders,
        positions: positions,
        successMessage: 'BUY ${e.quantity}× ${e.symbol} executed @ ₹${e.price.toStringAsFixed(2)}',
      ));
    } catch (error) {
      emit(state.copyWith(error: error.toString()));
    }
  }

  Future<void> _onSell(OrdersPlaceSell e, Emitter<OrdersState> emit) async {
    try {
      await _api.sellStock(
        symbol: e.symbol,
        quantity: e.quantity,
        price: e.price,
      );
      final orders = await _api.fetchOrders();
      final positions = await _api.fetchPositions();
      emit(state.copyWith(
        status: OrdersStatus.ready,
        orders: orders,
        positions: positions,
        successMessage: 'SELL ${e.quantity}× ${e.symbol} executed @ ₹${e.price.toStringAsFixed(2)}',
      ));
    } catch (error) {
      emit(state.copyWith(error: error.toString()));
    }
  }
}

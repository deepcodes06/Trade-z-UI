import 'package:equatable/equatable.dart';
import '../../models/order_model.dart';

enum OrdersStatus { initial, loading, ready, failure }

class OrdersState extends Equatable {
  final OrdersStatus status;
  final int tab; // 0 positions, 1 order book, 2 trade book
  final List<OrderModel> orders;
  final List<PositionModel> positions;
  final String? error;
  final String? successMessage;

  const OrdersState({
    this.status = OrdersStatus.initial,
    this.tab = 0,
    this.orders = const [],
    this.positions = const [],
    this.error,
    this.successMessage,
  });

  OrdersState copyWith({
    OrdersStatus? status,
    int? tab,
    List<OrderModel>? orders,
    List<PositionModel>? positions,
    String? error,
    String? successMessage,
  }) =>
      OrdersState(
        status: status ?? this.status,
        tab: tab ?? this.tab,
        orders: orders ?? this.orders,
        positions: positions ?? this.positions,
        error: error,
        successMessage: successMessage,
      );

  @override
  List<Object?> get props => [status, tab, orders, positions, error, successMessage];
}

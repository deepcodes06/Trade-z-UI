import 'package:equatable/equatable.dart';

abstract class OrdersEvent extends Equatable {
  const OrdersEvent();
  @override
  List<Object?> get props => [];
}

class OrdersLoadRequested extends OrdersEvent {
  const OrdersLoadRequested();
}

class OrdersTabChanged extends OrdersEvent {
  final int tab;
  const OrdersTabChanged(this.tab);
  @override
  List<Object?> get props => [tab];
}

class OrdersPlaceBuy extends OrdersEvent {
  final String symbol;
  final String? company;
  final int quantity;
  final double price;
  const OrdersPlaceBuy({
    required this.symbol,
    this.company,
    required this.quantity,
    required this.price,
  });
  @override
  List<Object?> get props => [symbol, company, quantity, price];
}

class OrdersPlaceSell extends OrdersEvent {
  final String symbol;
  final int quantity;
  final double price;
  const OrdersPlaceSell({
    required this.symbol,
    required this.quantity,
    required this.price,
  });
  @override
  List<Object?> get props => [symbol, quantity, price];
}

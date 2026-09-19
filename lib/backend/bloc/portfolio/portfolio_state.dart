import '../../models/portfolio_holding_model.dart';

enum PortfolioStatus { initial, loading, ready, failure }

class PortfolioState {
  final PortfolioStatus status;
  final List<PortfolioHoldingModel> holdings;
  final String? error;

  const PortfolioState({
    this.status = PortfolioStatus.initial,
    this.holdings = const [],
    this.error,
  });

  double get totalInvested => holdings.fold(0, (sum, h) => sum + h.invested);
  double get totalCurrentValue => holdings.fold(0, (sum, h) => sum + h.currentValue);
  double get totalPnl => totalCurrentValue - totalInvested;
  double get totalPnlPct => totalInvested > 0 ? (totalPnl / totalInvested) * 100 : 0;
  double get totalDayPnl => holdings.fold(0, (sum, h) => sum + h.dayPnl);
  bool get totalPnlPositive => totalPnl >= 0;
  bool get totalDayPnlPositive => totalDayPnl >= 0;

  PortfolioState copyWith({
    PortfolioStatus? status,
    List<PortfolioHoldingModel>? holdings,
    String? error,
  }) {
    return PortfolioState(
      status: status ?? this.status,
      holdings: holdings ?? this.holdings,
      error: error,
    );
  }
}

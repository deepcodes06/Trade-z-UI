import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../backend/bloc/orders/orders_bloc.dart';
import '../../backend/bloc/orders/orders_event.dart';
import '../../backend/bloc/orders/orders_state.dart';
import '../../backend/models/order_model.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_responsive.dart';
import '../../constants/app_strings.dart';

class OrdersPage extends StatefulWidget {
  final VoidCallback onSearchTap;
  final VoidCallback onProfileTap;

  const OrdersPage({super.key, required this.onSearchTap, required this.onProfileTap});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrdersBloc>().add(const OrdersLoadRequested());
    });
  }

  @override
  Widget build(BuildContext context) {
    AppResponsive.init(context);
    return BlocConsumer<OrdersBloc, OrdersState>(
      listener: (context, state) {
        if (state.successMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.successMessage!)),
          );
          context.read<OrdersBloc>().add(const OrdersLoadRequested());
        }
        if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.error!), backgroundColor: AppPalette.of(context).loss),
          );
        }
      },
      builder: (context, state) {
        if (state.status == OrdersStatus.loading) {
          return Center(child: CircularProgressIndicator(color: AppPalette.of(context).primary));
        }
        return Column(
          children: [
            _Tabs(state: state),
            SizedBox(height: AppResponsive.h(10)),
            Expanded(
              child: switch (state.tab) {
                0 => _PositionsList(state: state),
                1 => _OrderBook(state: state),
                _ => _TradeBook(state: state),
              },
            ),
          ],
        );
      },
    );
  }
}

class _Tabs extends StatelessWidget {
  final OrdersState state;
  const _Tabs({required this.state});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final tabs = const [AppStrings.positions, AppStrings.orderBook, AppStrings.tradeBook];
    return Container(
      margin: AppResponsive.symH(16).add(EdgeInsets.only(top: AppResponsive.h(8))),
      padding: EdgeInsets.all(AppResponsive.w(4)),
      decoration: GlassCard.of(context, radius: AppResponsive.w(14)),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final selected = state.tab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => context.read<OrdersBloc>().add(OrdersTabChanged(i)),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(vertical: AppResponsive.h(10)),
                decoration: BoxDecoration(
                  color: selected ? p.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppResponsive.w(11)),
                ),
                alignment: Alignment.center,
                child: Text(
                  tabs[i],
                  style: GoogleFonts.inter(
                    color: selected ? p.onPrimary : p.textSecondary,
                    fontSize: AppResponsive.font(13),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _PositionsList extends StatelessWidget {
  final OrdersState state;
  const _PositionsList({required this.state});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    if (state.positions.isEmpty) return _Empty(text: 'No open positions');
    return Container(
      margin: AppResponsive.symH(16),
      decoration: GlassCard.of(context, radius: AppResponsive.w(16)),
      child: Column(
        children: [
          for (var i = 0; i < state.positions.length; i++) ...[
            _PositionRow(pos: state.positions[i]),
            if (i != state.positions.length - 1)
              Divider(height: 1, color: p.divider, indent: AppResponsive.w(16)),
          ],
          Container(
            padding: AppResponsive.symH(16).add(EdgeInsets.symmetric(vertical: AppResponsive.h(12))),
            decoration: BoxDecoration(
              color: p.surfaceAlt.withValues(alpha: 0.5),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total P&L', style: GoogleFonts.inter(color: p.textSecondary, fontSize: AppResponsive.font(13), fontWeight: FontWeight.w600)),
                Builder(builder: (_) {
                  final total = state.positions.fold<double>(0, (a, b) => a + b.pnl);
                  final up = total >= 0;
                  return Text(
                    '${up ? '+' : ''}${total.toStringAsFixed(2)}',
                    style: GoogleFonts.spaceGrotesk(color: up ? p.gain : p.loss, fontSize: AppResponsive.font(16), fontWeight: FontWeight.w700, letterSpacing: -0.2),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PositionRow extends StatelessWidget {
  final PositionModel pos;
  const _PositionRow({required this.pos});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final up = pos.pnl >= 0;
    return Padding(
      padding: AppResponsive.symH(16).add(EdgeInsets.symmetric(vertical: AppResponsive.h(12))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pos.symbol, style: GoogleFonts.inter(color: p.textPrimary, fontSize: AppResponsive.font(14), fontWeight: FontWeight.w700, letterSpacing: -0.1)),
                SizedBox(height: AppResponsive.h(3)),
                Text('Qty ${pos.qty}  •  Avg ${pos.avgPrice.toStringAsFixed(2)}', style: GoogleFonts.inter(color: p.textSecondary, fontSize: AppResponsive.font(11), fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(pos.ltp.toStringAsFixed(2), style: GoogleFonts.spaceGrotesk(color: p.textPrimary, fontSize: AppResponsive.font(14), fontWeight: FontWeight.w700, letterSpacing: -0.1)),
              SizedBox(height: AppResponsive.h(3)),
              Text('${up ? '+' : ''}${pos.pnl.toStringAsFixed(2)}', style: GoogleFonts.inter(color: up ? p.gain : p.loss, fontSize: AppResponsive.font(12), fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrderBook extends StatelessWidget {
  final OrdersState state;
  const _OrderBook({required this.state});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    if (state.orders.isEmpty) return _Empty(text: 'No orders yet');
    return Container(
      margin: AppResponsive.symH(16),
      decoration: GlassCard.of(context, radius: AppResponsive.w(16)),
      child: Column(
        children: [
          for (var i = 0; i < state.orders.length; i++) ...[
            _OrderRow(order: state.orders[i]),
            if (i != state.orders.length - 1)
              Divider(height: 1, color: p.divider, indent: AppResponsive.w(16)),
          ],
        ],
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  final OrderModel order;
  const _OrderRow({required this.order});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final isBuy = order.side == OrderSide.buy;
    final fmt = DateFormat('HH:mm');
    final sideColor = isBuy ? p.gain : p.loss;
    return Padding(
      padding: AppResponsive.symH(16).add(EdgeInsets.symmetric(vertical: AppResponsive.h(12))),
      child: Row(
        children: [
          Container(
            width: AppResponsive.w(34),
            height: AppResponsive.w(28),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: sideColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: sideColor.withValues(alpha: 0.5)),
            ),
            child: Text(
              isBuy ? 'B' : 'S',
              style: GoogleFonts.spaceGrotesk(color: sideColor, fontSize: AppResponsive.font(12), fontWeight: FontWeight.w800),
            ),
          ),
          SizedBox(width: AppResponsive.w(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.symbol, style: GoogleFonts.inter(color: p.textPrimary, fontSize: AppResponsive.font(14), fontWeight: FontWeight.w700, letterSpacing: -0.1)),
                SizedBox(height: AppResponsive.h(3)),
                Text('${order.type.name.toUpperCase()} • Qty ${order.qty} • ${fmt.format(order.time)}', style: GoogleFonts.inter(color: p.textSecondary, fontSize: AppResponsive.font(11), fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(order.price.toStringAsFixed(2), style: GoogleFonts.spaceGrotesk(color: p.textPrimary, fontSize: AppResponsive.font(14), fontWeight: FontWeight.w700, letterSpacing: -0.1)),
              SizedBox(height: AppResponsive.h(3)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor(p, order.status).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  order.status.name.toUpperCase(),
                  style: GoogleFonts.inter(color: _statusColor(p, order.status), fontSize: AppResponsive.font(10), fontWeight: FontWeight.w700, letterSpacing: 0.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _statusColor(AppPalette p, OrderStatus s) {
    switch (s) {
      case OrderStatus.executed: return p.gain;
      case OrderStatus.pending: return p.warning;
      case OrderStatus.rejected: return p.loss;
      case OrderStatus.cancelled: return p.textMuted;
    }
  }
}

class _TradeBook extends StatelessWidget {
  final OrdersState state;
  const _TradeBook({required this.state});

  @override
  Widget build(BuildContext context) {
    final trades = state.orders.where((o) => o.status == OrderStatus.executed).toList();
    if (trades.isEmpty) return _Empty(text: 'No executed trades');
    return _OrderBook(state: state.copyWith(orders: trades));
  }
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty({required this.text});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: AppResponsive.w(88),
            height: AppResponsive.w(88),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(color: p.primary.withValues(alpha: 0.2)),
            ),
            child: Icon(Icons.inbox_outlined, size: AppResponsive.w(40), color: p.primary.withValues(alpha: 0.4)),
          ),
          SizedBox(height: AppResponsive.h(12)),
          Text(text, style: GoogleFonts.inter(color: p.textSecondary, fontSize: AppResponsive.font(13), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

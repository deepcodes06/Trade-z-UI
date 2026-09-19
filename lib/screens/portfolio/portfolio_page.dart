import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../backend/bloc/portfolio/portfolio_bloc.dart';
import '../../backend/bloc/portfolio/portfolio_event.dart';
import '../../backend/bloc/portfolio/portfolio_state.dart';
import '../../backend/models/portfolio_holding_model.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_responsive.dart';
import '../../constants/app_strings.dart';
import '../../utils/market_hours.dart';
import '../stock_detail/stock_detail_page.dart';

class PortfolioPage extends StatefulWidget {
  final VoidCallback? onSearchTap;
  final VoidCallback? onProfileTap;
  const PortfolioPage({super.key, this.onSearchTap, this.onProfileTap});

  @override
  State<PortfolioPage> createState() => _PortfolioPageState();
}

class _PortfolioPageState extends State<PortfolioPage> {
  Timer? _poller;

  @override
  void initState() {
    super.initState();
    context.read<PortfolioBloc>().add(const PortfolioLoadRequested());
    _poller = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        // Market settled — stop live market-price refreshes.
        if (!MarketHours.isOpen()) return;
        context.read<PortfolioBloc>().add(const PortfolioRefreshRequested());
      },
    );
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return BlocBuilder<PortfolioBloc, PortfolioState>(
      builder: (context, state) {
        if (state.status == PortfolioStatus.loading) {
          return Center(
            child: CircularProgressIndicator(color: p.primary),
          );
        }
        if (state.status == PortfolioStatus.failure && state.holdings.isEmpty) {
          return _EmptyState(
            icon: Icons.error_outline,
            message: state.error ?? 'Failed to load portfolio',
            onRetry: () => context.read<PortfolioBloc>().add(const PortfolioLoadRequested()),
          );
        }
        if (state.holdings.isEmpty) {
          return const _EmptyState(
            icon: Icons.account_balance_wallet_outlined,
            message: 'No holdings yet',
          );
        }
        return RefreshIndicator(
          color: p.primary,
          backgroundColor: p.surface,
          onRefresh: () async {
            context.read<PortfolioBloc>().add(const PortfolioRefreshRequested());
            await Future<void>.delayed(const Duration(milliseconds: 600));
          },
          child: ListView(
            padding: EdgeInsets.only(
              top: AppResponsive.h(16),
              bottom: AppResponsive.h(100),
            ),
            children: [
              _PortfolioSummaryHeader(state: state),
              SizedBox(height: AppResponsive.h(20)),
              _HoldingsList(holdings: state.holdings),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Summary header
// ---------------------------------------------------------------------------

class _PortfolioSummaryHeader extends StatelessWidget {
  final PortfolioState state;
  const _PortfolioSummaryHeader({required this.state});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final pnlColor = state.totalPnlPositive ? p.gain : p.loss;
    final dayPnlColor = state.totalDayPnlPositive ? p.gain : p.loss;

    return GlassCard.blur(
      radius: AppResponsive.w(20),
      margin: AppResponsive.symH(16),
      padding: AppResponsive.symH(20).copyWith(
        top: AppResponsive.h(20),
        bottom: AppResponsive.h(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Invested',
            style: GoogleFonts.inter(
              color: p.textMuted,
              fontSize: AppResponsive.font(12),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: AppResponsive.h(4)),
          Text(
            '₹${_fmt(state.totalInvested)}',
            style: GoogleFonts.inter(
              color: p.textPrimary,
              fontSize: AppResponsive.font(16),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: AppResponsive.h(16)),
          Row(
            children: [
              _SummaryPill(
                label: 'Current Value',
                value: '₹${_fmt(state.totalCurrentValue)}',
                color: p.textPrimary,
                p: p,
              ),
              SizedBox(width: AppResponsive.w(10)),
              _SummaryPill(
                label: 'Overall P&L',
                value: '${state.totalPnl >= 0 ? '+' : ''}₹${_fmt(state.totalPnl)}',
                sub: '${state.totalPnlPct >= 0 ? '+' : ''}${state.totalPnlPct.toStringAsFixed(2)}%',
                color: pnlColor,
                p: p,
              ),
            ],
          ),
          SizedBox(height: AppResponsive.h(10)),
          Row(
            children: [
              _SummaryPill(
                label: 'Day P&L',
                value: '${state.totalDayPnl >= 0 ? '+' : ''}₹${_fmt(state.totalDayPnl)}',
                color: dayPnlColor,
                p: p,
              ),
              SizedBox(width: AppResponsive.w(10)),
              _SummaryPill(
                label: 'Holdings',
                value: '${state.holdings.length}',
                color: p.textPrimary,
                p: p,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _fmt(double v) => v.abs().toStringAsFixed(2);
}

class _SummaryPill extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final Color color;
  final AppPalette p;

  const _SummaryPill({
    required this.label,
    required this.value,
    this.sub,
    required this.color,
    required this.p,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppResponsive.w(14),
          vertical: AppResponsive.h(10),
        ),
        decoration: BoxDecoration(
          color: p.softHighlight,
          borderRadius: BorderRadius.circular(AppResponsive.w(12)),
          border: Border.all(color: p.border, width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                color: p.textMuted,
                fontSize: AppResponsive.font(11),
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: AppResponsive.h(4)),
            Text(
              value,
              style: GoogleFonts.inter(
                color: color,
                fontSize: AppResponsive.font(15),
                fontWeight: FontWeight.w700,
              ),
            ),
            if (sub != null) ...[
              SizedBox(height: AppResponsive.h(2)),
              Text(
                sub!,
                style: GoogleFonts.inter(
                  color: color,
                  fontSize: AppResponsive.font(11),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Holdings list
// ---------------------------------------------------------------------------

class _HoldingsList extends StatelessWidget {
  final List<PortfolioHoldingModel> holdings;
  const _HoldingsList({required this.holdings});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      margin: AppResponsive.symH(16),
      decoration: GlassCard.of(context, radius: AppResponsive.w(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppResponsive.w(16),
              AppResponsive.h(14),
              AppResponsive.w(16),
              AppResponsive.h(10),
            ),
            child: Text(
              'Your Holdings',
              style: GoogleFonts.inter(
                color: p.textPrimary,
                fontSize: AppResponsive.font(14),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Divider(color: p.border, height: 1),
          ...holdings.map((h) => _HoldingTile(holding: h)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual holding tile
// ---------------------------------------------------------------------------

class _HoldingTile extends StatelessWidget {
  final PortfolioHoldingModel holding;
  const _HoldingTile({required this.holding});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final dayPnlColor = holding.dayPnlPositive ? p.gain : p.loss;
    final overallColor = holding.overallPnlPositive ? p.gain : p.loss;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StockDetailPage(
              symbol: holding.symbol,
              name: holding.company,
              seedLtp: holding.currentLtp,
              seedChange: holding.dayChange,
              seedPercentChange: holding.dayChangePct,
            ),
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppResponsive.w(16),
          vertical: AppResponsive.h(12),
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: p.border, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            // Symbol circle
            Container(
              width: AppResponsive.w(42),
              height: AppResponsive.w(42),
              decoration: BoxDecoration(
                color: p.softHighlight,
                borderRadius: BorderRadius.circular(AppResponsive.w(12)),
                border: Border.all(color: p.primary.withValues(alpha: 0.20), width: 1),
              ),
              alignment: Alignment.center,
              child: Text(
                holding.symbol.characters.take(2).string.toUpperCase(),
                style: GoogleFonts.inter(
                  color: p.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: AppResponsive.font(13),
                ),
              ),
            ),
            SizedBox(width: AppResponsive.w(12)),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    holding.symbol,
                    style: GoogleFonts.inter(
                      color: p.textPrimary,
                      fontSize: AppResponsive.font(14),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: AppResponsive.h(2)),
                  Text(
                    '${holding.quantity} qty · avg ₹${holding.avgPrice.toStringAsFixed(2)}',
                    style: GoogleFonts.inter(
                      color: p.textMuted,
                      fontSize: AppResponsive.font(11),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // Current price + day P&L
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${holding.currentLtp.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(
                    color: p.textPrimary,
                    fontSize: AppResponsive.font(14),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: AppResponsive.h(2)),
                Text(
                  'Day ${holding.dayPnl >= 0 ? '+' : ''}₹${holding.dayPnl.abs().toStringAsFixed(2)}',
                  style: GoogleFonts.inter(
                    color: dayPnlColor,
                    fontSize: AppResponsive.font(11),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            SizedBox(width: AppResponsive.w(12)),
            // Overall P&L pill
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppResponsive.w(10),
                vertical: AppResponsive.h(5),
              ),
              decoration: BoxDecoration(
                color: overallColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppResponsive.w(8)),
              ),
              child: Text(
                '${holding.overallPnl >= 0 ? '+' : ''}₹${holding.overallPnl.abs().toStringAsFixed(2)}',
                style: GoogleFonts.inter(
                  color: overallColor,
                  fontSize: AppResponsive.font(11),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final VoidCallback? onRetry;

  const _EmptyState({
    required this.icon,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Center(
      child: Padding(
        padding: AppResponsive.symH(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: AppResponsive.w(72),
              height: AppResponsive.w(72),
              decoration: BoxDecoration(
                color: p.softHighlight,
                borderRadius: BorderRadius.circular(AppResponsive.w(24)),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: p.primary, size: AppResponsive.w(34)),
            ),
            SizedBox(height: AppResponsive.h(16)),
            Text(
              message,
              style: GoogleFonts.inter(
                color: p.textMuted,
                fontSize: AppResponsive.font(14),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              SizedBox(height: AppResponsive.h(16)),
              GestureDetector(
                onTap: onRetry,
                child: Text(
                  AppStrings.retry,
                  style: GoogleFonts.inter(
                    color: p.primary,
                    fontSize: AppResponsive.font(14),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

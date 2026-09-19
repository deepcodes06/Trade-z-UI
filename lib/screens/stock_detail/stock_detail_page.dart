import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../backend/api/market_api.dart';
import '../../backend/api/orders_api.dart';
import '../../backend/bloc/watchlist/watchlist_bloc.dart';
import '../../backend/bloc/watchlist/watchlist_event.dart';
import '../../backend/models/candle_model.dart';
import '../../backend/models/market_depth.dart';
import '../../backend/models/order_model.dart';
import '../../backend/models/stock_detail_model.dart';
import '../../backend/repositories/market_repository.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_responsive.dart';
import '../../utils/market_hours.dart';
import '../../widgets/neon_backdrop.dart';

/// Full detail screen for a single stock, modeled after typical broker apps:
/// header with LTP/change, Overview/Fundamentals/Technicals/News tabs,
/// exchange selector, range-selectable chart, market depth, day/52-week
/// stats, holdings (if the user has a position), quick actions, and a
/// Buy/Sell action bar.
///
/// Two honesty notes baked into the UI itself:
/// - Market depth (bid/ask ladder) and Market Cap / Upper-Lower circuit /
///   ATP are Level-2 / reference-data fields Twelve Data's quote endpoint
///   doesn't provide, so they render as placeholders ("-" / "—") rather
///   than fabricated numbers.
/// - Buy/Sell/Set Alert only capture input and show a confirmation; there's
///   no broker order-execution backend wired up in this project.
class StockDetailPage extends StatefulWidget {
  final String symbol;
  final String name;
  final String? exchange;

  /// Optional values already known from the list the user tapped from,
  /// so we can render something instantly while the fresh quote loads.
  final double? seedLtp;
  final double? seedChange;
  final double? seedPercentChange;

  const StockDetailPage({
    super.key,
    required this.symbol,
    required this.name,
    this.exchange,
    this.seedLtp,
    this.seedChange,
    this.seedPercentChange,
  });

  @override
  State<StockDetailPage> createState() => _StockDetailPageState();
}

class _StockDetailPageState extends State<StockDetailPage> {
  final _repo = MarketRepository();

  StockDetailModel? _detail;
  List<CandleModel> _candles = const [];
  ChartRange _range = ChartRange.d1;
  String _exchange = 'NSE';
  int _tabIndex = 0;

  bool _loading = true;
  bool _chartLoading = false;
  String? _error;
  Timer? _poller;

  PositionModel? _holding;

  @override
  void initState() {
    super.initState();
    _exchange = widget.exchange ?? 'NSE';
    _loadQuote();
    _loadHolding();
    // Auto-refresh the quote (not the chart) every 10s while this screen is open.
    // 30s, not 10s — see the matching comment in HomeBloc for why.
    _poller = Timer.periodic(const Duration(seconds: 30), (_) {
      // Outside NSE hours prices are settled — stop live polling.
      if (!MarketHours.isOpen()) return;
      _loadQuote(silent: true);
    });
    _subscribeToLiveTicks();
  }

  @override
  void dispose() {
    _poller?.cancel();
    _liveSub?.cancel();
    super.dispose();
  }

  /// Subscribes to `/api/market/stream` and applies the per-tick price
  /// updates to the current detail so the price header, change line, day
  /// stats, depth and 52-week indicators all move in real time between
  /// the 30-second `_loadQuote` polls. Silent no-op when the symbol isn't
  /// present in the latest tick payload.
  StreamSubscription<String>? _liveSub;
  void _subscribeToLiveTicks() {
    try {
      _liveSub = MarketApi.instance.subscribeToStream(
        onTick: (payload) {
          if (!mounted) return;
          final updates = payload['updates'];
          if (updates is! List) return;
          for (final raw in updates) {
            if (raw is! Map) continue;
            final m = raw.cast<String, dynamic>();
            if ((m['symbol'] ?? '').toString().toUpperCase() != widget.symbol.toUpperCase()) {
              continue;
            }
            final newPrice = _d(m['currentPrice']);
            if (newPrice <= 0) return;
            final d = _detail;
            if (d == null) return;
            setState(() {
              // Update the fields that change every tick in-place without
              // a full re-fetch. Day high/low and depth are recomputed by
              // the simulator's next snapshot, so we just patch ltp here.
              _detail = StockDetailModel(
                symbol: d.symbol,
                name: d.name,
                exchange: d.exchange,
                sector: d.sector,
                industry: d.industry,
                ltp: newPrice,
                change: newPrice - d.previousClose,
                percentChange: d.previousClose == 0 ? 0 : ((newPrice - d.previousClose) / d.previousClose) * 100,
                open: d.open,
                dayHigh: newPrice > d.dayHigh ? newPrice : d.dayHigh,
                dayLow: newPrice < d.dayLow || d.dayLow == 0 ? newPrice : d.dayLow,
                previousClose: d.previousClose,
                volume: d.volume,
                avgVolume: d.avgVolume,
                bid: d.bid,
                ask: d.ask,
                weekHigh52: newPrice > d.weekHigh52 ? newPrice : d.weekHigh52,
                weekLow52: newPrice < d.weekLow52 || d.weekLow52 == 0 ? newPrice : d.weekLow52,
                weekHigh52Date: d.weekHigh52Date,
                weekLow52Date: d.weekLow52Date,
                marketCap: d.marketCap,
                peRatio: d.peRatio,
                eps: d.eps,
                bookValue: d.bookValue,
                dividendYield: d.dividendYield,
                beta: d.beta,
                faceValue: d.faceValue,
                lotSize: d.lotSize,
                upperCircuit: d.upperCircuit,
                lowerCircuit: d.lowerCircuit,
                circuitPct: d.circuitPct,
                atp: d.atp,
                depth: d.depth,
                candles: d.candles,
              );
            });
            return;
          }
        },
      );
    } catch (e) {
      // SSE failures are non-fatal — the 30s poll keeps things moving.
    }
  }

  double _d(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  Future<void> _loadQuote({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final d = await _repo.fetchStockDetail(
        symbol: widget.symbol,
        name: widget.name,
        exchange: _exchange,
        seedLtp: widget.seedLtp,
        range: _range,
      );
      if (!mounted) return;
      setState(() {
        _detail = d;
        _candles = d.candles;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not refresh: $e';
      });
    }
  }

  Future<void> _loadHolding() async {
    try {
      final positions = await OrdersApi.instance.fetchPositions();
      if (!mounted) return;
      setState(() {
        _holding = positions.cast<PositionModel?>().firstWhere(
              (p) => p?.symbol == widget.symbol,
              orElse: () => null,
            );
      });
    } catch (_) {
      // Holdings are a nice-to-have on this screen; ignore failures quietly.
    }
  }

  Future<void> _onRangeSelected(ChartRange range) async {
    if (range == _range) return;
    setState(() {
      _range = range;
      _chartLoading = true;
    });
    final candles = await _repo.fetchCandlesForRange(
      symbol: widget.symbol,
      range: range,
    );
    if (!mounted) return;
    setState(() {
      _candles = candles;
      _chartLoading = false;
    });
  }

  Future<void> _onExchangeChanged(String exchange) async {
    if (exchange == _exchange) return;
    setState(() => _exchange = exchange);
    await _loadQuote();
  }

  @override
  Widget build(BuildContext context) {
    AppResponsive.init(context);
    final p = AppPalette.of(context);
    final d = _detail;
    final up = (d?.change ?? widget.seedChange ?? 0) >= 0;
    final color = up ? p.gain : p.loss;

    return Scaffold(
      backgroundColor: p.background,
      appBar: _buildHeader(p, d, color, up),
      body: Stack(
        children: [
          const Positioned.fill(child: NeonBackdrop()),
          _loading && d == null
              ? Center(child: CircularProgressIndicator(color: p.primary))
              : Column(
                  children: [
                    _TabBarRow(
                      index: _tabIndex,
                      onChanged: (i) => setState(() => _tabIndex = i),
                    ),
                    Expanded(
                      child: switch (_tabIndex) {
                        0 => _buildOverview(p, d, color, up),
                        1 => _FundamentalsTab(detail: d),
                        _ => _ComingSoonTab(
                            label: const ['', 'Fundamentals', 'Technicals', 'News'][_tabIndex],
                          ),
                      },
                    ),
                  ],
                ),
        ],
      ),
      bottomNavigationBar: _BuySellBar(
        onBuy: d == null ? null : () => _openOrderSheet(context, side: 'BUY', ltp: d.ltp, color: p.gain),
        onSell: d == null ? null : () => _openOrderSheet(context, side: 'SELL', ltp: d.ltp, color: p.loss),
      ),
    );
  }

  PreferredSizeWidget _buildHeader(AppPalette p, StockDetailModel? d, Color color, bool up) {
    return AppBar(
      backgroundColor: p.topBar,
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      toolbarHeight: AppResponsive.h(64),
      title: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppResponsive.w(4)),
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back, color: p.icon),
              onPressed: () => Navigator.pop(context),
            ),
            Container(
              width: AppResponsive.w(34),
              height: AppResponsive.w(34),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppResponsive.w(8)),
                border: Border.all(color: p.loss.withValues(alpha: 0.6)),
              ),
              child: Text(
                widget.symbol.substring(0, widget.symbol.length.clamp(0, 1)),
                style: TextStyle(color: p.loss, fontWeight: FontWeight.w800),
              ),
            ),
            SizedBox(width: AppResponsive.w(8)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.symbol,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.spaceGrotesk(
                      color: p.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: AppResponsive.font(15),
                    ),
                  ),
                  Text(
                    widget.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: p.textMuted,
                      fontSize: AppResponsive.font(11),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  (d?.ltp ?? widget.seedLtp ?? 0).toStringAsFixed(2),
                  style: GoogleFonts.spaceGrotesk(
                    color: p.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: AppResponsive.font(15),
                  ),
                ),
                Text(
                  '${up ? '+' : ''}${(d?.change ?? widget.seedChange ?? 0).toStringAsFixed(2)} '
                  '(${up ? '+' : ''}${(d?.percentChange ?? widget.seedPercentChange ?? 0).toStringAsFixed(2)}%)',
                  style: TextStyle(
                    color: color,
                    fontSize: AppResponsive.font(11),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            SizedBox(width: AppResponsive.w(6)),
          ],
        ),
      ),
    );
  }

  Widget _buildOverview(AppPalette p, StockDetailModel? d, Color color, bool up) {
    return RefreshIndicator(
      color: p.primary,
      backgroundColor: p.card,
      onRefresh: () => _loadQuote(),
      child: ListView(
        padding: AppResponsive.padAll(16),
        children: [
          if (_error != null)
            Padding(
              padding: EdgeInsets.only(bottom: AppResponsive.h(8)),
              child: Text(_error!, style: TextStyle(color: p.loss, fontSize: AppResponsive.font(12))),
            ),

          _ExchangeSelector(value: _exchange, onChanged: _onExchangeChanged),
          SizedBox(height: AppResponsive.h(12)),

          // Chart card
          Container(
            padding: AppResponsive.padAll(12),
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: BorderRadius.circular(AppResponsive.w(16)),
              border: Border.all(color: p.border),
            ),
            child: Column(
              children: [
                SizedBox(
                  height: AppResponsive.h(190),
                  child: _candles.isEmpty
                      ? Center(
                          child: _chartLoading
                              ? CircularProgressIndicator(color: p.primary)
                              : Text('No chart data', style: TextStyle(color: p.textMuted)),
                        )
                      : Stack(
                          children: [
                            CustomPaint(
                              size: Size.infinite,
                              painter: _LineChartPainter(
                                candles: _candles,
                                lineColor: p.primary,
                                gridColor: p.divider,
                              ),
                            ),
                            if (_chartLoading)
                              Positioned.fill(
                                child: Container(
                                  color: p.card.withValues(alpha: 0.5),
                                  child: Center(
                                    child: CircularProgressIndicator(color: p.primary),
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
                SizedBox(height: AppResponsive.h(10)),
                Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: ChartRange.values
                              .map((r) => Padding(
                                    padding: EdgeInsets.only(right: AppResponsive.w(6)),
                                    child: _RangeChip(
                                      label: r.label,
                                      selected: r == _range,
                                      onTap: () => _onRangeSelected(r),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.candlestick_chart_outlined, color: p.icon, size: AppResponsive.w(18)),
                      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Candlestick / depth chart view coming soon.')),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.fullscreen, color: p.icon, size: AppResponsive.w(20)),
                      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Fullscreen chart view coming soon.')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(height: AppResponsive.h(16)),
          _MarketDepthCard(detail: d),

          SizedBox(height: AppResponsive.h(16)),
          _StatsCard(detail: d),

          SizedBox(height: AppResponsive.h(16)),
          _FiftyTwoWeekSlider(detail: d),

          if (_holding != null) ...[
            SizedBox(height: AppResponsive.h(16)),
            _HoldingsCard(holding: _holding!, ltp: d?.ltp),
          ],

          SizedBox(height: AppResponsive.h(16)),
          _QuickActionsRow(symbol: widget.symbol),

          SizedBox(height: AppResponsive.h(90)), // room for bottom bar
        ],
      ),
    );
  }

  void _openOrderSheet(BuildContext context,
      {required String side, required double ltp, required Color color}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPalette.of(context).surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _BuySellSheet(symbol: widget.symbol, side: side, ltp: ltp, accent: color),
    );
  }
}

/// Overview / Fundamentals / Technicals / News tab row.
class _TabBarRow extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  const _TabBarRow({required this.index, required this.onChanged});

  static const _labels = ['Overview', 'Fundamentals', 'Technicals', 'News'];

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: p.topBar,
        border: Border(bottom: BorderSide(color: p.border)),
      ),
      child: Row(
        children: List.generate(_labels.length, (i) {
          final selected = i == index;
          return Expanded(
            child: InkWell(
              onTap: () => onChanged(i),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: AppResponsive.h(12)),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected ? p.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  _labels[i],
                  style: GoogleFonts.inter(
                    color: selected ? p.primary : p.textSecondary,
                    fontSize: AppResponsive.font(13),
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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

class _ComingSoonTab extends StatelessWidget {
  final String label;
  const _ComingSoonTab({required this.label});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Center(
      child: Padding(
        padding: AppResponsive.padAll(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hourglass_empty, color: p.textMuted, size: AppResponsive.w(32)),
            SizedBox(height: AppResponsive.h(10)),
            Text(
              '$label coming soon',
              style: GoogleFonts.inter(color: p.textSecondary, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExchangeSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _ExchangeSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return PopupMenuButton<String>(
      color: p.surface,
      onSelected: onChanged,
      itemBuilder: (_) => const ['NSE', 'BSE']
          .map((e) => PopupMenuItem<String>(value: e, child: Text(e)))
          .toList(),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: AppResponsive.w(12), vertical: AppResponsive.h(6)),
        decoration: BoxDecoration(
          color: p.primary,
          borderRadius: BorderRadius.circular(AppResponsive.w(8)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value,
                style: TextStyle(color: p.onPrimary, fontWeight: FontWeight.w700, fontSize: AppResponsive.font(13))),
            Icon(Icons.arrow_drop_down, color: p.onPrimary),
          ],
        ),
      ),
    );
  }
}

class _RangeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _RangeChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: AppResponsive.w(10), vertical: AppResponsive.h(5)),
        decoration: BoxDecoration(
          color: selected ? p.primary.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? p.primary : p.textSecondary,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            fontSize: AppResponsive.font(12),
          ),
        ),
      ),
    );
  }
}

/// Market depth (5-level bid/ask ladder). The simulator populates this on
/// every tick with realistic qty + order counts at each price level, so we
/// render the live order book instead of placeholder dashes.
class _MarketDepthCard extends StatelessWidget {
  final StockDetailModel? detail;
  const _MarketDepthCard({required this.detail});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final d = detail;
    final depth = d?.depth;
    final bids = depth?.bids ?? const [];
    final asks = depth?.asks ?? const [];
    final rows = <(DepthLevel?, DepthLevel?)>[
      for (var i = 0; i < 5; i++)
        (
          i < bids.length ? bids[i] : null,
          i < asks.length ? asks[i] : null,
        ),
    ];
    final maxSideQty = [
      ...bids.map((b) => b.quantity),
      ...asks.map((a) => a.quantity),
      1,
    ].reduce((a, b) => a > b ? a : b);
    final totalBuy = depth?.totalBuyQty ?? 0;
    final totalSell = depth?.totalSellQty ?? 0;
    final total = totalBuy + totalSell;
    final buyFrac = total == 0 ? 0.5 : totalBuy / total;

    return Container(
      padding: AppResponsive.padAll(14),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(AppResponsive.w(16)),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _depthHeaderCell('Volume', p),
              _depthHeaderCell('Orders', p),
              _depthHeaderCell('Bid', p),
              _depthHeaderCell('Ask', p),
              _depthHeaderCell('Orders', p),
              _depthHeaderCell('Volume', p),
            ],
          ),
          SizedBox(height: AppResponsive.h(6)),
          for (final r in rows) _depthRow(p, r.$1, r.$2, maxSideQty),
          SizedBox(height: AppResponsive.h(8)),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Row(
              children: [
                Expanded(
                  flex: (buyFrac * 1000).round().clamp(1, 1000),
                  child: Container(height: AppResponsive.h(6), color: p.gain),
                ),
                Expanded(
                  flex: ((1 - buyFrac) * 1000).round().clamp(1, 1000),
                  child: Container(height: AppResponsive.h(6), color: p.loss),
                ),
              ],
            ),
          ),
          SizedBox(height: AppResponsive.h(4)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fmtQty(totalBuy),
                  style: TextStyle(color: p.gain, fontWeight: FontWeight.w700, fontSize: AppResponsive.font(12))),
              Text(_fmtQty(totalSell),
                  style: TextStyle(color: p.loss, fontWeight: FontWeight.w700, fontSize: AppResponsive.font(12))),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Buy Quantity',
                  style: GoogleFonts.inter(color: p.textMuted, fontSize: AppResponsive.font(11))),
              Text('Total Sell Quantity',
                  style: GoogleFonts.inter(color: p.textMuted, fontSize: AppResponsive.font(11))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _depthHeaderCell(String label, AppPalette p) => Expanded(
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: p.textMuted, fontSize: AppResponsive.font(11), fontWeight: FontWeight.w600),
        ),
      );

  Widget _depthRow(AppPalette p, DepthLevel? bid, DepthLevel? ask, int maxQty) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppResponsive.h(3)),
      child: Row(
        children: [
          _depthCell(bid == null ? '-' : _fmtQty(bid.quantity), p.textMuted, bar: bid, side: true, max: maxQty, p: p),
          _depthCell(bid == null ? '-' : '${bid.orders}', p.textMuted),
          _depthCell(bid == null ? '-—' : bid.price.toStringAsFixed(2), p.gain),
          _depthCell(ask == null ? '-—' : ask.price.toStringAsFixed(2), p.loss),
          _depthCell(ask == null ? '-' : '${ask.orders}', p.textMuted),
          _depthCell(ask == null ? '-' : _fmtQty(ask.quantity), p.textMuted, bar: ask, side: false, max: maxQty, p: p),
        ],
      ),
    );
  }

  /// Render a depth cell with a faint background bar behind it sized to its
  /// share of total qty at that side — the same visual brokers use.
  Widget _depthCell(
    String text,
    Color color, {
    DepthLevel? bar,
    bool side = true,
    int max = 1,
    AppPalette? p,
  }) {
    final frac = (bar == null || max == 0) ? 0.0 : (bar.quantity / max).clamp(0.0, 1.0);
    return Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppResponsive.w(1)),
        child: Stack(
          alignment: side ? Alignment.centerRight : Alignment.centerLeft,
          children: [
            if (bar != null)
              FractionallySizedBox(
                widthFactor: frac,
                alignment: side ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  height: AppResponsive.h(18),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: color, fontSize: AppResponsive.font(12), fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtQty(int q) {
    if (q >= 100000) return '${(q / 100000).toStringAsFixed(1)}L';
    if (q >= 1000) return '${(q / 1000).toStringAsFixed(1)}K';
    return '$q';
  }
}

/// Day / reference stats. The simulator populates every field the realtime
/// quote carries — Market Cap, Upper/Lower Circuit and ATP included — so
/// the cards on this screen never show "—" unless the simulator hasn't
/// published those values yet (which is a visible "data not loaded" state
/// rather than a fabricated figure).
class _StatsCard extends StatelessWidget {
  final StockDetailModel? detail;
  const _StatsCard({required this.detail});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final d = detail;
    final rows = <(String, String)>[
      ('Open', _num(d?.open)),
      ('High', _num(d?.dayHigh)),
      ('Low', _num(d?.dayLow)),
      ('Prev. close', _num(d?.previousClose)),
      ('Volume', _vol(d?.volume)),
      ('Market Cap', _mcap(d?.marketCap)),
      ('Upper Circuit', _circuit(d?.upperCircuit, d?.circuitPct)),
      ('Lower Circuit', _circuit(d?.lowerCircuit, d?.circuitPct)),
      ('ATP', _num(d?.atp)),
    ];
    return Container(
      padding: AppResponsive.padAll(14),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(AppResponsive.w(16)),
        border: Border.all(color: p.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(rows[i].$1,
                    style: GoogleFonts.inter(color: p.textSecondary, fontSize: AppResponsive.font(13))),
                Text(rows[i].$2,
                    style: GoogleFonts.inter(
                        color: p.textPrimary, fontSize: AppResponsive.font(13), fontWeight: FontWeight.w700)),
              ],
            ),
            if (i != rows.length - 1)
              Padding(
                padding: EdgeInsets.symmetric(vertical: AppResponsive.h(8)),
                child: Divider(height: 1, color: p.divider),
              ),
          ],
        ],
      ),
    );
  }

  String _num(double? v) => (v == null || v == 0) ? '—' : v.toStringAsFixed(2);

  String _vol(double? v) {
    if (v == null || v == 0) return '—';
    final i = v.toInt();
    if (i >= 10000000) return '${(i / 10000000).toStringAsFixed(2)} Cr';
    if (i >= 100000) return '${(i / 100000).toStringAsFixed(2)} L';
    if (i >= 1000) return '${(i / 1000).toStringAsFixed(2)} K';
    return '$i';
  }

  String _mcap(double? v) {
    if (v == null || v == 0) return '—';
    // Rupee → Crore (1 Cr = 1e7) → Lakh (1 L = 1e5).
    if (v >= 1e12) return '₹${(v / 1e7).toStringAsFixed(0)} Cr';
    if (v >= 1e9) return '₹${(v / 1e7).toStringAsFixed(1)} Cr';
    if (v >= 1e7) return '₹${(v / 1e7).toStringAsFixed(2)} Cr';
    if (v >= 1e5) return '₹${(v / 1e5).toStringAsFixed(1)} L';
    return '₹${v.toStringAsFixed(0)}';
  }

  String _circuit(double? price, double? pct) {
    if (price == null || price == 0) return '—';
    final pctStr = (pct == null || pct == 0) ? '' : ' (${(pct * 100).toStringAsFixed(0)}%)';
    return '${price.toStringAsFixed(2)}$pctStr';
  }
}

/// Fundamentals tab — populated by the simulator's broker-data fields
/// (P/E, EPS, book value, dividend yield, beta, face value, lot size, sector,
/// industry). All values are real; the "—" fallback only shows when the
/// simulator hasn't published a value yet.
class _FundamentalsTab extends StatelessWidget {
  final StockDetailModel? detail;
  const _FundamentalsTab({required this.detail});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final d = detail;

    final valuation = <(String, String)>[
      ('Market Cap', _mcap(d?.marketCap)),
      ('P/E Ratio', _num(d?.peRatio)),
      ('EPS', _num(d?.eps)),
      ('Book Value', _num(d?.bookValue)),
      ('Dividend Yield', _pct(d?.dividendYield)),
      ('Beta', _num(d?.beta)),
    ];
    final share = <(String, String)>[
      ('Face Value', d?.faceValue == null || d!.faceValue == 0 ? '—' : '₹${d.faceValue.toStringAsFixed(0)}'),
      ('Lot Size', d?.lotSize == null || d!.lotSize == 0 ? '—' : '${d.lotSize}'),
      ('Avg. Volume', _vol(d?.avgVolume)),
      ('Sector', (d?.sector ?? '').isEmpty ? '—' : d!.sector),
      ('Industry', (d?.industry ?? '').isEmpty ? '—' : d!.industry),
      ('Exchange', (d?.exchange ?? '').isEmpty ? '—' : d!.exchange),
    ];

    return ListView(
      padding: AppResponsive.padAll(16),
      children: [
        _section('Valuation', valuation, p),
        SizedBox(height: AppResponsive.h(16)),
        _section('Share Info', share, p),
        SizedBox(height: AppResponsive.h(90)), // bottom bar clearance
      ],
    );
  }

  Widget _section(String title, List<(String, String)> rows, AppPalette p) {
    return Container(
      padding: AppResponsive.padAll(14),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(AppResponsive.w(16)),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.spaceGrotesk(
              color: p.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: AppResponsive.font(14),
            ),
          ),
          SizedBox(height: AppResponsive.h(10)),
          for (var i = 0; i < rows.length; i++) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(rows[i].$1,
                    style: GoogleFonts.inter(color: p.textSecondary, fontSize: AppResponsive.font(13))),
                Text(rows[i].$2,
                    style: GoogleFonts.inter(
                        color: p.textPrimary, fontSize: AppResponsive.font(13), fontWeight: FontWeight.w700)),
              ],
            ),
            if (i != rows.length - 1)
              Padding(
                padding: EdgeInsets.symmetric(vertical: AppResponsive.h(8)),
                child: Divider(height: 1, color: p.divider),
              ),
          ],
        ],
      ),
    );
  }

  String _num(double? v) => (v == null || v == 0) ? '—' : v.toStringAsFixed(2);

  String _vol(double? v) {
    if (v == null || v == 0) return '—';
    final i = v.toInt();
    if (i >= 10000000) return '${(i / 10000000).toStringAsFixed(2)} Cr';
    if (i >= 100000) return '${(i / 100000).toStringAsFixed(2)} L';
    if (i >= 1000) return '${(i / 1000).toStringAsFixed(2)} K';
    return '$i';
  }

  String _mcap(double? v) {
    if (v == null || v == 0) return '—';
    if (v >= 1e12) return '₹${(v / 1e7).toStringAsFixed(0)} Cr';
    if (v >= 1e9) return '₹${(v / 1e7).toStringAsFixed(1)} Cr';
    if (v >= 1e7) return '₹${(v / 1e7).toStringAsFixed(2)} Cr';
    if (v >= 1e5) return '₹${(v / 1e5).toStringAsFixed(1)} L';
    return '₹${v.toStringAsFixed(0)}';
  }

  String _pct(double? v) => (v == null || v == 0) ? '—' : '${v.toStringAsFixed(2)}%';
}

class _FiftyTwoWeekSlider extends StatelessWidget {
  final StockDetailModel? detail;
  const _FiftyTwoWeekSlider({required this.detail});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final d = detail;
    final low = d?.weekLow52 ?? 0;
    final high = d?.weekHigh52 ?? 0;
    final ltp = d?.ltp ?? 0;
    final frac = (high - low).abs() < 1e-9 ? 0.5 : ((ltp - low) / (high - low)).clamp(0.0, 1.0);

    return Container(
      padding: AppResponsive.padAll(14),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(AppResponsive.w(16)),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final trackW = constraints.maxWidth;
              return SizedBox(
                height: AppResponsive.h(22),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: AppResponsive.h(8),
                      left: 0,
                      right: 0,
                      child: Container(
                        height: AppResponsive.h(6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          gradient: LinearGradient(colors: [p.loss, p.textMuted, p.gain]),
                        ),
                      ),
                    ),
                    Positioned(
                      left: (trackW * frac - AppResponsive.w(7)).clamp(0.0, trackW - AppResponsive.w(14)),
                      top: 0,
                      child: Icon(Icons.arrow_drop_down, color: p.primary, size: AppResponsive.w(22)),
                    ),
                  ],
                ),
              );
            },
          ),
          SizedBox(height: AppResponsive.h(6)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(d == null ? '—' : low.toStringAsFixed(2),
                  style: TextStyle(color: p.textPrimary, fontWeight: FontWeight.w700, fontSize: AppResponsive.font(13))),
              Text(d == null ? '—' : high.toStringAsFixed(2),
                  style: TextStyle(color: p.textPrimary, fontWeight: FontWeight.w700, fontSize: AppResponsive.font(13))),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('52 Week Low', style: GoogleFonts.inter(color: p.textMuted, fontSize: AppResponsive.font(11))),
              Text('52 Week High', style: GoogleFonts.inter(color: p.textMuted, fontSize: AppResponsive.font(11))),
            ],
          ),
        ],
      ),
    );
  }
}

/// Only rendered when the (demo) positions API returns a matching holding
/// for this symbol — real values, not fabricated, computed from qty/avg
/// price plus the live-ish LTP already on screen.
class _HoldingsCard extends StatelessWidget {
  final PositionModel holding;
  final double? ltp;
  const _HoldingsCard({required this.holding, required this.ltp});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final currentLtp = ltp ?? holding.ltp;
    final invested = holding.avgPrice * holding.qty;
    final currentValue = currentLtp * holding.qty;
    final totalPnl = currentValue - invested;
    final totalPnlPct = invested == 0 ? 0.0 : (totalPnl / invested) * 100;
    final dayPnl = holding.pnl;

    return Container(
      padding: AppResponsive.padAll(14),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(AppResponsive.w(16)),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your Holdings',
              style: GoogleFonts.spaceGrotesk(
                  color: p.textPrimary, fontSize: AppResponsive.font(15), fontWeight: FontWeight.w700)),
          SizedBox(height: AppResponsive.h(12)),
          Row(
            children: [
              Expanded(child: _holdingStat('Total Invested', invested.toStringAsFixed(2), p.textPrimary, p)),
              Expanded(child: _holdingStat('Current Value', currentValue.toStringAsFixed(2), p.textPrimary, p)),
              Expanded(
                child: _holdingStat(
                  'Total P&L',
                  '${totalPnl >= 0 ? '+' : ''}${totalPnl.toStringAsFixed(2)} (${totalPnlPct.toStringAsFixed(2)}%)',
                  totalPnl >= 0 ? p.gain : p.loss,
                  p,
                ),
              ),
            ],
          ),
          SizedBox(height: AppResponsive.h(14)),
          Row(
            children: [
              Expanded(child: _holdingStat('Quantity', '${holding.qty}', p.textPrimary, p)),
              Expanded(child: _holdingStat('Avg. Price', holding.avgPrice.toStringAsFixed(2), p.textPrimary, p)),
              Expanded(
                child: _holdingStat(
                  '1 Day P&L',
                  '${dayPnl >= 0 ? '+' : ''}${dayPnl.toStringAsFixed(2)}',
                  dayPnl >= 0 ? p.gain : p.loss,
                  p,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _holdingStat(String label, String value, Color valueColor, AppPalette p) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(color: p.textMuted, fontSize: AppResponsive.font(11))),
          SizedBox(height: AppResponsive.h(2)),
          Text(value,
              style: GoogleFonts.inter(color: valueColor, fontSize: AppResponsive.font(13), fontWeight: FontWeight.w700)),
        ],
      );
}

class _QuickActionsRow extends StatelessWidget {
  final String symbol;
  const _QuickActionsRow({required this.symbol});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickAction(
            icon: Icons.notifications_active_outlined,
            label: 'Set Alert',
            onTap: () => _showSetAlert(context),
          ),
        ),
        SizedBox(width: AppResponsive.w(10)),
        Expanded(
          child: _QuickAction(
            icon: Icons.bookmark_add_outlined,
            label: 'Watchlist',
            onTap: () => _addToWatchlist(context),
          ),
        ),
        SizedBox(width: AppResponsive.w(10)),
        Expanded(
          child: _QuickAction(
            icon: Icons.shopping_basket_outlined,
            label: 'Basket',
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Basket orders aren\'t available yet.')),
            ),
          ),
        ),
      ],
    );
  }

  void _showSetAlert(BuildContext context) {
    final p = AppPalette.of(context);
    final ctrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.surface,
        title: const Text('Set price alert'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(color: p.textPrimary),
          decoration: const InputDecoration(hintText: 'Target price'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              final target = double.tryParse(ctrl.text);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    target == null
                        ? 'Enter a valid price to set an alert.'
                        : 'Alert set for $symbol @ ₹${target.toStringAsFixed(2)} (demo — not persisted).',
                  ),
                ),
              );
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }

  void _addToWatchlist(BuildContext context) {
    final state = context.read<WatchlistBloc>().state;
    if (state.activeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create a watchlist first from the Watchlist tab.')),
      );
      return;
    }
    context.read<WatchlistBloc>().add(
          WatchlistAddStockRequested(watchlistId: state.activeId!, symbol: symbol),
        );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$symbol added to your watchlist.')),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppResponsive.w(12)),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: AppResponsive.h(10)),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(AppResponsive.w(12)),
          border: Border.all(color: p.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: p.primary, size: AppResponsive.w(20)),
            SizedBox(height: AppResponsive.h(4)),
            Text(label,
                style: GoogleFonts.inter(
                    color: p.textSecondary, fontSize: AppResponsive.font(11), fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _BuySellBar extends StatelessWidget {
  final VoidCallback? onBuy;
  final VoidCallback? onSell;
  const _BuySellBar({required this.onBuy, required this.onSell});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppResponsive.w(16), vertical: AppResponsive.h(10)),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: p.gain,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: AppResponsive.h(14)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppResponsive.w(10))),
                ),
                onPressed: onBuy,
                child: const Text('Buy', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
            SizedBox(width: AppResponsive.w(10)),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: p.loss,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: AppResponsive.h(14)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppResponsive.w(10))),
                ),
                onPressed: onSell,
                child: const Text('Sell', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
            SizedBox(width: AppResponsive.w(10)),
            Container(
              decoration: BoxDecoration(
                color: p.primary,
                borderRadius: BorderRadius.circular(AppResponsive.w(10)),
              ),
              child: IconButton(
                icon: const Icon(Icons.settings, color: Colors.white),
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Order settings (product type, validity) coming soon.')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple, dependency-free line chart drawn with CustomPainter.
class _LineChartPainter extends CustomPainter {
  final List<CandleModel> candles;
  final Color lineColor;
  final Color gridColor;

  _LineChartPainter({required this.candles, required this.lineColor, required this.gridColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;
    final closes = candles.map((c) => c.close).toList();
    final maxV = closes.reduce((a, b) => a > b ? a : b);
    final minV = closes.reduce((a, b) => a < b ? a : b);
    final range = (maxV - minV).abs() < 1e-9 ? 1.0 : (maxV - minV);

    const leftPad = 4.0;
    const rightPad = 4.0;
    const topPad = 8.0;
    const bottomPad = 8.0;
    final chartW = size.width - leftPad - rightPad;
    final chartH = size.height - topPad - bottomPad;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = topPad + chartH * (i / 3);
      canvas.drawLine(Offset(leftPad, y), Offset(size.width - rightPad, y), gridPaint);
    }

    final path = Path();
    final points = <Offset>[];
    for (var i = 0; i < closes.length; i++) {
      final x = leftPad + chartW * (closes.length == 1 ? 0 : i / (closes.length - 1));
      final norm = (closes[i] - minV) / range;
      final y = topPad + chartH * (1 - norm);
      points.add(Offset(x, y));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, topPad + chartH)
      ..lineTo(points.first.dx, topPad + chartH)
      ..close();
    canvas.drawPath(fillPath, Paint()..color = lineColor.withValues(alpha: 0.12));

    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawCircle(points.last, 3.5, Paint()..color = lineColor);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.candles != candles || oldDelegate.lineColor != lineColor;
}

/// Bottom sheet to capture a simple buy/sell intent.
///
/// This does NOT place a real order — there is no broker execution backend
/// wired into this project. It just validates input and shows a confirmation
/// so the UI flow is complete; wire the submit callback up to your order API
/// (e.g. via a new OrdersEvent) when that integration is ready.
class _BuySellSheet extends StatefulWidget {
  final String symbol;
  final String side;
  final double ltp;
  final Color accent;

  const _BuySellSheet({required this.symbol, required this.side, required this.ltp, required this.accent});

  @override
  State<_BuySellSheet> createState() => _BuySellSheetState();
}

class _BuySellSheetState extends State<_BuySellSheet> {
  int _qty = 1;
  bool _market = true;
  final _priceCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _priceCtrl.text = widget.ltp.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final price = _market ? widget.ltp : (double.tryParse(_priceCtrl.text) ?? widget.ltp);
    final total = price * _qty;

    return Padding(
      padding: EdgeInsets.only(
        left: AppResponsive.w(20),
        right: AppResponsive.w(20),
        top: AppResponsive.h(16),
        bottom: MediaQuery.of(context).viewInsets.bottom + AppResponsive.h(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: AppResponsive.w(10), vertical: AppResponsive.h(4)),
                decoration: BoxDecoration(
                  color: widget.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(widget.side, style: TextStyle(color: widget.accent, fontWeight: FontWeight.w800)),
              ),
              SizedBox(width: AppResponsive.w(10)),
              Text(widget.symbol,
                  style: GoogleFonts.spaceGrotesk(
                      color: p.textPrimary, fontSize: AppResponsive.font(18), fontWeight: FontWeight.w700)),
            ],
          ),
          SizedBox(height: AppResponsive.h(18)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Quantity', style: GoogleFonts.inter(color: p.textSecondary, fontWeight: FontWeight.w600)),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.remove_circle_outline, color: p.icon),
                    onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                  ),
                  Text('$_qty',
                      style: GoogleFonts.spaceGrotesk(color: p.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                  IconButton(
                    icon: Icon(Icons.add_circle_outline, color: p.icon),
                    onPressed: () => setState(() => _qty++),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: AppResponsive.h(8)),
          Row(
            children: [
              _ToggleChip(label: 'Market', selected: _market, onTap: () => setState(() => _market = true)),
              SizedBox(width: AppResponsive.w(8)),
              _ToggleChip(label: 'Limit', selected: !_market, onTap: () => setState(() => _market = false)),
            ],
          ),
          if (!_market) ...[
            SizedBox(height: AppResponsive.h(10)),
            TextField(
              controller: _priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: p.textPrimary),
              decoration: InputDecoration(
                labelText: 'Limit price',
                labelStyle: TextStyle(color: p.textSecondary),
                enabledBorder:
                    OutlineInputBorder(borderSide: BorderSide(color: p.border), borderRadius: BorderRadius.circular(10)),
                focusedBorder:
                    OutlineInputBorder(borderSide: BorderSide(color: p.primary), borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
          SizedBox(height: AppResponsive.h(16)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Est. total', style: GoogleFonts.inter(color: p.textSecondary, fontWeight: FontWeight.w600)),
              Text('₹${total.toStringAsFixed(2)}',
                  style: GoogleFonts.spaceGrotesk(color: p.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
            ],
          ),
          SizedBox(height: AppResponsive.h(18)),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.accent,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: AppResponsive.h(14)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppResponsive.w(12))),
              ),
              onPressed: () async {
                Navigator.pop(context);
                try {
                  final api = OrdersApi.instance;
                  if (widget.side == 'BUY') {
                    await api.buyStock(
                      symbol: widget.symbol,
                      quantity: _qty,
                      price: price,
                    );
                  } else {
                    await api.sellStock(
                      symbol: widget.symbol,
                      quantity: _qty,
                      price: price,
                    );
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${widget.side} order for $_qty × ${widget.symbol} @ ₹${price.toStringAsFixed(2)} placed successfully.',
                        ),
                        backgroundColor: widget.accent,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Order failed: $e'),
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                    );
                  }
                }
              },
              child: Text('Confirm ${widget.side}', style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ToggleChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: AppResponsive.w(14), vertical: AppResponsive.h(7)),
        decoration: BoxDecoration(
          color: selected ? p.primary : p.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? p.primary : p.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? p.onPrimary : p.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: AppResponsive.font(13),
          ),
        ),
      ),
    );
  }
}

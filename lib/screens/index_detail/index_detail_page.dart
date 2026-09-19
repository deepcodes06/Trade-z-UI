import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../backend/models/candle_model.dart';
import '../../backend/models/index_model.dart';
import '../../backend/repositories/market_repository.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_responsive.dart';
import '../../utils/market_hours.dart';

/// Detail page for one of the four indices tapped from the home screen grid.
///
/// Shows the live level + change, a candle-based line chart with the same
/// range chips as the stock detail page, and OHLC / 52-week stats. Data comes
/// from `GET /api/market/indices/:symbol` and
/// `GET /api/market/index-history/:symbol` (the server computes the levels
/// from the underlying stock basket), so nothing is fabricated client-side.
class IndexDetailPage extends StatefulWidget {
  final IndexModel seed;

  const IndexDetailPage({super.key, required this.seed});

  @override
  State<IndexDetailPage> createState() => _IndexDetailPageState();
}

class _IndexDetailPageState extends State<IndexDetailPage> {
  final MarketRepository _repo = MarketRepository();
  ChartRange _range = ChartRange.d1;
  IndexModel? _index;
  List<CandleModel> _candles = const [];
  bool _loading = true;
  bool _chartLoading = true;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _index = widget.seed;
    _refresh();
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) return;
      if (!MarketHours.isOpen()) return;
      _refresh(quiet: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh({bool quiet = false}) async {
    if (!quiet && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final detail = await _repo.fetchIndexDetail(widget.seed.symbol);
      if (!mounted) return;
      setState(() {
        _index = detail;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (!quiet) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
    await _loadRange();
  }

  Future<void> _loadRange() async {
    if (!mounted) return;
    setState(() => _chartLoading = true);
    final candles = await _repo.fetchIndexCandles(
      symbol: widget.seed.symbol,
      range: _range,
    );
    if (!mounted) return;
    setState(() {
      _candles = candles;
      _chartLoading = false;
    });
  }

  void _onRangeSelected(ChartRange range) {
    if (range == _range) return;
    setState(() => _range = range);
    _loadRange();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final index = _index ?? widget.seed;
    final up = index.change >= 0;
    final accent = up ? p.gain : p.loss;

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: p.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          index.name,
          style: GoogleFonts.spaceGrotesk(
            color: p.textPrimary,
            fontSize: AppResponsive.font(18),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: p.primary,
        backgroundColor: p.surface,
        onRefresh: () => _refresh(),
        child: ListView(
          padding: EdgeInsets.only(bottom: AppResponsive.h(24)),
          children: [
            // Header card: symbol + live level + change
            Container(
              margin: AppResponsive.symH(16),
              padding: AppResponsive.padAll(16),
              decoration: GlassCard.of(context, radius: AppResponsive.w(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    index.symbol,
                    style: GoogleFonts.inter(
                      color: p.textSecondary,
                      fontSize: AppResponsive.font(13),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: AppResponsive.h(6)),
                  if (_loading && _index == widget.seed)
                    CircularProgressIndicator(color: p.primary, strokeWidth: 2.5)
                  else
                    Text(
                      index.last.toStringAsFixed(2),
                      style: GoogleFonts.spaceGrotesk(
                        color: p.textPrimary,
                        fontSize: AppResponsive.font(38),
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                  SizedBox(height: AppResponsive.h(4)),
                  Text(
                    '${up ? '+' : ''}${index.change.toStringAsFixed(2)}  (${up ? '+' : ''}${index.percentChange.toStringAsFixed(2)}%)',
                    style: GoogleFonts.inter(
                      color: accent,
                      fontSize: AppResponsive.font(16),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

            if (_error != null)
              Container(
                margin: AppResponsive.symH(16).add(
                  EdgeInsets.only(top: AppResponsive.h(12)),
                ),
                padding: AppResponsive.padAll(12),
                decoration: BoxDecoration(
                  color: p.loss.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppResponsive.w(12)),
                  border: Border.all(color: p.loss.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.cloud_off, size: AppResponsive.w(18), color: p.loss),
                    SizedBox(width: AppResponsive.w(8)),
                    Expanded(
                      child: Text(
                        'Showing last known data — ${_error!}',
                        style: GoogleFonts.inter(
                          color: p.loss,
                          fontSize: AppResponsive.font(12),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Chart card
            Container(
              margin: AppResponsive.symH(16).add(
                EdgeInsets.only(top: AppResponsive.h(12)),
              ),
              padding: AppResponsive.padAll(12),
              decoration: GlassCard.of(context, radius: AppResponsive.w(16)),
              child: Column(
                children: [
                  SizedBox(
                    height: AppResponsive.h(190),
                    child: _candles.isEmpty
                        ? Center(
                            child: _chartLoading
                                ? CircularProgressIndicator(color: p.primary)
                                : Text('No chart data',
                                    style: TextStyle(color: p.textMuted)),
                          )
                        : Stack(
                            children: [
                              CustomPaint(
                                size: Size.infinite,
                                painter: IndexLineChartPainter(
                                  candles: _candles,
                                  lineColor: accent,
                                  gridColor: p.divider,
                                ),
                              ),
                              if (_chartLoading)
                                Positioned.fill(
                                  child: Container(
                                    color: p.surface.withValues(alpha: 0.5),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                          color: p.primary),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                  ),
                  SizedBox(height: AppResponsive.h(10)),
                  SingleChildScrollView(
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
                ],
              ),
            ),

            // OHLC stats card
            Container(
              margin: AppResponsive.symH(16).add(
                EdgeInsets.only(top: AppResponsive.h(12)),
              ),
              padding: AppResponsive.symH(16).add(
                EdgeInsets.symmetric(vertical: AppResponsive.h(14)),
              ),
              decoration: GlassCard.of(context, radius: AppResponsive.w(16)),
              child: Column(
                children: [
                  Row(
                    children: [
                      _StatBox(label: 'Open', value: index.open),
                      SizedBox(width: AppResponsive.w(10)),
                      _StatBox(label: 'Day High', value: index.dayHigh),
                    ],
                  ),
                  SizedBox(height: AppResponsive.h(10)),
                  Row(
                    children: [
                      _StatBox(label: 'Day Low', value: index.dayLow),
                      SizedBox(width: AppResponsive.w(10)),
                      _StatBox(label: 'Prev Close', value: index.previousClose),
                    ],
                  ),
                ],
              ),
            ),

            // 52-week range
            if (index.weekHigh52 > 0 && index.weekLow52 > 0) ...[
              Container(
                margin: AppResponsive.symH(16).add(
                  EdgeInsets.only(top: AppResponsive.h(12)),
                ),
                padding: AppResponsive.symH(16).add(
                  EdgeInsets.symmetric(vertical: AppResponsive.h(14)),
                ),
                decoration: GlassCard.of(context, radius: AppResponsive.w(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '52 Week Range',
                      style: GoogleFonts.inter(
                        color: p.textSecondary,
                        fontSize: AppResponsive.font(13),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: AppResponsive.h(12)),
                    _WeekRangeBar(
                      low: index.weekLow52,
                      high: index.weekHigh52,
                      current: index.last,
                      color: accent,
                    ),
                    SizedBox(height: AppResponsive.h(8)),
                    Row(
                      children: [
                        Text(
                          index.weekLow52.toStringAsFixed(2),
                          style: GoogleFonts.inter(
                            color: p.textMuted,
                            fontSize: AppResponsive.font(12),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          index.weekHigh52.toStringAsFixed(2),
                          style: GoogleFonts.inter(
                            color: p.textMuted,
                            fontSize: AppResponsive.font(12),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final double value;
  const _StatBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Expanded(
      child: Container(
        padding: AppResponsive.symH(12).add(
          EdgeInsets.symmetric(vertical: AppResponsive.h(12)),
        ),
        decoration: BoxDecoration(
          color: p.surfaceAlt,
          borderRadius: BorderRadius.circular(AppResponsive.w(12)),
          border: Border.all(color: p.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                color: p.textSecondary,
                fontSize: AppResponsive.font(12),
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: AppResponsive.h(4)),
            Text(
              value <= 0 ? '—' : value.toStringAsFixed(2),
              style: GoogleFonts.inter(
                color: p.textPrimary,
                fontSize: AppResponsive.font(15),
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekRangeBar extends StatelessWidget {
  final double low;
  final double high;
  final double current;
  final Color color;
  const _WeekRangeBar({
    required this.low,
    required this.high,
    required this.current,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final span = (high - low).abs() < 1e-9 ? 1.0 : high - low;
    final ratio = ((current - low) / span).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          height: AppResponsive.h(18),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: AppResponsive.h(4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: LinearGradient(
                    colors: [p.loss, p.warning, p.gain],
                  ),
                ),
              ),
              Positioned(
                left: (constraints.maxWidth * ratio) - AppResponsive.w(8),
                top: 0,
                child: Container(
                  width: AppResponsive.w(18),
                  height: AppResponsive.w(18),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: p.surface, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RangeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _RangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppResponsive.w(8)),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppResponsive.w(12),
          vertical: AppResponsive.h(6),
        ),
        decoration: BoxDecoration(
          color: selected ? p.primary : p.surfaceAlt,
          borderRadius: BorderRadius.circular(AppResponsive.w(8)),
          border: Border.all(
            color: selected ? p.primary : p.border,
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: selected ? p.onPrimary : p.textSecondary,
            fontSize: AppResponsive.font(12),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Lightweight line chart used on the index detail page. Mirrors the stock
/// detail chart: closes wired top-to-bottom, gradient fill under the line.
class IndexLineChartPainter extends CustomPainter {
  final List<CandleModel> candles;
  final Color lineColor;
  final Color gridColor;

  IndexLineChartPainter({
    required this.candles,
    required this.lineColor,
    required this.gridColor,
  });

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
  bool shouldRepaint(covariant IndexLineChartPainter oldDelegate) =>
      oldDelegate.candles != candles || oldDelegate.lineColor != lineColor;
}
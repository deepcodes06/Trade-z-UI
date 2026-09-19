import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_responsive.dart';

class StockChangeText extends StatelessWidget {
  final double change;
  final double percentChange;
  final double fontSize;

  const StockChangeText({
    super.key,
    required this.change,
    required this.percentChange,
    this.fontSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final up = change >= 0;
    final color = up ? p.gain : p.loss;
    final sign = up ? '+' : '';
    return Text(
      '$sign${change.toStringAsFixed(2)} ($sign${percentChange.toStringAsFixed(2)}%)',
      style: TextStyle(
        color: color,
        fontSize: AppResponsive.font(fontSize),
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
      ),
    );
  }
}

class IndexTile extends StatelessWidget {
  final String name;
  final double last;
  final double change;
  final double percentChange;
  final VoidCallback? onTap;

  const IndexTile({
    super.key,
    required this.name,
    required this.last,
    required this.change,
    required this.percentChange,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final up = change >= 0;
    final color = up ? p.gain : p.loss;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppResponsive.w(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppResponsive.w(14)),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppResponsive.w(10),
            vertical: AppResponsive.h(6),
          ),
          decoration: GlassCard.of(context, radius: AppResponsive.w(14)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: p.textSecondary,
                  fontSize: AppResponsive.font(11),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  last.toStringAsFixed(2),
                  style: TextStyle(
                    color: p.textPrimary,
                    fontSize: AppResponsive.font(15),
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              Row(
                children: [
                  Icon(
                    up ? Icons.trending_up : Icons.trending_down,
                    color: color,
                    size: AppResponsive.w(13),
                  ),
                  SizedBox(width: AppResponsive.w(2)),
                  Flexible(
                    child: Text(
                      '${up ? '+' : ''}${percentChange.toStringAsFixed(2)}%',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontSize: AppResponsive.font(11),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StockTile extends StatelessWidget {
  final String symbol;
  final String name;
  final double ltp;
  final double change;
  final double percentChange;
  final bool isBlowUpSignal;
  final VoidCallback? onTap;

  const StockTile({
    super.key,
    required this.symbol,
    required this.name,
    required this.ltp,
    required this.change,
    required this.percentChange,
    this.isBlowUpSignal = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return ListTile(
      onTap: onTap,
      contentPadding: AppResponsive.symH(16),
      leading: Container(
        width: AppResponsive.w(42),
        height: AppResponsive.w(42),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: p.softHighlight,
          borderRadius: BorderRadius.circular(AppResponsive.w(12)),
          border: Border.all(color: p.primary.withValues(alpha: 0.20)),
        ),
        child: Text(
          symbol.substring(0, symbol.length.clamp(0, 2)),
          style: TextStyle(
            color: p.accent,
            fontSize: AppResponsive.font(12),
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              symbol,
              style: TextStyle(
                color: p.textPrimary,
                fontSize: AppResponsive.font(15),
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
          ),
          if (isBlowUpSignal)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: p.warning.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: p.warning),
              ),
              child: Text(
                'BLOW-UP',
                style: TextStyle(
                  color: p.warning,
                  fontSize: AppResponsive.font(10),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ),
        ],
      ),
      subtitle: Padding(
        padding: EdgeInsets.only(top: AppResponsive.h(2)),
        child: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: p.textSecondary,
            fontSize: AppResponsive.font(12),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            ltp.toStringAsFixed(2),
            style: TextStyle(
              color: p.textPrimary,
              fontSize: AppResponsive.font(14),
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          SizedBox(height: AppResponsive.h(2)),
          StockChangeText(
            change: change,
            percentChange: percentChange,
            fontSize: 12,
          ),
        ],
      ),
    );
  }
}

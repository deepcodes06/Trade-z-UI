import 'package:equatable/equatable.dart';
import 'candle_model.dart';
import 'market_depth.dart';

/// Full detail payload for a single stock, served by `/api/market/quote/:symbol`.
///
/// Fields mirror what the realtime simulator (and stock.indianapi.in via the
/// IndianProvider) return. The Flutter detail page consumes:
///   - quote fields: ltp, change, percentChange, open, dayHigh, dayLow,
///     previousClose, weekHigh52, weekLow52, volume
///   - broker fields: marketCap, upperCircuit, lowerCircuit, atp, bid, ask,
///     peRatio, eps, bookValue, dividendYield, beta, faceValue, lotSize,
///     sector, industry, exchange
///   - depth: 5-level bid/ask ladder rendered in `_MarketDepthCard`
///   - candles: chart series for the active range
class StockDetailModel extends Equatable {
  // Identity.
  final String symbol;
  final String name;
  final String exchange;
  final String sector;
  final String industry;

  // Quote / session.
  final double ltp;
  final double change;
  final double percentChange;
  final double open;
  final double dayHigh;
  final double dayLow;
  final double previousClose;
  final double volume;
  final double avgVolume;
  final double bid;
  final double ask;

  // 52-week.
  final double weekHigh52;
  final double weekLow52;
  final String? weekHigh52Date;
  final String? weekLow52Date;

  // Broker fundamentals.
  final double marketCap;
  final double peRatio;
  final double eps;
  final double bookValue;
  final double dividendYield;
  final double beta;
  final double faceValue;
  final int lotSize;

  // Circuit limits + ATP.
  final double upperCircuit;
  final double lowerCircuit;
  final double circuitPct;
  final double atp;

  // Order book (Level-2 depth).
  final MarketDepth depth;

  // Chart.
  final List<CandleModel> candles;

  const StockDetailModel({
    required this.symbol,
    required this.name,
    required this.exchange,
    required this.sector,
    required this.industry,
    required this.ltp,
    required this.change,
    required this.percentChange,
    required this.open,
    required this.dayHigh,
    required this.dayLow,
    required this.previousClose,
    required this.volume,
    required this.avgVolume,
    required this.bid,
    required this.ask,
    required this.weekHigh52,
    required this.weekLow52,
    required this.weekHigh52Date,
    required this.weekLow52Date,
    required this.marketCap,
    required this.peRatio,
    required this.eps,
    required this.bookValue,
    required this.dividendYield,
    required this.beta,
    required this.faceValue,
    required this.lotSize,
    required this.upperCircuit,
    required this.lowerCircuit,
    required this.circuitPct,
    required this.atp,
    required this.depth,
    required this.candles,
  });

  bool get isUp => change >= 0;
  bool get hasDepth => !depth.isEmpty;
  bool get hasFundamentals => marketCap > 0 || peRatio > 0 || eps > 0;

  @override
  List<Object?> get props => [
        symbol,
        name,
        exchange,
        sector,
        industry,
        ltp,
        change,
        percentChange,
        open,
        dayHigh,
        dayLow,
        previousClose,
        volume,
        avgVolume,
        bid,
        ask,
        weekHigh52,
        weekLow52,
        weekHigh52Date,
        weekLow52Date,
        marketCap,
        peRatio,
        eps,
        bookValue,
        dividendYield,
        beta,
        faceValue,
        lotSize,
        upperCircuit,
        lowerCircuit,
        circuitPct,
        atp,
        depth,
        candles,
      ];
}
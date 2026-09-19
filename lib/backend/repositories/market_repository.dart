import 'dart:async';
import 'dart:developer' as dev;

import '../api/market_api.dart';
import '../models/candle_model.dart';
import '../models/index_model.dart';
import '../models/market_depth.dart';
import '../models/stock_detail_model.dart';
import '../models/stock_listing_model.dart';
import '../models/stock_model.dart';

/// Chart range options shown on the stock detail page.
///
/// We map each of our existing UI labels to the corresponding `period` and
/// `filter` query params the backend's `/api/market/history/:name` endpoint
/// accepts (see server/src/provider/indian.provider.js — supports
/// `1m`, `6m`, `1yr`, `3yr`, `5yr`, `10yr`, `max`).
enum ChartRange { d1, w1, m1, m6, y1, y5, max }

extension ChartRangeX on ChartRange {
  String get label => switch (this) {
        ChartRange.d1 => '1D',
        ChartRange.w1 => '1W',
        ChartRange.m1 => '1M',
        ChartRange.m6 => '6M',
        ChartRange.y1 => '1Y',
        ChartRange.y5 => '5Y',
        ChartRange.max => 'Max',
      };

  /// (period, filter) the backend's /history endpoint accepts.
  (String period, String filter) get query => switch (this) {
        ChartRange.d1 => ('1m', 'default'),
        ChartRange.w1 => ('1m', 'default'),
        ChartRange.m1 => ('1m', 'default'),
        ChartRange.m6 => ('6m', 'default'),
        ChartRange.y1 => ('1yr', 'default'),
        ChartRange.y5 => ('5yr', 'default'),
        ChartRange.max => ('max', 'default'),
      };
}

/// Shared, app-wide quote cache. The backend already rate-limits us (300/15m,
/// see server/src/app.js), so this cache mainly exists to keep multiple
/// screens from re-fetching the same symbol in the same second. It never
/// invents data: on a failure it serves the last known *real* quote (if
/// we have one) rather than a synthetic number.
class _QuoteCache {
  _QuoteCache._();
  static final Map<String, QuoteResult> lastKnown = {};
  static final Map<String, DateTime> lastAt = {};

  static void store(Iterable<QuoteResult> quotes) {
    final now = DateTime.now();
    for (final q in quotes) {
      if (q.symbol.isEmpty) continue;
      lastKnown[q.symbol] = q;
      lastAt[q.symbol] = now;
    }
  }
}

class MarketRepository {
  final MarketApi _api;
  MarketRepository({MarketApi? api}) : _api = api ?? MarketApi.instance;

  void _log(String msg) => dev.log(msg, name: 'MarketRepository');

  /// True once we've successfully talked to the backend at least once. The
  /// home/watchlist UI uses this to flip its "LIVE" indicator.
  bool _everSucceeded = false;
  bool get isLive => _everSucceeded;

  /// Whether the NSE market is currently open, straight from the dashboard's
  /// `marketStatus` payload. Defaults to open so the UI never accidentally
  /// freezes just because the server doesn't report a status yet.
  bool _marketOpen = true;
  bool get isMarketOpen => _marketOpen;

  static Map<String, dynamic>? _dashboardCache;
  static DateTime? _dashboardFetchedAt;
  static Future<Map<String, dynamic>>? _dashboardFetchTask;
  static const Duration _dashboardTtl = Duration(seconds: 60);

  Future<Map<String, dynamic>> _getDashboard({bool forceRefresh = false}) async {
    final now = DateTime.now();
    final cached = _dashboardCache;
    final fetchedAt = _dashboardFetchedAt;
    final cacheValid = !forceRefresh && cached != null && fetchedAt != null && now.difference(fetchedAt) < _dashboardTtl;

    if (cacheValid) {
      _log('getDashboard: cache hit');
      return cached;
    }

    if (_dashboardFetchTask != null) {
      _log('getDashboard: waiting for in-flight fetch');
      return await _dashboardFetchTask!;
    }

    _dashboardFetchTask = _api.getDashboard();
    try {
      final result = await _dashboardFetchTask!;
      _dashboardCache = result;
      _dashboardFetchedAt = DateTime.now();
      _log('getDashboard: fetched and cached');
      return result;
    } catch (e) {
      if (_dashboardCache != null) {
        _log('getDashboard failed: $e, returning stale cache');
        return _dashboardCache!;
      }
      rethrow;
    } finally {
      _dashboardFetchTask = null;
    }
  }

  // -- Indices / top stocks (home screen) ---------------------------------

  /// Fetches the dashboard (which contains trending + NSE/BSE most active
  /// + price shockers). We use `trending` for the "indices" grid and
  /// `nseMostActive` for the "Top Nifty 50" list. Returns empty lists on
  /// failure so the UI can render a "no data" state instead of fabricated
  /// numbers.
  Future<({List<IndexModel> indices, List<StockModel> topStocks})>
      fetchHomeData({bool forceRefresh = false}) async {
    try {
      final dashboard = await _getDashboard(forceRefresh: forceRefresh);
      _everSucceeded = true;
      final status = dashboard['marketStatus'];
      if (status is Map) {
        final isOpen = status['isOpen'];
        if (isOpen is bool) _marketOpen = isOpen;
      }
      final indicesRaw = (dashboard['indices'] as List?) ?? const [];
      final nse = (dashboard['nseMostActive'] as List?) ?? const [];
      final indices = indicesRaw
          .whereType<Map>()
          .map((m) => _indexFromMap(m.cast<String, dynamic>()))
          .where((i) => i.last > 0)
          .toList();
      final topStocks = nse
          .whereType<Map>()
          .map((m) => _stockFromMap(m.cast<String, dynamic>()))
          .where((s) => s.ltp > 0)
          .toList();
      _QuoteCache.store([
        ...indices.map((i) => QuoteResult(
              symbol: i.symbol,
              name: i.name,
              price: i.last,
              change: i.change,
              percentChange: i.percentChange,
              volume: 0,
            )),
        ...topStocks.map((s) => QuoteResult(
              symbol: s.symbol,
              name: s.name,
              price: s.ltp,
              change: s.change,
              percentChange: s.percentChange,
              volume: 0,
            )),
      ]);
      _log('fetchHomeData: ${indices.length} indices, ${topStocks.length} stocks');
      return (indices: indices, topStocks: topStocks);
    } catch (e, st) {
      _log('fetchHomeData failed: $e');
      dev.log('fetchHomeData error', name: 'MarketRepository', error: e, stackTrace: st);
      return (indices: <IndexModel>[], topStocks: <StockModel>[]);
    }
  }

  /// Kept for backwards compat with the home/watchlist blocs which previously
  /// called `fetchIndices` separately. Returns the trending list as "indices".
  Future<List<IndexModel>> fetchIndices({bool forceRefresh = false}) async {
    final r = await fetchHomeData(forceRefresh: forceRefresh);
    return r.indices;
  }

  /// Fetches a single index's live quote via `GET /api/market/indices/:symbol`.
  /// The backend computes open/high/low/prev-close/52-week from the underlying
  /// stock basket, so this gives the detail page everything it needs to render
  /// the OHLC stats. Throws like fetchStockDetail when there's no data.
  Future<IndexModel> fetchIndexDetail(String symbol) async {
    try {
      final raw = await _api.getIndexDetail(symbol);
      _everSucceeded = true;
      final index = _indexFromMap(raw);
      _QuoteCache.store([
        QuoteResult(
          symbol: index.symbol,
          name: index.name,
          price: index.last,
          change: index.change,
          percentChange: index.percentChange,
          volume: 0,
          open: index.open,
          dayHigh: index.dayHigh,
          dayLow: index.dayLow,
          previousClose: index.previousClose,
          weekHigh52: index.weekHigh52,
          weekLow52: index.weekLow52,
        ),
      ]);
      return index;
    } catch (e, st) {
      _log('fetchIndexDetail($symbol) failed: $e');
      dev.log('fetchIndexDetail error', name: 'MarketRepository', error: e, stackTrace: st);
      throw MarketApiException('No live data available for $symbol right now');
    }
  }

  /// Fetches a synthesized index candle series via
  /// `GET /api/market/index-history/:symbol?period=&filter=`. Shares the TTL
  /// cache with stock candles so re-entering the same range is instant.
  Future<List<CandleModel>> fetchIndexCandles({
    required String symbol,
    required ChartRange range,
  }) async {
    final (period, filter) = range.query;
    final cacheKey = 'idx/$symbol/${range.name}';
    final cachedAt = _candleFetchedAt[cacheKey];
    if (cachedAt != null && DateTime.now().difference(cachedAt) < _candleTtl) {
      return _candleCache[cacheKey] ?? const [];
    }
    try {
      final raw = await _api.getIndexHistory(symbol, period: period, filter: filter);
      _everSucceeded = true;
      final candles = raw
          .whereType<Map>()
          .map((m) => _candleFromMap(m.cast<String, dynamic>()))
          .whereType<CandleModel>()
          .toList();
      _candleCache[cacheKey] = candles;
      _candleFetchedAt[cacheKey] = DateTime.now();
      _log('fetchIndexCandles($cacheKey): ${candles.length} candles');
      return candles;
    } catch (e, st) {
      _log('fetchIndexCandles($cacheKey) failed: $e');
      dev.log('fetchIndexCandles error', name: 'MarketRepository', error: e, stackTrace: st);
      return _candleCache[cacheKey] ?? const [];
    }
  }

  /// Kept for backwards compat — returns the NSE most-active list.
  Future<List<StockModel>> fetchTopStocks({bool forceRefresh = false}) async {
    final r = await fetchHomeData(forceRefresh: forceRefresh);
    return r.topStocks;
  }

  IndexModel _indexFromMap(Map<String, dynamic> m) {
    final symbol = (m['symbol'] ?? m['ticker'] ?? m['name'] ?? '').toString();
    final name = (m['companyName'] ?? m['name'] ?? symbol).toString();
    final last = _d(m['currentPrice'] ?? m['price'] ?? m['last']);
    final prev = _d(m['previousClose'] ?? m['prevClose']);
    final change = m['change'] != null
        ? _d(m['change'])
        : (prev == 0 ? 0.0 : last - prev);
    final pct = m['percentChange'] != null
        ? _d(m['percentChange'])
        : (prev == 0 ? 0.0 : (change / prev) * 100);
    return IndexModel(
      symbol: symbol,
      name: name,
      last: last,
      change: change,
      percentChange: pct,
      open: _d(m['open']),
      dayHigh: _d(m['dayHigh'] ?? m['high']),
      dayLow: _d(m['dayLow'] ?? m['low']),
      previousClose: prev,
      weekHigh52: _d(m['yearHigh'] ?? m['fiftyTwoWeekHigh']),
      weekLow52: _d(m['yearLow'] ?? m['fiftyTwoWeekLow']),
    );
  }

  StockModel _stockFromMap(Map<String, dynamic> m) {
    final symbol = (m['symbol'] ?? m['ticker'] ?? '').toString();
    final name = (m['companyName'] ?? m['name'] ?? symbol).toString();
    final percentChange = _d(m['percentChange'] ?? m['pctChange']);
    final blowUpSignal = m['isBlowUpSignal'] == true ||
        m['blowUpSignal'] == true ||
        m['isBlowupSignal'] == true ||
        percentChange >= 3.0;
    return StockModel(
      symbol: symbol,
      name: name,
      ltp: _d(m['currentPrice'] ?? m['price'] ?? m['ltp']),
      change: _d(m['change'] ?? m['dayChange']),
      percentChange: percentChange,
      volume: _d(m['volume']),
      isBlowUpSignal: blowUpSignal,
    );
  }

  // -- Watchlist quotes ---------------------------------------------------

  /// Fetches quotes for an arbitrary list of watchlist symbols. Hits
  /// `POST /api/market/quotes` (batch endpoint). On failure, serves the
  /// last known real quote for each symbol if we have one.
  Future<List<StockModel>> fetchStocks(List<String> symbols) async {
    if (symbols.isEmpty) return const [];
    try {
      final results = await _api.getQuotes(symbols);
      _everSucceeded = true;
      final parsed = results
          .whereType<Map>()
          .map((m) => _stockFromMap(m.cast<String, dynamic>()))
          .toList();
      _QuoteCache.store(parsed.map((s) => QuoteResult(
            symbol: s.symbol,
            name: s.name,
            price: s.ltp,
            change: s.change,
            percentChange: s.percentChange,
            volume: s.volume,
          )));
      _log('fetchStocks(${symbols.length}) -> ${parsed.length} quotes');
      return parsed;
    } catch (e, st) {
      _log('fetchStocks failed: $e, serving last-known where available');
      dev.log('fetchStocks error', name: 'MarketRepository', error: e, stackTrace: st);
      final out = <StockModel>[];
      for (final s in symbols) {
        final q = _QuoteCache.lastKnown[s];
        if (q == null) continue;
        out.add(StockModel(
          symbol: s,
          name: q.name.isEmpty ? s : q.name,
          ltp: q.price,
          change: q.change,
          percentChange: q.percentChange,
          volume: 0,
          isBlowUpSignal: false,
        ));
      }
      return out;
    }
  }

  // -- Stock detail (quote + candles) -------------------------------------

  /// Fetches a single stock's quote + candle series. Used by the stock
  /// detail page. Throws if there's no real data to show — the detail UI
  /// handles that with a clear error state.
  Future<StockDetailModel> fetchStockDetail({
    required String symbol,
    required String name,
    String? exchange,
    double? seedLtp,
    ChartRange range = ChartRange.d1,
  }) async {
    try {
      final raw = await _api.getQuote(symbol);
      _everSucceeded = true;
      // Keep the legacy QuoteResult populated for the watchlist/home caches
      // and the offline fallback path.
      final q = _quoteFromDetailMap(raw);
      _QuoteCache.store([q]);
      final candles = await fetchCandlesForRange(symbol: symbol, range: range);
      return _stockDetailFromMap(raw, fallbackSymbol: symbol, fallbackName: name, candles: candles);
    } catch (e, st) {
      _log('fetchStockDetail($symbol) failed: $e');
      dev.log('fetchStockDetail error', name: 'MarketRepository', error: e, stackTrace: st);
      throw MarketApiException('No live data available for $symbol right now');
    }
  }

  /// Build the full StockDetailModel straight from the raw /quote map. The
  /// simulator and IndianProvider both return the same field names (the
  /// aliases below cover both shapes); the model itself is what powers
  /// `_StatsCard`, `_MarketDepthCard`, the 52-week slider, and the
  /// Fundamentals tab on the detail page.
  StockDetailModel _stockDetailFromMap(
    Map<String, dynamic> m, {
    required String fallbackSymbol,
    required String fallbackName,
    required List<CandleModel> candles,
  }) {
    final sym = (m['symbol'] ?? m['ticker'] ?? m['stockName'] ?? fallbackSymbol).toString();
    final nm = (m['companyName'] ?? m['name'] ?? fallbackName).toString();
    final price = _d(m['currentPrice'] ?? m['price'] ?? m['ltp']);
    final prev = _d(m['previousClose'] ?? m['prevClose']);
    final change = m['change'] != null ? _d(m['change']) : (prev == 0 ? 0.0 : price - prev);
    final pct = m['percentChange'] != null
        ? _d(m['percentChange'])
        : (prev == 0 ? 0.0 : (change / prev) * 100);

    return StockDetailModel(
      symbol: sym.isEmpty ? fallbackSymbol : sym,
      name: nm.isEmpty ? fallbackName : nm,
      exchange: (m['exchange'] ?? '').toString(),
      sector: (m['sector'] ?? '').toString(),
      industry: (m['industry'] ?? '').toString(),

      ltp: price,
      change: change,
      percentChange: pct,
      open: _d(m['open']),
      dayHigh: _d(m['dayHigh'] ?? m['high']),
      dayLow: _d(m['dayLow'] ?? m['low']),
      previousClose: prev,
      volume: _d(m['volume']),
      avgVolume: _d(m['avgVolume']),
      bid: _d(m['bid']),
      ask: _d(m['ask']),

      weekHigh52: _d(m['yearHigh'] ?? m['fiftyTwoWeekHigh']),
      weekLow52: _d(m['yearLow'] ?? m['fiftyTwoWeekLow']),
      weekHigh52Date: m['yearHighDate']?.toString(),
      weekLow52Date: m['yearLowDate']?.toString(),

      marketCap: _d(m['marketCap']),
      peRatio: _d(m['peRatio']),
      eps: _d(m['eps']),
      bookValue: _d(m['bookValue']),
      dividendYield: _d(m['dividendYield']),
      beta: _d(m['beta']),
      faceValue: _d(m['faceValue']),
      lotSize: _d(m['lotSize']).round(),

      upperCircuit: _d(m['upperCircuit']),
      lowerCircuit: _d(m['lowerCircuit']),
      circuitPct: _d(m['circuitPct']),
      atp: _d(m['atp']),

      depth: m['depth'] is Map
          ? MarketDepth.fromMap((m['depth'] as Map).cast<String, dynamic>())
          : MarketDepth.empty,

      candles: candles,
    );
  }

  QuoteResult _quoteFromDetailMap(Map<String, dynamic> m) {
    final symbol = (m['symbol'] ?? m['ticker'] ?? m['stockName'] ?? '').toString();
    final name = (m['companyName'] ?? m['name'] ?? symbol).toString();
    final price = _d(m['currentPrice'] ?? m['price'] ?? m['ltp']);
    final prev = _d(m['previousClose'] ?? m['prevClose']);
    final change = m['change'] != null
        ? _d(m['change'])
        : (prev == 0 ? 0.0 : price - prev);
    final pct = m['percentChange'] != null
        ? _d(m['percentChange'])
        : (prev == 0 ? 0.0 : (change / prev) * 100);
    return QuoteResult(
      symbol: symbol,
      name: name,
      price: price,
      change: change,
      percentChange: pct,
      volume: _d(m['volume']),
      open: _d(m['open']),
      dayHigh: _d(m['dayHigh'] ?? m['high']),
      dayLow: _d(m['dayLow'] ?? m['low']),
      previousClose: prev,
      weekHigh52: _d(m['yearHigh'] ?? m['fiftyTwoWeekHigh']),
      weekLow52: _d(m['yearLow'] ?? m['fiftyTwoWeekLow']),
    );
  }

  // -- Chart candles ------------------------------------------------------

  static final Map<String, List<CandleModel>> _candleCache = {};
  static final Map<String, DateTime> _candleFetchedAt = {};
  static const Duration _candleTtl = Duration(seconds: 60);

  Future<List<CandleModel>> fetchCandlesForRange({
    required String symbol,
    required ChartRange range,
  }) async {
    final (period, filter) = range.query;
    final cacheKey = '$symbol/${range.name}';
    final cachedAt = _candleFetchedAt[cacheKey];
    if (cachedAt != null && DateTime.now().difference(cachedAt) < _candleTtl) {
      _log('fetchCandlesForRange($cacheKey): cache hit');
      return _candleCache[cacheKey] ?? const [];
    }

    try {
      final raw = await _api.getHistory(symbol, period: period, filter: filter);
      _everSucceeded = true;
      final candles = raw
          .whereType<Map>()
          .map((m) => _candleFromMap(m.cast<String, dynamic>()))
          .whereType<CandleModel>()
          .toList();
      if (candles.isEmpty) {
        _log('fetchCandlesForRange($cacheKey): empty response');
        return _candleCache[cacheKey] ?? const [];
      }
      _candleCache[cacheKey] = candles;
      _candleFetchedAt[cacheKey] = DateTime.now();
      _log('fetchCandlesForRange($cacheKey): ${candles.length} candles');
      return candles;
    } catch (e, st) {
      _log('fetchCandlesForRange($cacheKey) failed: $e, serving stale cache if any');
      dev.log('fetchCandlesForRange error', name: 'MarketRepository', error: e, stackTrace: st);
      return _candleCache[cacheKey] ?? const [];
    }
  }

  CandleModel? _candleFromMap(Map<String, dynamic> m) {
    final t = DateTime.tryParse((m['datetime'] ?? m['date'] ?? '').toString());
    if (t == null) return null;
    return CandleModel(
      time: t,
      close: _d(m['close'] ?? m['price']),
      high: _d(m['high']),
      low: _d(m['low']),
      volume: _d(m['volume']),
    );
  }

  // -- Symbol search ------------------------------------------------------

  static List<StockListing>? _searchCache;
  static bool _searchIsLive = false;

  bool get stockListIsLive => _searchIsLive;

  /// Fetches the search catalog from the backend dashboard so the app shows
  /// live market symbols instead of a static frontend list. The actual
  /// typeahead goes through [searchStocks] below.
  Future<List<StockListing>> fetchIndianStockList({bool forceRefresh = false}) async {
    if (!forceRefresh && _searchCache != null) return _searchCache!;
    try {
      final dashboard = await _getDashboard(forceRefresh: forceRefresh);
      final seen = <String>{};
      final out = <StockListing>[];
      void addList(List<dynamic>? items, String defaultExchange) {
        for (final item in items ?? const []) {
          if (item is! Map) continue;
          final map = Map<String, dynamic>.from(item);
          final symbol = (map['symbol'] ?? map['ticker'] ?? '').toString().trim().toUpperCase();
          if (symbol.isEmpty || seen.contains(symbol)) continue;
          final name = (map['companyName'] ?? map['name'] ?? symbol).toString();
          out.add(StockListing(
            symbol: symbol,
            name: name,
            exchange: (map['exchange'] ?? defaultExchange).toString(),
            type: 'Common Stock',
          ));
          seen.add(symbol);
        }
      }

      addList((dashboard['nseMostActive'] as List?) ?? const [], 'NSE');
      addList((dashboard['bseMostActive'] as List?) ?? const [], 'BSE');
      addList((dashboard['trending'] as List?) ?? const [], 'NSE');

      _searchCache = out;
      _searchIsLive = true;
      return out;
    } catch (e, st) {
      _log('fetchIndianStockList failed: $e');
      dev.log('fetchIndianStockList error', name: 'MarketRepository', error: e, stackTrace: st);
      _searchCache = const [];
      _searchIsLive = false;
      return const [];
    }
  }

  /// Debounced typeahead called from the search page. Hits
  /// `GET /api/market/search?query=...`.
  Future<List<StockListing>> searchStocks(String query) async {
    try {
      final results = await _api.search(query);
      _everSucceeded = true;
      _searchIsLive = true;
      return results
          .whereType<Map>()
          .map((m) => _listingFromMap(m.cast<String, dynamic>()))
          .where((s) => s.symbol.isNotEmpty)
          .toList();
    } catch (e, st) {
      _log('searchStocks failed: $e');
      dev.log('searchStocks error', name: 'MarketRepository', error: e, stackTrace: st);
      // Fall back to a substring match on the offline list so the user
      // still gets useful results.
      final q = query.trim().toLowerCase();
      if (q.isEmpty) return _offlineStockList();
      return _offlineStockList()
          .where((s) =>
              s.symbol.toLowerCase().contains(q) ||
              s.name.toLowerCase().contains(q))
          .toList();
    }
  }

  StockListing _listingFromMap(Map<String, dynamic> m) {
    return StockListing(
      symbol: (m['symbol'] ?? m['ticker'] ?? '').toString(),
      name: (m['companyName'] ?? m['name'] ?? '').toString(),
      exchange: (m['exchange'] ?? 'NSE').toString(),
      type: (m['type'] ?? 'Common Stock').toString(),
    );
  }

  static const List<String> kNiftySymbols = [
    'RELIANCE', 'TCS', 'HDFCBANK', 'INFY', 'ICICIBANK', 'SBIN',
    'BHARTIARTL', 'ITC', 'KOTAKBANK', 'LT', 'AXISBANK', 'WIPRO',
    'HINDUNILVR', 'BAJFINANCE', 'BAJAJFINSV', 'MARUTI', 'ASIANPAINT',
    'SUNPHARMA', 'TITAN', 'ULTRACEMCO', 'NESTLEIND', 'POWERGRID',
    'M&M', 'NTPC', 'TECHM', 'TATAMOTORS', 'TATASTEEL', 'JSWSTEEL',
    'INDUSINDBK', 'ADANIENT', 'ADANIPORTS', 'COALINDIA', 'BPCL',
    'CIPLA', 'DIVISLAB', 'DRREDDY', 'EICHERMOT', 'GRASIM', 'HCLTECH',
    'HEROMOTOCO', 'HINDALCO', 'APOLLOHOSP', 'BRITANNIA', 'BANDHANBNK',
    'BAJAJ-AUTO', 'SHRIRAMFIN', 'SBILIFE', 'HDFCLIFE', 'ONGC',
    'LTIM', 'TATACONSUM',
  ];

  List<StockListing> _offlineStockList() {
    return kNiftySymbols
        .map((s) => StockListing(symbol: s, name: s, exchange: 'NSE'))
        .toList();
  }

  double _d(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
}

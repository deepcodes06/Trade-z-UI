import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../backend/models/stock_listing_model.dart';
import '../../backend/repositories/market_repository.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_responsive.dart';
import '../../widgets/neon_backdrop.dart';
import '../stock_detail/stock_detail_page.dart';

/// Typeahead search across the backend's /api/market/search endpoint.
///
/// The backend exposes search as a per-query endpoint (not a "give me the
/// whole catalog" endpoint), so the page debounces typing by 300ms and
/// calls the server with the current query. When the query is empty we
/// show a curated offline list of well-known NSE symbols so the page
/// still has something useful to render before the user has typed
/// anything.
class StockSearchPage extends StatefulWidget {
  const StockSearchPage({super.key});

  @override
  State<StockSearchPage> createState() => _StockSearchPageState();
}

enum _ExchangeFilter { all, nse, bse }

class _StockSearchPageState extends State<StockSearchPage> {
  final _repo = MarketRepository();
  final _controller = TextEditingController();

  List<StockListing> _results = const [];
  _ExchangeFilter _filter = _ExchangeFilter.all;
  bool _loading = false;
  String? _error;
  Timer? _debounce;
  int _requestSeq = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQueryChanged);
    _loadInitial();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onQueryChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _repo.fetchIndianStockList();
      if (!mounted) return;
      setState(() {
        _results = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load the stock list: $e';
      });
    }
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    final query = _controller.text.trim();
    if (query.isEmpty) {
      _loadInitial();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _runSearch(query);
    });
  }

  Future<void> _runSearch(String query) async {
    final seq = ++_requestSeq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _repo.searchStocks(query);
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _results = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _loading = false;
        _error = 'Search failed: $e';
      });
    }
  }

  List<StockListing> get _filtered {
    Iterable<StockListing> src = _results;
    if (_filter == _ExchangeFilter.nse) {
      src = src.where((s) => s.exchange == 'NSE');
    } else if (_filter == _ExchangeFilter.bse) {
      src = src.where((s) => s.exchange == 'BSE');
    }
    return src.take(200).toList();
  }

  @override
  Widget build(BuildContext context) {
    AppResponsive.init(context);
    final p = AppPalette.of(context);
    final query = _controller.text.trim();
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.topBar,
        elevation: 0,
        iconTheme: IconThemeData(color: p.icon),
        titleSpacing: 0,
        title: Padding(
          padding: EdgeInsets.only(right: AppResponsive.w(12)),
          child: Container(
            height: AppResponsive.h(40),
            decoration: BoxDecoration(
              color: const Color(0x0A1743A3),
              borderRadius: BorderRadius.circular(AppResponsive.w(10)),
              border: Border.all(color: p.border, width: 0.8),
            ),
            child: TextField(
              controller: _controller,
              autofocus: true,
              style: TextStyle(color: p.textPrimary, fontSize: AppResponsive.font(14)),
              decoration: InputDecoration(
                hintText: 'Search NSE & BSE stocks',
                hintStyle: TextStyle(color: p.textMuted, fontSize: AppResponsive.font(14)),
                prefixIcon: Icon(Icons.search, color: p.textMuted, size: AppResponsive.w(20)),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        icon: Icon(Icons.close, color: p.textMuted, size: AppResponsive.w(18)),
                        onPressed: () => _controller.clear(),
                      ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: AppResponsive.h(10)),
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: NeonBackdrop()),
          Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppResponsive.w(16),
              AppResponsive.h(10),
              AppResponsive.w(16),
              AppResponsive.h(4),
            ),
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  selected: _filter == _ExchangeFilter.all,
                  onTap: () => setState(() => _filter = _ExchangeFilter.all),
                ),
                SizedBox(width: AppResponsive.w(8)),
                _FilterChip(
                  label: 'NSE',
                  selected: _filter == _ExchangeFilter.nse,
                  onTap: () => setState(() => _filter = _ExchangeFilter.nse),
                ),
                SizedBox(width: AppResponsive.w(8)),
                _FilterChip(
                  label: 'BSE',
                  selected: _filter == _ExchangeFilter.bse,
                  onTap: () => setState(() => _filter = _ExchangeFilter.bse),
                ),
                const Spacer(),
                if (_loading)
                  SizedBox(
                    width: AppResponsive.w(14),
                    height: AppResponsive.w(14),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: p.primary,
                    ),
                  )
                else
                  Text(
                    '${filtered.length} results',
                    style: GoogleFonts.inter(color: p.textMuted, fontSize: AppResponsive.font(11)),
                  ),
              ],
            ),
          ),
          Expanded(child: _buildBody(p, filtered)),
          ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody(AppPalette p, List<StockListing> filtered) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: AppResponsive.padAll(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: p.loss, size: AppResponsive.w(32)),
              SizedBox(height: AppResponsive.h(10)),
              Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: p.textSecondary)),
              SizedBox(height: AppResponsive.h(12)),
              ElevatedButton(
                onPressed: () => _controller.text.trim().isEmpty
                    ? _loadInitial()
                    : _runSearch(_controller.text.trim()),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (filtered.isEmpty) {
      return Center(
        child: Text(
          _controller.text.trim().isEmpty ? 'Start typing to search' : 'No matches found',
          style: TextStyle(color: p.textMuted),
        ),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.symmetric(horizontal: AppResponsive.w(12), vertical: AppResponsive.h(4)),
      itemCount: filtered.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: p.divider),
      itemBuilder: (context, i) {
        final s = filtered[i];
        final exchangeColor = s.exchange == 'NSE' ? p.primary : p.accent;
        return ListTile(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StockDetailPage(
                symbol: s.symbol,
                name: s.name.isEmpty ? s.symbol : s.name,
                exchange: s.exchange,
              ),
            ),
          ),
          leading: Container(
            width: AppResponsive.w(36),
            height: AppResponsive.w(36),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: exchangeColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppResponsive.w(8)),
            ),
            child: Text(
              s.symbol.isEmpty ? '?' : s.symbol.substring(0, 1),
              style: TextStyle(color: exchangeColor, fontWeight: FontWeight.w800),
            ),
          ),
          title: Text(
            s.symbol,
            style: GoogleFonts.spaceGrotesk(
              color: p.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: AppResponsive.font(14),
            ),
          ),
          subtitle: s.name.isEmpty || s.name == s.symbol
              ? null
              : Text(
                  s.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(color: p.textMuted, fontSize: AppResponsive.font(12)),
                ),
          trailing: Container(
            padding: EdgeInsets.symmetric(horizontal: AppResponsive.w(8), vertical: AppResponsive.h(4)),
            decoration: BoxDecoration(
              color: exchangeColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppResponsive.w(6)),
            ),
            child: Text(
              s.exchange,
              style: TextStyle(
                color: exchangeColor,
                fontSize: AppResponsive.font(11),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: AppResponsive.w(14), vertical: AppResponsive.h(6)),
        decoration: BoxDecoration(
          color: selected ? p.primary : p.softHighlight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? p.primary : p.border, width: 0.8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? p.onPrimary : p.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: AppResponsive.font(12),
          ),
        ),
      ),
    );
  }
}

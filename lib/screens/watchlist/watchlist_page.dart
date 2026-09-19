import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../backend/bloc/watchlist/watchlist_bloc.dart';
import '../../backend/bloc/watchlist/watchlist_event.dart';
import '../../backend/bloc/watchlist/watchlist_state.dart';
import '../../backend/models/stock_listing_model.dart';
import '../../backend/models/watchlist_model.dart';
import '../../backend/repositories/market_repository.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_responsive.dart';
import '../../constants/app_strings.dart';
import '../stock_detail/stock_detail_page.dart';

class WatchlistPage extends StatefulWidget {
  final VoidCallback onSearchTap;
  final VoidCallback onProfileTap;

  const WatchlistPage({
    super.key,
    required this.onSearchTap,
    required this.onProfileTap,
  });

  @override
  State<WatchlistPage> createState() => _WatchlistPageState();
}

class _WatchlistPageState extends State<WatchlistPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WatchlistBloc>().add(const WatchlistsLoadRequested());
    });
  }

  @override
  Widget build(BuildContext context) {
    AppResponsive.init(context);
    return BlocConsumer<WatchlistBloc, WatchlistState>(
      listenWhen: (a, b) => a.error != b.error && b.error != null,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(state.error ?? ''),
            backgroundColor: AppPalette.of(context).warning,
          ));
      },
      builder: (context, state) {
        if (state.status == WatchlistStatus.loading && state.lists.isEmpty) {
          return Center(
            child: CircularProgressIndicator(color: AppPalette.of(context).primary),
          );
        }
        return Column(
          children: [
            _Tabs(state: state),
            SizedBox(height: AppResponsive.h(6)),
            _ListHint(state: state),
            Expanded(child: _ListBody(state: state)),
          ],
        );
      },
    );
  }
}

class _Tabs extends StatelessWidget {
  final WatchlistState state;
  const _Tabs({required this.state});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SizedBox(
      height: AppResponsive.h(46),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: AppResponsive.symH(14),
        itemCount: state.lists.length + 1,
        separatorBuilder: (_, i) => SizedBox(width: AppResponsive.w(8)),
        itemBuilder: (_, i) {
          if (i == state.lists.length) {
            final canCreate = state.lists.length < WatchlistState.maxLists;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: canCreate
                    ? () => _showCreateDialog(context)
                    : () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text(AppStrings.maxWatchlists)),
                        ),
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppResponsive.w(14),
                    vertical: AppResponsive.h(7),
                  ),
                  decoration: BoxDecoration(
                    color: p.surfaceAlt,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: p.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add,
                          size: AppResponsive.w(16),
                          color: canCreate ? p.primary : p.textMuted),
                      SizedBox(width: AppResponsive.w(4)),
                      Text(
                        'New (${state.lists.length}/${WatchlistState.maxLists})',
                        style: GoogleFonts.inter(
                          color: canCreate ? p.primary : p.textMuted,
                          fontSize: AppResponsive.font(12),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          final w = state.lists[i];
          final selected = w.id == state.activeId;
          return InkWell(
            onTap: () => context
                .read<WatchlistBloc>()
                .add(WatchlistActiveStocksRequested(w.id)),
            onLongPress: () => _showListOptions(context, w),
            borderRadius: BorderRadius.circular(22),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(
                horizontal: AppResponsive.w(14),
                vertical: AppResponsive.h(7),
              ),
              decoration: BoxDecoration(
                color: selected ? p.primary : p.softHighlight,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: selected ? p.primary : p.border,
                  width: 0.8,
                ),
              ),
              child: Text(
                w.name,
                style: GoogleFonts.inter(
                  color: selected ? p.onPrimary : p.textPrimary,
                  fontSize: AppResponsive.font(13),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    final p = AppPalette.of(context);
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.surface,
        title: const Text('Create Watchlist'),
        content: TextField(
          controller: controller,
          style: TextStyle(color: p.textPrimary),
          decoration: const InputDecoration(hintText: 'Watchlist name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              context
                  .read<WatchlistBloc>()
                  .add(WatchlistCreateRequested(controller.text));
              Navigator.pop(ctx);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showListOptions(BuildContext context, WatchlistModel w) {
    final p = AppPalette.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.edit, color: p.icon),
              title: Text('Rename', style: TextStyle(color: p.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                final controller = TextEditingController(text: w.name);
                showDialog<void>(
                  context: context,
                  builder: (dctx) => AlertDialog(
                    backgroundColor: p.surface,
                    title: const Text('Rename Watchlist'),
                    content: TextField(
                      controller: controller,
                      style: TextStyle(color: p.textPrimary),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('Cancel')),
                      ElevatedButton(
                        onPressed: () {
                          context
                              .read<WatchlistBloc>()
                              .add(WatchlistRenameRequested(id: w.id, name: controller.text));
                          Navigator.pop(dctx);
                        },
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: p.loss),
              title: Text('Delete', style: TextStyle(color: p.loss)),
              onTap: () {
                Navigator.pop(ctx);
                context.read<WatchlistBloc>().add(WatchlistDeleteRequested(w.id));
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ListHint extends StatelessWidget {
  final WatchlistState state;
  const _ListHint({required this.state});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final active = state.lists.firstWhere(
      (w) => w.id == state.activeId,
      orElse: () => state.lists.isEmpty
          ? const WatchlistModel(id: '', name: '', symbols: [])
          : state.lists.first,
    );
    return Padding(
      padding: AppResponsive.symH(16).add(EdgeInsets.symmetric(vertical: AppResponsive.h(6))),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: state.isLive ? p.gain : p.warning,
                  ),
                ),
                SizedBox(width: AppResponsive.w(6)),
                Flexible(
                  child: Text(
                    '${active.symbols.length}/${WatchlistState.maxStocksPerList} stocks',
                    style: GoogleFonts.inter(
                      color: p.textSecondary,
                      fontSize: AppResponsive.font(12),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (state.lastUpdated != null) ...[
                  SizedBox(width: AppResponsive.w(8)),
                  Flexible(
                    child: Text(
                      '•  ${_fmt(state.lastUpdated!)}',
                      style: GoogleFonts.inter(
                        color: p.textMuted,
                        fontSize: AppResponsive.font(11),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () => _showAddStockSheet(context, active),
            icon: Icon(Icons.add, size: AppResponsive.w(16), color: p.primary),
            label: Text(
              'Add stock',
              style: GoogleFonts.inter(
                color: p.primary,
                fontSize: AppResponsive.font(12),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime t) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    final ss = t.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  void _showAddStockSheet(BuildContext context, WatchlistModel active) {
    final p = AppPalette.of(context);
    final repo = MarketRepository();
    final searchCtrl = TextEditingController();
    List<StockListing> candidates = const [];
    bool loading = false;
    String? error;
    Timer? debounce;
    bool loadedInitial = false;

    Future<void> runSearch(String query) async {
      debounce?.cancel();
      if (query.trim().isEmpty) {
        candidates = const [];
        error = null;
        loading = false;
        return;
      }
      loading = true;
      error = null;
      debounce = Timer(const Duration(milliseconds: 300), () async {
        try {
          final results = await repo.searchStocks(query.trim());
          if (!context.mounted) return;
          candidates = results;
          loading = false;
          error = null;
        } catch (e) {
          if (!context.mounted) return;
          candidates = const [];
          loading = false;
          error = e.toString();
        }
      });
    }

    Future<void> loadInitial() async {
      if (loadedInitial) return;
      loadedInitial = true;
      loading = true;
      error = null;
      try {
        final results = await repo.fetchIndianStockList();
        if (!context.mounted) return;
        candidates = results;
        loading = false;
      } catch (e) {
        if (!context.mounted) return;
        candidates = const [];
        loading = false;
        error = e.toString();
      }
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: p.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          if (!loadedInitial && searchCtrl.text.isEmpty) {
            Future.microtask(loadInitial).then((_) => setSheetState(() {}));
          }
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.75,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            builder: (_, scroll) => Padding(
              padding: EdgeInsets.only(
                left: AppResponsive.w(16),
                right: AppResponsive.w(16),
                top: AppResponsive.h(12),
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Column(
                children: [
                  Container(
                    width: AppResponsive.w(40),
                    height: AppResponsive.h(4),
                    margin: EdgeInsets.only(bottom: AppResponsive.h(10)),
                    decoration: BoxDecoration(
                      color: p.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Text(
                    'Add to ${active.name}',
                    style: GoogleFonts.spaceGrotesk(
                      color: p.textPrimary,
                      fontSize: AppResponsive.font(16),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: AppResponsive.h(8)),
                  TextField(
                    controller: searchCtrl,
                    onChanged: (value) {
                      runSearch(value);
                      setSheetState(() {});
                    },
                    decoration: InputDecoration(
                      hintText: 'Search NSE & BSE symbols',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppResponsive.w(12)),
                      ),
                    ),
                  ),
                  SizedBox(height: AppResponsive.h(8)),
                  if (loading)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: AppResponsive.h(16)),
                      child: CircularProgressIndicator(color: p.primary),
                    )
                  else if (error != null)
                    Text(error!, style: TextStyle(color: p.loss))
                  else
                    Expanded(
                      child: ListView.separated(
                        controller: scroll,
                        itemCount: candidates.length,
                        separatorBuilder: (_, i) => Divider(color: p.divider, height: 1),
                        itemBuilder: (_, i) {
                          final s = candidates[i];
                          final exists = active.symbols.any((symbol) => symbol.toUpperCase() == s.symbol.toUpperCase());
                          return ListTile(
                            title: Text(
                              s.symbol,
                              style: TextStyle(color: p.textPrimary, fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              s.name.isEmpty ? s.symbol : s.name,
                              style: TextStyle(color: p.textSecondary),
                            ),
                            trailing: exists
                                ? Icon(Icons.check_circle, color: p.gain)
                                : IconButton(
                                    icon: Icon(Icons.add_circle, color: p.primary),
                                    onPressed: () {
                                      context.read<WatchlistBloc>().add(
                                            WatchlistAddStockRequested(
                                              watchlistId: active.id,
                                              symbol: s.symbol.toUpperCase(),
                                            ),
                                          );
                                      Navigator.pop(ctx);
                                    },
                                  ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ListBody extends StatelessWidget {
  final WatchlistState state;
  const _ListBody({required this.state});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    if (state.lists.isEmpty) {
      return _EmptyState(onCreate: () {
        context.read<WatchlistBloc>().add(const WatchlistCreateRequested('My Watchlist'));
      });
    }
    final active = state.lists.firstWhere(
      (w) => w.id == state.activeId,
      orElse: () => state.lists.first,
    );
    if (active.symbols.isEmpty) {
      return Center(
        child: Padding(
          padding: AppResponsive.padAll(16),
          child: Text(
            'No stocks yet. Tap "Add stock" to start tracking.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: p.textSecondary,
              fontSize: AppResponsive.font(13),
            ),
          ),
        ),
      );
    }
    return Container(
      margin: AppResponsive.symH(16),
      decoration: GlassCard.of(context, radius: AppResponsive.w(16)),
      child: Column(
        children: [
          for (var i = 0; i < active.symbols.length; i++) ...[
            _WatchlistRow(symbol: active.symbols[i], state: state),
            if (i != active.symbols.length - 1)
              Divider(height: 1, color: p.divider, indent: AppResponsive.w(72)),
          ]
        ],
      ),
    );
  }
}

class _WatchlistRow extends StatelessWidget {
  final String symbol;
  final WatchlistState state;
  const _WatchlistRow({required this.symbol, required this.state});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final live = state.activeStocks
        .where((s) => s.symbol == symbol)
        .cast<dynamic>()
        .firstOrNull;
    final ltp = live?.ltp as double? ?? 0.0;
    final change = live?.change as double? ?? 0.0;
    final pct = live?.percentChange as double? ?? 0.0;
    return Dismissible(
      key: ValueKey(symbol),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: AppResponsive.w(20)),
        color: p.loss,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        final state = context.read<WatchlistBloc>().state;
        if (state.activeId != null) {
          context.read<WatchlistBloc>().add(
                WatchlistRemoveStockRequested(
                    watchlistId: state.activeId!, symbol: symbol),
              );
        }
      },
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StockDetailPage(
              symbol: symbol,
              name: symbol,
              exchange: 'NSE',
              seedLtp: live == null ? null : ltp,
              seedChange: live == null ? null : change,
              seedPercentChange: live == null ? null : pct,
            ),
          ),
        ),
        leading: Container(
          width: AppResponsive.w(42),
          height: AppResponsive.w(42),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: p.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppResponsive.w(12)),
            border: Border.all(color: p.primary.withValues(alpha: 0.3)),
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
        title: Text(
          symbol,
          style: GoogleFonts.inter(
            color: p.textPrimary,
            fontSize: AppResponsive.font(15),
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        subtitle: Text(
          live == null
              ? 'Loading…'
              : 'LTP ${ltp.toStringAsFixed(2)}  •  ${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)}%',
          style: GoogleFonts.inter(
            color: p.textSecondary,
            fontSize: AppResponsive.font(12),
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Padding(
                padding: EdgeInsets.only(right: AppResponsive.w(4)),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    live == null ? '—' : '${change >= 0 ? '+' : ''}${change.toStringAsFixed(2)}',
                    style: GoogleFonts.inter(
                      color: live == null
                          ? p.textMuted
                          : (change >= 0 ? p.gain : p.loss),
                      fontSize: AppResponsive.font(13),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: AppResponsive.w(28),
              height: AppResponsive.w(28),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppResponsive.w(8)),
                onTap: () {
                  final s = context.read<WatchlistBloc>().state;
                  if (s.activeId != null) {
                    context.read<WatchlistBloc>().add(
                          WatchlistRemoveStockRequested(
                              watchlistId: s.activeId!, symbol: symbol),
                        );
                  }
                },
                child: Icon(Icons.close,
                    color: p.textMuted, size: AppResponsive.w(18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Center(
      child: Padding(
        padding: AppResponsive.padAll(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: AppResponsive.w(88),
              height: AppResponsive.w(88),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: p.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
                border: Border.all(color: p.primary.withValues(alpha: 0.3)),
              ),
              child: Icon(Icons.bookmark_outline,
                  size: AppResponsive.w(40), color: p.primary),
            ),
            SizedBox(height: AppResponsive.h(14)),
            Text(
              'No watchlists yet',
              style: GoogleFonts.spaceGrotesk(
                color: p.textPrimary,
                fontSize: AppResponsive.font(18),
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: AppResponsive.h(6)),
            Text(
              'Create your first watchlist to track stocks you love.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: p.textSecondary,
                fontSize: AppResponsive.font(13),
              ),
            ),
            SizedBox(height: AppResponsive.h(16)),
            ElevatedButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Create Watchlist'),
            ),
          ],
        ),
      ),
    );
  }
}

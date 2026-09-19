import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../backend/bloc/home/home_bloc.dart';
import '../../backend/bloc/home/home_event.dart';
import '../../backend/bloc/home/home_state.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_responsive.dart';
import '../../constants/app_strings.dart';
import '../index_detail/index_detail_page.dart';
import '../stock_detail/stock_detail_page.dart';
import '../../widgets/stock_widgets.dart';

class HomePage extends StatefulWidget {
  final VoidCallback onSearchTap;
  final VoidCallback onProfileTap;

  const HomePage({super.key, required this.onSearchTap, required this.onProfileTap});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeBloc>().add(const HomeLoadRequested());
    });
  }

  @override
  Widget build(BuildContext context) {
    AppResponsive.init(context);
    final p = AppPalette.of(context);
    return RefreshIndicator(
      color: p.primary,
      backgroundColor: p.surface,
      onRefresh: () async {
        context.read<HomeBloc>().add(const HomeRefreshRequested());
        await context.read<HomeBloc>().stream.firstWhere(
              (s) => s.status != HomeStatus.loading,
            );
      },
      child: ListView(
        padding: EdgeInsets.only(bottom: AppResponsive.h(24)),
        children: [
          BlocBuilder<HomeBloc, HomeState>(
            buildWhen: (a, b) =>
                a.isLive != b.isLive ||
                a.isMarketOpen != b.isMarketOpen ||
                a.lastUpdated != b.lastUpdated,
            builder: (context, state) {
              return Padding(
                padding: AppResponsive.symH(16).add(
                  EdgeInsets.only(top: AppResponsive.h(8)),
                ),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: !state.isMarketOpen
                            ? p.warning
                            : state.isLive
                                ? p.gain
                                : p.warning,
                        boxShadow: state.isLive && state.isMarketOpen
                            ? [BoxShadow(color: p.gain.withValues(alpha: 0.5), blurRadius: 8)]
                            : null,
                      ),
                    ),
                    SizedBox(width: AppResponsive.w(6)),
                    Text(
                      !state.isMarketOpen
                          ? 'MARKET CLOSED'
                          : state.isLive
                              ? 'LIVE'
                              : 'CONNECTING…',
                      style: GoogleFonts.inter(
                        color: !state.isMarketOpen
                            ? p.warning
                            : state.isLive
                                ? p.gain
                                : p.textSecondary,
                        fontSize: AppResponsive.font(11),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const Spacer(),
                    if (state.lastUpdated != null)
                      Text(
                        'Updated ${_formatTime(state.lastUpdated!)}',
                        style: GoogleFonts.inter(
                          color: p.textMuted,
                          fontSize: AppResponsive.font(11),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),

          _SectionHeader(title: AppStrings.indices),
          BlocBuilder<HomeBloc, HomeState>(
            builder: (context, state) {
              if (state.status == HomeStatus.loading && state.indices.isEmpty) {
                return Padding(
                  padding: AppResponsive.padAll(16),
                  child: Center(
                    child: CircularProgressIndicator(color: p.primary),
                  ),
                );
              }
              final visibleIndices = state.indices.take(4).toList();
              return Padding(
                padding: AppResponsive.symH(16),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: AppResponsive.isTablet ? 4 : 2,
                    mainAxisSpacing: AppResponsive.h(10),
                    crossAxisSpacing: AppResponsive.w(10),
                    childAspectRatio: AppResponsive.isTablet ? 1.6 : 2.0,
                  ),
                  itemCount: visibleIndices.length,
                  itemBuilder: (_, i) {
                    final idx = visibleIndices[i];
                    return IndexTile(
                      name: idx.name,
                      last: idx.last,
                      change: idx.change,
                      percentChange: idx.percentChange,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => IndexDetailPage(seed: idx),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),

          SizedBox(height: AppResponsive.h(18)),

          _SectionHeader(title: AppStrings.topNifty),
          BlocBuilder<HomeBloc, HomeState>(
            builder: (context, state) {
              if (state.status == HomeStatus.loading && state.topStocks.isEmpty) {
                return Padding(
                  padding: AppResponsive.padAll(16),
                  child: Center(
                    child: CircularProgressIndicator(color: p.primary),
                  ),
                );
              }
              final visibleStocks = state.topStocks.take(6).toList();
              return Container(
                margin: AppResponsive.symH(16),
                decoration: GlassCard.of(context, radius: AppResponsive.w(16)),
                child: Column(
                  children: List.generate(visibleStocks.length, (i) {
                    final s = visibleStocks[i];
                    return Column(
                      children: [
                        StockTile(
                          symbol: s.symbol,
                          name: s.name,
                          ltp: s.ltp,
                          change: s.change,
                          percentChange: s.percentChange,
                          isBlowUpSignal: s.isBlowUpSignal,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StockDetailPage(
                                symbol: s.symbol,
                                name: s.name,
                                exchange: 'NSE',
                                seedLtp: s.ltp,
                                seedChange: s.change,
                                seedPercentChange: s.percentChange,
                              ),
                            ),
                          ),
                        ),
                        if (i != visibleStocks.length - 1)
                          Divider(
                            height: 1,
                            color: p.divider,
                            indent: AppResponsive.w(72),
                          ),
                      ],
                    );
                  }),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: AppResponsive.symH(16).add(
        EdgeInsets.only(top: AppResponsive.h(10), bottom: AppResponsive.h(8)),
      ),
      child: Text(
        title,
        style: GoogleFonts.spaceGrotesk(
          color: p.textPrimary,
          fontSize: AppResponsive.font(16),
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

String _formatTime(DateTime t) {
  final hh = t.hour.toString().padLeft(2, '0');
  final mm = t.minute.toString().padLeft(2, '0');
  final ss = t.second.toString().padLeft(2, '0');
  return '$hh:$mm:$ss';
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../backend/bloc/home/home_bloc.dart';
import '../backend/bloc/orders/orders_bloc.dart';
import '../backend/bloc/portfolio/portfolio_bloc.dart';
import '../backend/bloc/profile/profile_bloc.dart';
import '../constants/app_colors.dart';
import '../constants/app_responsive.dart';
import '../constants/app_strings.dart';
import '../screens/home/home_page.dart';
import '../screens/orders/orders_page.dart';
import '../screens/portfolio/portfolio_page.dart';
import '../screens/profile/profile_page.dart';
import '../screens/search/stock_search_page.dart';
import '../screens/watchlist/watchlist_page.dart';
import '../widgets/app_bottom_bar.dart';
import '../widgets/app_top_bar.dart';
import 'neon_backdrop.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _index = 0;
  final List<Widget?> _pages = List<Widget?>.filled(5, null, growable: false);

  @override
  void initState() {
    super.initState();
    _pages[0] = _pageForIndex(0);
  }

  String get _title => switch (_index) {
        0 => AppStrings.appName,
        1 => AppStrings.watchlist,
        2 => AppStrings.portfolio,
        3 => AppStrings.orders,
        _ => AppStrings.profile,
      };

  void _onSearchTap() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const StockSearchPage()));
  }

  void _onProfileTap() {
    setState(() => _index = 4);
  }

  Widget _pageForIndex(int index) {
    return switch (index) {
      0 => BlocProvider(
            create: (_) => HomeBloc(),
            child: HomePage(onSearchTap: _onSearchTap, onProfileTap: _onProfileTap),
          ),
      1 => WatchlistPage(onSearchTap: _onSearchTap, onProfileTap: _onProfileTap),
      2 => BlocProvider(
            create: (_) => PortfolioBloc(),
            child: PortfolioPage(onSearchTap: _onSearchTap, onProfileTap: _onProfileTap),
          ),
      3 => BlocProvider(
            create: (_) => OrdersBloc(),
            child: OrdersPage(onSearchTap: _onSearchTap, onProfileTap: _onProfileTap),
          ),
      4 => MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => ProfileBloc()),
              BlocProvider(create: (_) => PortfolioBloc()),
            ],
            child: const ProfilePage(),
          ),
      _ => const SizedBox(),
    };
  }

  @override
  Widget build(BuildContext context) {
    AppResponsive.init(context);
    final p = AppPalette.of(context);
    if (_pages[_index] == null) {
      _pages[_index] = _pageForIndex(_index);
    }
    final pages = List<Widget>.generate(5, (i) => _pages[i] ?? const SizedBox());
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppTopBar(
        title: _title,
        onSearchTap: _index == 4 ? null : _onSearchTap,
        onProfileTap: _index == 4 ? null : _onProfileTap,
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: NeonBackdrop()),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: KeyedSubtree(
              key: ValueKey(_index),
              child: IndexedStack(index: _index, children: pages),
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomBar(
        currentIndex: _index,
        onTap: (i) => setState(() {
          _index = i;
          if (_pages[i] == null) {
            _pages[i] = _pageForIndex(i);
          }
        }),
      ),
    );
  }
}

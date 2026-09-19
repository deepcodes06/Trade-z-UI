import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'backend/api/market_api.dart';
import 'backend/bloc/auth/auth_bloc.dart';
import 'backend/bloc/auth/auth_state.dart';
import 'backend/bloc/watchlist/watchlist_bloc.dart';
import 'backend/services/notification_service.dart';
import 'constants/app_theme.dart';
import 'screens/auth/login_page.dart';
import 'screens/splash/splash_screen.dart';
import 'widgets/main_scaffold.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MarketApi.instance.logStartupStatus();
  await NotificationService.instance.init();
  runApp(const TradeZApp());
}

class TradeZApp extends StatelessWidget {
  const TradeZApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AuthBloc()),
        // App-level so pushed routes (e.g. StockDetailPage's "Watchlist" quick
        // action) can add/remove symbols no matter which tab they came from
        // — the watchlist tab's own provider would not be in scope above the
        // Navigator once a detail page is pushed on top.
        BlocProvider(create: (_) => WatchlistBloc()),
      ],
      child: MaterialApp(
        title: 'TradeZ',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.light,
        theme: AppTheme.light,
        home: const _RootGate(),
      ),
    );
  }
}

class _RootGate extends StatefulWidget {
  const _RootGate();

  @override
  State<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<_RootGate> {
  bool _splashDone = false;

  @override
  Widget build(BuildContext context) {
    if (!_splashDone) {
      return SplashScreen(onFinished: () {
        if (mounted) setState(() => _splashDone = true);
      });
    }
    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (a, b) => a.status != b.status,
      builder: (context, state) {
        switch (state.status) {
          case AuthStatus.authenticated:
            return const MainScaffold();
          case AuthStatus.unauthenticated:
            return const LoginPage();
          case AuthStatus.unknown:
            // Still restoring the session — show a loading screen (we never
            // want to flash the login page while we're checking for a token).
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFF1743A3)),
              ),
            );
        }
      },
    );
  }
}

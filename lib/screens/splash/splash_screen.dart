import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_responsive.dart';
import '../../constants/app_strings.dart';
import '../../widgets/neon_backdrop.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onFinished;
  const SplashScreen({super.key, required this.onFinished});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _scale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _controller.forward();
    Future.delayed(const Duration(milliseconds: 1800), widget.onFinished);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Scaffold(
      backgroundColor: p.background,
      body: Stack(
        children: [
          const Positioned.fill(child: NeonBackdrop()),
          Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: AppResponsive.w(100),
                  height: AppResponsive.w(100),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: p.softHighlight,
                    border: Border.all(color: p.primary.withValues(alpha: 0.25), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0x0F1E2D3C),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.all(AppResponsive.w(20)),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
                SizedBox(height: AppResponsive.h(24)),
                Text(
                  AppStrings.appName,
                  style: GoogleFonts.spaceGrotesk(
                    color: p.textPrimary,
                    fontSize: AppResponsive.font(32),
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: AppResponsive.h(6)),
                Text(
                  AppStrings.tagline,
                  style: GoogleFonts.inter(
                    color: p.accent,
                    fontSize: AppResponsive.font(13),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          ),
          ),
        ],
      ),
    );
  }
}

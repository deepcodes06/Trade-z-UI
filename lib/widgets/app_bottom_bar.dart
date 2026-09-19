import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../constants/app_responsive.dart';
import '../constants/app_strings.dart';

class AppBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomBar({super.key, required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final items = const [
      _NavItem(icon: Icons.show_chart, label: AppStrings.home),
      _NavItem(icon: Icons.bookmark_outline, label: AppStrings.watchlist),
      _NavItem(icon: Icons.account_balance_wallet_outlined, label: AppStrings.portfolio),
      _NavItem(icon: Icons.swap_horiz, label: AppStrings.orders),
      _NavItem(icon: Icons.person_outline, label: AppStrings.profile),
    ];
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: p.bottomBar,
            border: const Border(
              top: BorderSide(color: Color(0x1FFFFFFF), width: 1),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: AppResponsive.h(66),
              child: Row(
                children: List.generate(items.length, (i) {
                  final selected = i == currentIndex;
                  final item = items[i];
                  return Expanded(
                    child: InkWell(
                      onTap: () => onTap(i),
                      borderRadius: BorderRadius.circular(AppResponsive.w(14)),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppResponsive.w(6),
                          vertical: AppResponsive.h(6),
                        ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                          decoration: BoxDecoration(
                            color: selected
                                ? p.softHighlight
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(AppResponsive.w(14)),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                item.icon,
                                size: AppResponsive.w(22),
                                color: selected ? p.accent : p.textMuted,
                              ),
                              SizedBox(height: AppResponsive.h(2)),
                              Text(
                                item.label,
                                style: GoogleFonts.inter(
                                  fontSize: AppResponsive.font(11),
                                  color: selected ? p.accent : p.textMuted,
                                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

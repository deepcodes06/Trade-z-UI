import 'dart:ui';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_responsive.dart';

class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onSearchTap;
  final VoidCallback? onProfileTap;
  final String title;
  final bool showBack;
  final VoidCallback? onBack;

  const AppTopBar({
    super.key,
    required this.title,
    this.onSearchTap,
    this.onProfileTap,
    this.showBack = false,
    this.onBack,
  });

  @override
  Size get preferredSize => Size.fromHeight(AppResponsive.h(60));

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: AppBar(
          backgroundColor: p.topBar,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          automaticallyImplyLeading: false,
          leading: showBack
              ? IconButton(
                  icon: Icon(Icons.arrow_back, color: p.textPrimary),
                  onPressed: onBack,
                )
              : null,
          titleSpacing: 0,
          title: Padding(
            padding: EdgeInsets.symmetric(horizontal: AppResponsive.w(4)),
            child: Row(
              children: [
                if (!showBack)
                  _IconChip(icon: Icons.search, onTap: onSearchTap, palette: p),
                SizedBox(width: AppResponsive.w(8)),
                Expanded(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: p.textPrimary,
                      fontSize: AppResponsive.font(18),
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                _IconChip(icon: Icons.person_outline, onTap: onProfileTap, palette: p),
                SizedBox(width: AppResponsive.w(6)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IconChip extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final AppPalette palette;
  const _IconChip({required this.icon, required this.onTap, required this.palette});

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      radius: AppResponsive.w(22),
      onTap: onTap,
      child: Container(
        width: AppResponsive.w(38),
        height: AppResponsive.w(38),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0x331743A3),
          borderRadius: BorderRadius.circular(AppResponsive.w(12)),
          border: Border.all(color: palette.border, width: 1),
        ),
        child: Icon(icon, size: AppResponsive.w(18), color: palette.icon),
      ),
    );
  }
}

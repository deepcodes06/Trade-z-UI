import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// TradeZ color system — single light theme.
///
/// Premium fintech aesthetic: **Trade-Z Blue (#1743A3)** on a flat matte
/// (#F3F6F8) background with frosted translucent-glass cards. All depth comes
/// from translucency, backdrop blur and ultra-soft shadows — no gradients.
///
/// All UI code reads semantic tokens from the active [AppPalette].
class AppColors {
  AppColors._();

  static const Color tradeZBlue = Color(0xFF1743A3);
  static const Color tradeZBlueLight = Color(0xFF3B5BDB);
  static const Color softBlueHighlight = Color(0xFFE8F0FF);
}

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color card;
  final Color topBar;
  final Color bottomBar;
  final Color border;
  final Color divider;
  final Color primary;
  final Color onPrimary;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textInverse;
  final Color gain;
  final Color loss;
  final Color warning;
  final Color icon;
  final Color scrim;
  final Color glow;
  final Color softHighlight;

  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.card,
    required this.topBar,
    required this.bottomBar,
    required this.border,
    required this.divider,
    required this.primary,
    required this.onPrimary,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textInverse,
    required this.gain,
    required this.loss,
    required this.warning,
    required this.icon,
    required this.scrim,
    required this.glow,
    required this.softHighlight,
  });

  /// Single palette — dark neon glass.
  ///
  /// Near-black matte background (#05070B) with dark translucent frosted-glass
  /// surfaces on top. Soft neon light blobs sit behind the cards and bleed
  /// through the glass via BackdropFilter. No gradients, no opaque cards.
  static const AppPalette light = AppPalette(
    background: Color(0xFF05070B),
    surface: Color(0xFF151A22),
    surfaceAlt: Color(0xFF1D2530),
    card: Color(0x66151A22), // semi-transparent dark glass
    topBar: Color(0x99151A22),
    bottomBar: Color(0x99151A22),
    border: Color(0x1FFFFFFF), // rgba(255,255,255,0.12)
    divider: Color(0x14FFFFFF),
    primary: Color(0xFF1743A3), // Trade-Z accent
    onPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFF38BDF8), // electric cyan highlight
    textPrimary: Color(0xFFF3F6FA),
    textSecondary: Color(0xFFB4Bcc8),
    textMuted: Color(0xFF7A8494),
    textInverse: Color(0xFF05070B),
    gain: Color(0xFF3DDC84),
    loss: Color(0xFFFF4D67),
    warning: Color(0xFFFBBF24),
    icon: Color(0xFFCFD6E0),
    scrim: Color(0x99000000),
    glow: Color(0x331743A3),
    softHighlight: Color(0x331743A3),
  );

  static AppPalette of(BuildContext context) {
    final ext = Theme.of(context).extension<AppPalette>();
    return ext ?? AppPalette.light;
  }

  @override
  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? card,
    Color? topBar,
    Color? bottomBar,
    Color? border,
    Color? divider,
    Color? primary,
    Color? onPrimary,
    Color? accent,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? textInverse,
    Color? gain,
    Color? loss,
    Color? warning,
    Color? icon,
    Color? scrim,
    Color? glow,
    Color? softHighlight,
  }) {
    return AppPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      card: card ?? this.card,
      topBar: topBar ?? this.topBar,
      bottomBar: bottomBar ?? this.bottomBar,
      border: border ?? this.border,
      divider: divider ?? this.divider,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      accent: accent ?? this.accent,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      textInverse: textInverse ?? this.textInverse,
      gain: gain ?? this.gain,
      loss: loss ?? this.loss,
      warning: warning ?? this.warning,
      icon: icon ?? this.icon,
      scrim: scrim ?? this.scrim,
      glow: glow ?? this.glow,
      softHighlight: softHighlight ?? this.softHighlight,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      card: Color.lerp(card, other.card, t)!,
      topBar: Color.lerp(topBar, other.topBar, t)!,
      bottomBar: Color.lerp(bottomBar, other.bottomBar, t)!,
      border: Color.lerp(border, other.border, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textInverse: Color.lerp(textInverse, other.textInverse, t)!,
      gain: Color.lerp(gain, other.gain, t)!,
      loss: Color.lerp(loss, other.loss, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      icon: Color.lerp(icon, other.icon, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
      glow: Color.lerp(glow, other.glow, t)!,
      softHighlight: Color.lerp(softHighlight, other.softHighlight, t)!,
    );
  }
}

/// Dark frosted-glass card decoration.
///
/// Translucent dark glass floating over a near-black background. Neon light
/// blobs painted behind the cards are visibly blurred and softened through
/// the glass by a [BackdropFilter]. No gradients, no opaque surfaces.
class GlassCard {
  GlassCard._();

  static const Color _glass = Color(0x66151A22); // semi-transparent dark surface
  static const Color _glassSoft = Color(0x55161C25); // lighter small tiles
  static const Color _border = Color(0x1FFFFFFF); // rgba(255,255,255,0.12)
  static const Color _highlight = Color(0x14FFFFFF); // rgba(255,255,255,0.08)
  static const Color _shadow = Color(0x66000000); // extremely soft dark shadow

  /// Wraps [child] in a dark frosted-glass surface: translucent dark fill +
  /// backdrop blur + soft shadow + thin rgba(255,255,255,0.12) border +
  /// 20–24px radius. This is the primary "big card" surface.
  static Widget blur({
    required Widget child,
    double radius = 24,
    double sigma = 24,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    Color? color,
    Color? borderColor,
  }) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? _glass,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? _border, width: 1),
        boxShadow: [
          BoxShadow(
            color: _shadow,
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                child: const SizedBox.shrink(),
              ),
            ),
            Padding(
              padding: padding ?? EdgeInsets.zero,
              child: child,
            ),
          ],
        ),
      ),
    );
  }

  /// Standard non-blurred dark glass card — used where the surrounding surface
  /// already carries a blur (inside blurred bars, dialogs, etc.).
  static BoxDecoration of(BuildContext context, {Color? borderColor, double radius = 20}) {
    return BoxDecoration(
      color: _glass,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? _border, width: 1),
      boxShadow: [
        BoxShadow(
          color: _shadow,
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
        BoxShadow(color: _highlight, blurRadius: 0, offset: const Offset(0, -1)),
      ],
    );
  }

  /// Flat variant — no shadow, used for nested/secondary cards.
  static BoxDecoration flat({Color? borderColor, double radius = 16}) {
    return BoxDecoration(
      color: _glassSoft,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? _border, width: 1),
    );
  }

  /// Elevated variant — slightly stronger shadow for summary headers.
  static BoxDecoration elevated({double radius = 20}) {
    return BoxDecoration(
      color: _glass,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: _border, width: 1),
      boxShadow: [
        BoxShadow(
          color: Color(0x73000000), // rgba(0,0,0,0.45)
          blurRadius: 30,
          offset: const Offset(0, 12),
        ),
        BoxShadow(color: _highlight, blurRadius: 0, offset: const Offset(0, -1)),
      ],
    );
  }
}

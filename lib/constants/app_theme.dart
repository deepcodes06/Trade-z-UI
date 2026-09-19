import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static TextTheme _baseTextTheme(Color textPrimary, Color textSecondary) {
    final display = GoogleFonts.spaceGroteskTextTheme();
    final body = GoogleFonts.interTextTheme();
    return TextTheme(
      displayLarge: display.displayLarge?.copyWith(color: textPrimary, fontWeight: FontWeight.w700),
      displayMedium: display.displayMedium?.copyWith(color: textPrimary, fontWeight: FontWeight.w700),
      displaySmall: display.displaySmall?.copyWith(color: textPrimary, fontWeight: FontWeight.w700),
      headlineLarge: display.headlineLarge?.copyWith(color: textPrimary, fontWeight: FontWeight.w700),
      headlineMedium: display.headlineMedium?.copyWith(color: textPrimary, fontWeight: FontWeight.w700),
      headlineSmall: display.headlineSmall?.copyWith(color: textPrimary, fontWeight: FontWeight.w700),
      titleLarge: body.titleLarge?.copyWith(color: textPrimary, fontWeight: FontWeight.w700),
      titleMedium: body.titleMedium?.copyWith(color: textPrimary, fontWeight: FontWeight.w600),
      titleSmall: body.titleSmall?.copyWith(color: textPrimary, fontWeight: FontWeight.w600),
      bodyLarge: body.bodyLarge?.copyWith(color: textPrimary, fontWeight: FontWeight.w500),
      bodyMedium: body.bodyMedium?.copyWith(color: textPrimary, fontWeight: FontWeight.w500),
      bodySmall: body.bodySmall?.copyWith(color: textSecondary, fontWeight: FontWeight.w500),
      labelLarge: body.labelLarge?.copyWith(color: textPrimary, fontWeight: FontWeight.w600),
      labelMedium: body.labelMedium?.copyWith(color: textSecondary, fontWeight: FontWeight.w600),
      labelSmall: body.labelSmall?.copyWith(color: textSecondary, fontWeight: FontWeight.w600, letterSpacing: 0.6),
    );
  }

  static ThemeData build() {
    const p = AppPalette.light;
    final textTheme = _baseTextTheme(p.textPrimary, p.textSecondary);

    final colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: p.primary,
      onPrimary: p.onPrimary,
      secondary: p.accent,
      onSecondary: p.textInverse,
      error: p.loss,
      onError: p.onPrimary,
      surface: p.surface,
      onSurface: p.textPrimary,
      surfaceContainerHighest: p.surfaceAlt,
      onSurfaceVariant: p.textSecondary,
      outline: p.border,
      outlineVariant: p.divider,
      primaryContainer: p.softHighlight,
      onPrimaryContainer: p.primary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: p.background,
      primaryColor: p.primary,
      colorScheme: colorScheme,
      canvasColor: p.background,
      dividerColor: p.divider,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      extensions: <ThemeExtension<dynamic>>[p],
      textTheme: textTheme,
      fontFamily: GoogleFonts.inter().fontFamily,
      appBarTheme: AppBarTheme(
        backgroundColor: p.topBar,
        foregroundColor: p.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.spaceGrotesk(
          color: p.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: p.icon),
        actionsIconTheme: IconThemeData(color: p.icon),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: p.bottomBar,
        selectedItemColor: p.primary,
        unselectedItemColor: p.textMuted,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: p.border, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.spaceGrotesk(
          color: p.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: GoogleFonts.inter(
          color: p.textSecondary,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        elevation: 16,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        elevation: 12,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.textPrimary,
        contentTextStyle: GoogleFonts.inter(
          color: p.surface,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0x66151A22), // translucent dark glass fill
        hintStyle: GoogleFonts.inter(color: p.textMuted, fontSize: 14, fontWeight: FontWeight.w500),
        labelStyle: GoogleFonts.inter(color: p.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0x1FFFFFFF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0x1FFFFFFF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          shadowColor: p.primary.withValues(alpha: 0.20),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.accent,
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: p.icon),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? p.onPrimary : p.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? p.primary : p.border,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.primary),
      dividerTheme: DividerThemeData(color: p.divider, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(
        iconColor: p.icon,
        textColor: p.textPrimary,
      ),
    );
  }

  static ThemeData get light => build();
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Central color + typography definitions for SoulTalk AI.
/// Calm soft-blue and pastel-purple wellness palette.
class AppColors {
  AppColors._();

  static const Color background = Color(0xFFF3F5FB);
  static const Color foreground = Color(0xFF36405C);
  static const Color card = Color(0xFFFFFFFF);

  static const Color primary = Color(0xFF6E8BD6); // soft blue
  static const Color primaryDark = Color(0xFF5871C0);
  static const Color onPrimary = Color(0xFFFDFEFF);

  static const Color accent = Color(0xFFCBB6E6); // pastel purple
  static const Color accentSoft = Color(0xFFEDE6F7);
  static const Color accentForeground = Color(0xFF4A3670);

  static const Color secondary = Color(0xFFEDEFF9);
  static const Color muted = Color(0xFFF1F3FA);
  static const Color mutedForeground = Color(0xFF8089A3);

  static const Color border = Color(0xFFE6E9F2);
  static const Color destructive = Color(0xFFE0635F);
  static const Color success = Color(0xFF7BC4A4);

  // Chart / mood colors
  static const Color chart4 = Color(0xFF7BC4A4); // green – Calm
  static const Color chart5 = Color(0xFFD4A84B); // amber – Thinking

  // Mood spectrum
  static const Color moodGreat = Color(0xFF7BC4A4);
  static const Color moodGood = Color(0xFF8BB6E6);
  static const Color moodOkay = Color(0xFFE6C77B);
  static const Color moodLow = Color(0xFFE6A07B);
  static const Color moodRough = Color(0xFFE0635F);
}

class AppTheme {
  AppTheme._();

  static const double radius = 16.0;

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);

    final textTheme = GoogleFonts.nunitoTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.quicksand(fontWeight: FontWeight.w700, color: AppColors.foreground),
      displayMedium: GoogleFonts.quicksand(fontWeight: FontWeight.w700, color: AppColors.foreground),
      displaySmall: GoogleFonts.quicksand(fontWeight: FontWeight.w700, color: AppColors.foreground),
      headlineMedium: GoogleFonts.quicksand(fontWeight: FontWeight.w700, color: AppColors.foreground),
      headlineSmall: GoogleFonts.quicksand(fontWeight: FontWeight.w700, color: AppColors.foreground),
      titleLarge: GoogleFonts.quicksand(fontWeight: FontWeight.w700, color: AppColors.foreground),
      titleMedium: GoogleFonts.quicksand(fontWeight: FontWeight.w600, color: AppColors.foreground),
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        secondary: AppColors.accent,
        onSecondary: AppColors.foreground,
        surface: AppColors.card,
        onSurface: AppColors.foreground,
        error: AppColors.destructive,
        outline: AppColors.border,
      ),
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.foreground,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          elevation: 0,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
          textStyle: GoogleFonts.quicksand(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.muted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        hintStyle: const TextStyle(color: AppColors.mutedForeground),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(radius), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(radius), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(radius), borderSide: const BorderSide(color: AppColors.primary, width: 1.6)),
      ),
    );
  }

  static ThemeData dark() {
    const darkBg       = Color(0xFF0F1117);
    const darkSurface  = Color(0xFF1A1D27);
    const darkCard     = Color(0xFF1E2130);
    const darkBorder   = Color(0xFF2A2E40);
    const darkFg       = Color(0xFFE8EAF2);
    const darkMuted    = Color(0xFF6B7280);

    final base = ThemeData.dark(useMaterial3: true);

    final textTheme = GoogleFonts.nunitoTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.quicksand(fontWeight: FontWeight.w700, color: darkFg),
      displayMedium: GoogleFonts.quicksand(fontWeight: FontWeight.w700, color: darkFg),
      displaySmall: GoogleFonts.quicksand(fontWeight: FontWeight.w700, color: darkFg),
      headlineMedium: GoogleFonts.quicksand(fontWeight: FontWeight.w700, color: darkFg),
      headlineSmall: GoogleFonts.quicksand(fontWeight: FontWeight.w700, color: darkFg),
      titleLarge: GoogleFonts.quicksand(fontWeight: FontWeight.w700, color: darkFg),
      titleMedium: GoogleFonts.quicksand(fontWeight: FontWeight.w600, color: darkFg),
    );

    return base.copyWith(
      scaffoldBackgroundColor: darkBg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.accent,
        onSecondary: darkFg,
        surface: darkCard,
        onSurface: darkFg,
        error: AppColors.destructive,
        outline: darkBorder,
      ),
      textTheme: textTheme,
      cardColor: darkCard,
      dividerColor: darkBorder,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: darkFg,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
          textStyle: GoogleFonts.quicksand(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        hintStyle: const TextStyle(color: darkMuted),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(radius), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(radius), borderSide: const BorderSide(color: darkBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(radius), borderSide: const BorderSide(color: AppColors.primary, width: 1.6)),
      ),
    );
  }
}

/// Soft elevation used across cards for the calm, premium look.
class SoftShadow {
  static List<BoxShadow> get card => [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.03),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get soft => [
        BoxShadow(
          color: AppColors.foreground.withValues(alpha: 0.02),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ];
}

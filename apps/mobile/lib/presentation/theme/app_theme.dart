import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  static const _lightBackground = Color(0xFFFFFFFF);
  static const _lightSurface = Color(0xFFF5F5F7);
  static const _lightSurfaceElevated = Color(0xFFFFFFFF);
  static const _lightTextPrimary = Color(0xFF000000);
  static const _lightTextSecondary = Color(0xFF86868B);
  static const _lightTextTertiary = Color(0xFFAEAEB2);
  static const _lightDivider = Color(0xFFE5E5EA);

  static const _darkBackground = Color(0xFF000000);
  static const _darkSurface = Color(0xFF1C1C1E);
  static const _darkSurfaceElevated = Color(0xFF2C2C2E);
  static const _darkTextPrimary = Color(0xFFFFFFFF);
  static const _darkTextSecondary = Color(0xFF8E8E93);
  static const _darkTextTertiary = Color(0xFF636366);
  static const _darkDivider = Color(0xFF38383A);

  static const accent = Color(0xFF007AFF);
  static const destructive = Color(0xFFFF3B30);

  static TextTheme _buildTextTheme(TextTheme base) {
    return base.copyWith(
      displayLarge: GoogleFonts.dmSans(
        fontSize: 34,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
      ),
      displayMedium: GoogleFonts.dmSans(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
      ),
      displaySmall: GoogleFonts.dmSans(
        fontSize: 22,
        fontWeight: FontWeight.bold,
      ),
      headlineMedium: GoogleFonts.dmSans(
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      headlineSmall: GoogleFonts.dmSans(
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: GoogleFonts.dmSans(fontSize: 17, fontWeight: FontWeight.w600),
      titleMedium: GoogleFonts.dmSans(
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      bodyLarge: GoogleFonts.dmSans(
        fontSize: 17,
        fontWeight: FontWeight.normal,
      ),
      bodyMedium: GoogleFonts.dmSans(
        fontSize: 15,
        fontWeight: FontWeight.normal,
      ),
      bodySmall: GoogleFonts.dmSans(
        fontSize: 13,
        fontWeight: FontWeight.normal,
      ),
      labelLarge: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w500),
      labelSmall: GoogleFonts.dmSans(
        fontSize: 11,
        fontWeight: FontWeight.normal,
      ),
    );
  }

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: _darkBackground,
    colorScheme: const ColorScheme.dark(
      primary: accent,
      secondary: accent,
      surface: _darkSurface,
      surfaceContainerHighest: _darkSurfaceElevated,
      onSurface: _darkTextPrimary,
      onSurfaceVariant: _darkTextSecondary,
      outline: _darkDivider,
      error: destructive,
    ),
    textTheme: _buildTextTheme(
      ThemeData.dark().textTheme,
    ).apply(bodyColor: _darkTextPrimary, displayColor: _darkTextPrimary),
    appBarTheme: const AppBarTheme(
      backgroundColor: _darkBackground,
      foregroundColor: _darkTextPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
    ),
    cardTheme: CardThemeData(
      color: _darkSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: EdgeInsets.zero,
    ),
    dividerTheme: const DividerThemeData(
      color: _darkDivider,
      thickness: 0.5,
      space: 0,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: _darkSurface,
      modalBackgroundColor: _darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.transparent,
      side: BorderSide(color: _darkDivider),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      labelStyle: GoogleFonts.inter(fontSize: 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _darkSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      hintStyle: GoogleFonts.dmSans(fontSize: 16, color: _darkTextSecondary),
    ),
    cupertinoOverrideTheme: const CupertinoThemeData(
      brightness: Brightness.dark,
      primaryColor: accent,
    ),
  );

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: _lightBackground,
    colorScheme: const ColorScheme.light(
      primary: accent,
      secondary: accent,
      surface: _lightSurface,
      surfaceContainerHighest: _lightSurfaceElevated,
      onSurface: _lightTextPrimary,
      onSurfaceVariant: _lightTextSecondary,
      outline: _lightDivider,
      error: destructive,
    ),
    textTheme: _buildTextTheme(
      ThemeData.light().textTheme,
    ).apply(bodyColor: _lightTextPrimary, displayColor: _lightTextPrimary),
    appBarTheme: const AppBarTheme(
      backgroundColor: _lightBackground,
      foregroundColor: _lightTextPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
    ),
    cardTheme: CardThemeData(
      color: _lightSurfaceElevated,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: EdgeInsets.zero,
    ),
    dividerTheme: const DividerThemeData(
      color: _lightDivider,
      thickness: 0.5,
      space: 0,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: _lightSurfaceElevated,
      modalBackgroundColor: _lightSurfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.transparent,
      side: BorderSide(color: _lightDivider),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      labelStyle: GoogleFonts.inter(fontSize: 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _lightSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      hintStyle: GoogleFonts.dmSans(fontSize: 16, color: _lightTextSecondary),
    ),
    cupertinoOverrideTheme: const CupertinoThemeData(
      brightness: Brightness.light,
      primaryColor: accent,
    ),
  );
}

extension AppColors on BuildContext {
  Color get textSecondary => Theme.of(this).colorScheme.onSurfaceVariant;
  Color get textTertiary => Theme.of(this).brightness == Brightness.dark
      ? const Color(0xFF636366)
      : const Color(0xFFAEAEB2);
  Color get divider => Theme.of(this).colorScheme.outline;
  Color get surfaceElevated =>
      Theme.of(this).colorScheme.surfaceContainerHighest;
}

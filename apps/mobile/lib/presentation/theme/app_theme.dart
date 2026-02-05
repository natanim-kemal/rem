import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  static const _lightBackground = Color(0xFFF8F7F4);
  static const _lightSurface = Color(0xFFFFFFFF);
  static const _lightSurfaceElevated = Color(0xFFF2F2EF);
  static const _lightTextPrimary = Color(0xFF1E1E1E);
  static const _lightTextSecondary = Color(0xFF6E6E6E);
  static const _lightTextTertiary = Color(0xFF9A9A9A);
  static const _lightDivider = Color(0xFFE5E3DE);

  static const _darkBackground = Color(0xFF1F1F1F);
  static const _darkSurface = Color(0xFF262626);
  static const _darkSurfaceElevated = Color(0xFF2B2B2B);
  static const _darkTextPrimary = Color(0xFFF2F2F2);
  static const _darkTextSecondary = Color(0xFFB0B0B0);
  static const _darkTextTertiary = Color(0xFF7A7A7A);
  static const _darkDivider = Color(0xFF2F2F2F);

  static const accent = Color(0xFF2FBF9A);
  static const destructive = Color(0xFFFF3B30);

  static TextTheme _buildTextTheme(TextTheme base) {
    return GoogleFonts.geistTextTheme(base).copyWith(
      displayLarge: GoogleFonts.geist(
        fontSize: 34,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
      ),
      displayMedium: GoogleFonts.geist(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
      ),
      displaySmall: GoogleFonts.geist(
        fontSize: 22,
        fontWeight: FontWeight.bold,
      ),
      headlineMedium: GoogleFonts.geist(
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      headlineSmall: GoogleFonts.geist(
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: GoogleFonts.geist(fontSize: 17, fontWeight: FontWeight.w600),
      titleMedium: GoogleFonts.geist(fontSize: 16, fontWeight: FontWeight.w500),
      bodyLarge: GoogleFonts.geist(fontSize: 17, fontWeight: FontWeight.normal),
      bodyMedium: GoogleFonts.geist(
        fontSize: 15,
        fontWeight: FontWeight.normal,
      ),
      bodySmall: GoogleFonts.geist(fontSize: 13, fontWeight: FontWeight.normal),
      labelLarge: GoogleFonts.geist(fontSize: 14, fontWeight: FontWeight.w500),
      labelSmall: GoogleFonts.geist(
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
      labelStyle: GoogleFonts.geist(fontSize: 14),
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
      hintStyle: GoogleFonts.geist(fontSize: 16, color: _darkTextSecondary),
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
      labelStyle: GoogleFonts.geist(fontSize: 14),
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
      hintStyle: GoogleFonts.geist(fontSize: 16, color: _lightTextSecondary),
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
      ? AppTheme._darkTextTertiary
      : AppTheme._lightTextTertiary;
  Color get divider => Theme.of(this).colorScheme.outline;
  Color get surfaceElevated =>
      Theme.of(this).colorScheme.surfaceContainerHighest;
}

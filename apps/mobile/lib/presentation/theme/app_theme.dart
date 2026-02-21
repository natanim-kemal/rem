import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  static const _lightBackground = Color(0xFFFDFCFA);
  static const _lightSurface = Color(0xFFFFFFFF);
  static const _lightSurfaceElevated = Color(0xFFF2F2EF);
  static const _lightTextPrimary = Color(0xFF1E1E1E);
  static const _lightTextSecondary = Color(0xFF6E6E6E);
  static const _lightTextTertiary = Color(0xFF9A9A9A);
  static const _lightDivider = Color(0xFFE5E3DE);

  static const _darkBackground = Color(0xFF0F0F0F);
  static const _darkSurface = Color(0xFF141414);
  static const _darkSurfaceElevated = Color(0xFF1A1A1A);
  static const _darkTextPrimary = Color(0xFFC8C8C8);
  static const _darkTextSecondary = Color(0xFF707070);
  static const _darkTextTertiary = Color(0xFF505050);
  static const _darkDivider = Color(0xFF181818);

  static const accent = Color(0xFF2FBF9A);
  static const destructive = Color(0xFF1A8A6E);

  static TextTheme _buildTextTheme(TextTheme base, Color textColor) {
    final geistTheme = GoogleFonts.dmSansTextTheme(base);

    return geistTheme.copyWith(
      displayLarge: geistTheme.displayLarge?.copyWith(
        fontSize: 34,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
        color: textColor,
      ),
      displayMedium: geistTheme.displayMedium?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
        color: textColor,
      ),
      displaySmall: geistTheme.displaySmall?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
      headlineMedium: geistTheme.headlineMedium?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      headlineSmall: geistTheme.headlineSmall?.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      titleLarge: geistTheme.titleLarge?.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      titleMedium: geistTheme.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: textColor,
      ),
      titleSmall: geistTheme.titleSmall?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textColor,
      ),
      bodyLarge: geistTheme.bodyLarge?.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.normal,
        color: textColor,
      ),
      bodyMedium: geistTheme.bodyMedium?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.normal,
        color: textColor,
      ),
      bodySmall: geistTheme.bodySmall?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.normal,
        color: textColor,
      ),
      labelLarge: geistTheme.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textColor,
      ),
      labelMedium: geistTheme.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: textColor,
      ),
      labelSmall: geistTheme.labelSmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.normal,
        color: textColor,
      ),
    );
  }

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: _darkBackground,
    fontFamily: 'Lora',
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
    textTheme: _buildTextTheme(ThemeData.dark().textTheme, _darkTextPrimary),
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
      labelStyle: const TextStyle(fontSize: 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _darkSurfaceElevated,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      hintStyle: TextStyle(fontSize: 16, color: _darkTextSecondary),
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
    fontFamily: 'Lora',
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
    textTheme: _buildTextTheme(ThemeData.light().textTheme, _lightTextPrimary),
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
      labelStyle: const TextStyle(fontSize: 14),
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
      hintStyle: TextStyle(fontSize: 16, color: _lightTextSecondary),
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

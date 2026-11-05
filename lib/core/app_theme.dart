import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppPalette {
  final String name;
  final Color background;
  final Color surface;
  final Color primary;
  final Color secondary;

  const AppPalette({
    required this.name,
    required this.background,
    required this.surface,
    required this.primary,
    required this.secondary,
  });
}

class AppTheme {
  static const List<AppPalette> palettes = [
    AppPalette(
      name: 'Butter & Wood',
      background: Color(0xFFFFF1C3), // Butter yellow
      surface: Color(0xFFF4D5BF), // Pinky beige
      primary: Color(0xFF4A260F), // Warm wood
      secondary: Color(0xFF8C512B),
    ),
    AppPalette(
      name: 'Soft Sage',
      background: Color(0xFFEBF2EA),
      surface: Color(0xFFD3E2D0),
      primary: Color(0xFF2C4A3E),
      secondary: Color(0xFF4F7A68),
    ),
    AppPalette(
      name: 'Rose Coral',
      background: Color(0xFFFAF0E6),
      surface: Color(0xFFFAD2E1),
      primary: Color(0xFF6B2D46),
      secondary: Color(0xFFA34862),
    ),
    AppPalette(
      name: 'Ocean Breeze',
      background: Color(0xFFEBF4F6),
      surface: Color(0xFFB9E5E8),
      primary: Color(0xFF1E4D58),
      secondary: Color(0xFF3B7A8C),
    ),
    AppPalette(
      name: 'Lavender Mist',
      background: Color(0xFFF5F3F7),
      surface: Color(0xFFE3DCED),
      primary: Color(0xFF42325E),
      secondary: Color(0xFF6B5196),
    ),
    AppPalette(
      name: 'Sunset Amber',
      background: Color(0xFFFFF8F0),
      surface: Color(0xFFFCE2CE),
      primary: Color(0xFF5C2C16),
      secondary: Color(0xFF9A4F2A),
    ),
  ];

  static ThemeData get light => buildTheme(brightness: Brightness.light);
  static ThemeData get dark => buildTheme(brightness: Brightness.dark);

  static ThemeData buildTheme({
    required Brightness brightness,
    int paletteIndex = 0,
  }) {
    final palette = palettes[
        (paletteIndex >= 0 && paletteIndex < palettes.length)
            ? paletteIndex
            : 0];
    final isDark = brightness == Brightness.dark;

    final backgroundColor =
        isDark ? const Color(0xFF1F1A17) : palette.background;
    final surfaceColor = isDark ? const Color(0xFF2E2723) : palette.surface;
    final primaryColor = isDark ? palette.surface : palette.primary;
    final textColor = isDark ? const Color(0xFFFFF1C3) : palette.primary;

    final textTheme = GoogleFonts.plusJakartaSansTextTheme().apply(
      bodyColor: textColor,
      displayColor: textColor,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: backgroundColor,
      primaryColor: primaryColor,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: primaryColor,
        onPrimary: isDark ? const Color(0xFF1F1A17) : Colors.white,
        secondary: palette.secondary,
        onSecondary: Colors.white,
        surface: surfaceColor,
        onSurface: textColor,
        error: AppColors.dustyCoral,
        onError: Colors.white,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundColor,
        foregroundColor: textColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textColor),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: textColor,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 1.5,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.18 : 0.07),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: primaryColor.withValues(alpha: isDark ? 0.22 : 0.08),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceColor,
        selectedColor: primaryColor,
        secondarySelectedColor: primaryColor,
        labelStyle: TextStyle(color: textColor, fontWeight: FontWeight.w600),
        secondaryLabelStyle:
            const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: primaryColor.withValues(alpha: 0.2)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? const Color(0xFF3B332F)
            : Colors.white.withValues(alpha: 0.85),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primaryColor.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primaryColor.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.dustyCoral),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.dustyCoral, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: isDark ? const Color(0xFF1F1A17) : Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: isDark ? const Color(0xFF1F1A17) : Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: BorderSide(color: primaryColor, width: 1.5),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

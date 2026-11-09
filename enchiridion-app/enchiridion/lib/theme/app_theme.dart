import 'package:flutter/material.dart';
import 'app_colors.dart';
import '../models/user_settings.dart' as models;

class AppTheme {
  static const _sepiaAccent = Color(0xFFB5651D);

  static ThemeData getTheme(models.ThemeMode themeMode) {
    switch (themeMode) {
      case models.ThemeMode.dark:
        return _darkTheme();
      case models.ThemeMode.sepia:
        return _sepiaTheme();
      case models.ThemeMode.light:
        return _lightTheme();
    }
  }

  static ThemeData _lightTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.brandPink,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.brandPink,
      secondary: AppColors.neonTeal,
      surface: AppColors.paper,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.inkCharcoal,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.paper,
      appBarTheme: const AppBarThemeData(
        backgroundColor: AppColors.paper,
        foregroundColor: AppColors.inkCharcoal,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.brandPink),
      ),
      iconTheme: const IconThemeData(color: AppColors.brandPink),
      dividerColor: AppColors.frost,
      elevatedButtonTheme: _elevatedButtonTheme(),
      sliderTheme: _sliderTheme(AppColors.brandPink),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: AppColors.inkCharcoal),
        bodyMedium: TextStyle(color: AppColors.inkCharcoal),
        bodySmall: TextStyle(color: AppColors.inkCharcoal),
        titleLarge: TextStyle(color: AppColors.deepSpace),
        titleMedium: TextStyle(color: AppColors.deepSpace),
        titleSmall: TextStyle(color: AppColors.deepSpace),
      ),
    );
  }

  static ThemeData _darkTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.neonTeal,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.neonTeal,
      secondary: AppColors.brandPink,
      surface: AppColors.obsidian,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.frost,
      surfaceTint: Colors.transparent,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.deepSpace,
      appBarTheme: const AppBarThemeData(
        backgroundColor: AppColors.deepSpace,
        foregroundColor: AppColors.frost,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.brandPink),
      ),
      iconTheme: const IconThemeData(color: AppColors.neonTeal),
      dividerColor: AppColors.inkCharcoal,
      elevatedButtonTheme: _elevatedButtonTheme(),
      sliderTheme: _sliderTheme(AppColors.brandPink),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: AppColors.frost),
        bodyMedium: TextStyle(color: AppColors.frost),
        bodySmall: TextStyle(color: AppColors.frost),
        titleLarge: TextStyle(color: Colors.white),
        titleMedium: TextStyle(color: Colors.white),
        titleSmall: TextStyle(color: Colors.white),
      ),
    );
  }

  static ThemeData _sepiaTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _sepiaAccent,
      brightness: Brightness.light,
    ).copyWith(
      primary: _sepiaAccent,
      secondary: const Color(0xFFD4956A),
      surface: AppColors.sepiaBackground,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.sepiaText,
      surfaceTint: Colors.transparent,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.sepiaBackground,
      appBarTheme: const AppBarThemeData(
        backgroundColor: AppColors.sepiaBackground,
        foregroundColor: AppColors.sepiaText,
        elevation: 0,
        iconTheme: IconThemeData(color: _sepiaAccent),
      ),
      iconTheme: const IconThemeData(color: _sepiaAccent),
      dividerColor: AppColors.sepiaBorder,
      elevatedButtonTheme: _elevatedButtonTheme(color: _sepiaAccent),
      sliderTheme: _sliderTheme(_sepiaAccent),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: AppColors.sepiaText),
        bodyMedium: TextStyle(color: AppColors.sepiaText),
        bodySmall: TextStyle(color: AppColors.sepiaText),
        titleLarge: TextStyle(color: AppColors.sepiaText),
        titleMedium: TextStyle(color: AppColors.sepiaText),
        titleSmall: TextStyle(color: AppColors.sepiaText),
      ),
    );
  }

  static ElevatedButtonThemeData _elevatedButtonTheme({
    Color color = AppColors.brandPink,
  }) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
    );
  }

  static SliderThemeData _sliderTheme(Color color) {
    return SliderThemeData(
      activeTrackColor: color,
      thumbColor: color,
      inactiveTrackColor: color.withValues(alpha: 0.2),
      overlayColor: color.withValues(alpha: 0.12),
    );
  }
}

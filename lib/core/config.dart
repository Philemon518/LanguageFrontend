import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppConfig {
  static const _rawApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  /// Ensures Railway build vars like `my-api.up.railway.app` become absolute URLs.
  static String get apiBaseUrl => normalizeBaseUrl(_rawApiBaseUrl);

  static String normalizeBaseUrl(String value) {
    var url = value.trim();
    if (url.isEmpty) {
      return 'http://127.0.0.1:8000';
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }
}

class AppTheme {
  static const green = Color(0xFF58CC02);
  static const greenDark = Color(0xFF46A302);
  static const blue = Color(0xFF1CB0F6);
  static const blueDark = Color(0xFF168CC5);
  static const purple = Color(0xFFCE82FF);
  static const purpleDark = Color(0xFFA568CC);
  static const orange = Color(0xFFFF9600);
  static const orangeDark = Color(0xFFCC7800);
  static const red = Color(0xFFFF4B4B);
  static const ink = Color(0xFF3C3C3C);
  static const muted = Color(0xFF777777);
  static const border = Color(0xFFE5E5E5);
  static const canvas = Color(0xFFFFFDF7);

  static Color phaseColor(String phase) => switch (phase) {
    'sound' => blue,
    'components' => purple,
    'vocabulary' => green,
    'sentences' || 'grammar' => orange,
    _ => blue,
  };

  static Color phaseShadow(String phase) => switch (phase) {
    'sound' => blueDark,
    'components' => purpleDark,
    'vocabulary' => greenDark,
    'sentences' || 'grammar' => orangeDark,
    _ => blueDark,
  };

  static ThemeData get light {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: green),
      useMaterial3: true,
      scaffoldBackgroundColor: canvas,
      textTheme: GoogleFonts.nunitoTextTheme().copyWith(
        headlineLarge: GoogleFonts.fredoka(
          fontWeight: FontWeight.w700,
          color: ink,
        ),
        headlineMedium: GoogleFonts.fredoka(
          fontWeight: FontWeight.w700,
          color: ink,
        ),
        titleLarge: GoogleFonts.fredoka(
          fontWeight: FontWeight.w600,
          color: ink,
        ),
        titleMedium: GoogleFonts.nunito(
          fontWeight: FontWeight.w800,
          color: ink,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: canvas,
        foregroundColor: ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: green.withValues(alpha: .14),
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

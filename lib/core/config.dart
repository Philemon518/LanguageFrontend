import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'api_base_stub.dart'
    if (dart.library.js_interop) 'api_base_web.dart'
    as api_base;

class AppConfig {
  static const _rawApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  /// Local dev talks to the backend directly; deployed web uses same-origin `/api`.
  static String get apiBaseUrl {
    if (kIsWeb) {
      final runtime = api_base.readRuntimeApiBase();
      if (runtime != null && runtime.isNotEmpty) {
        return normalizeBaseUrl(runtime);
      }

      final normalized = normalizeBaseUrl(_rawApiBaseUrl);
      if (!_isLocalBackend(normalized)) {
        return '/api';
      }
      return normalized;
    }

    return normalizeBaseUrl(_rawApiBaseUrl);
  }

  static bool _isLocalBackend(String url) {
    return url.contains('127.0.0.1') ||
        url.contains('localhost') ||
        url.contains('10.0.2.2') ||
        url.startsWith('http://192.168.') ||
        url.startsWith('http://10.');
  }

  static String normalizeBaseUrl(String value) {
    var url = value.trim();
    if (url.isEmpty) {
      return 'http://127.0.0.1:8000';
    }
    if (url.startsWith('/')) {
      while (url.length > 1 && url.endsWith('/')) {
        url = url.substring(0, url.length - 1);
      }
      return url;
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  static Uri resolveUri(String path) => Uri.parse('$apiBaseUrl$path');

  static String resolveMediaUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty ||
        trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('assets/') ||
        trimmed.startsWith('/assets/number_gestures/')) {
      return trimmed;
    }
    final path = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return '$apiBaseUrl$path';
  }

  static Uri resolveWebSocketUri(String path) {
    final base = apiBaseUrl;
    if (base.startsWith('/')) {
      final page = Uri.base;
      final scheme = page.scheme == 'https' ? 'wss' : 'ws';
      return Uri(
        scheme: scheme,
        host: page.host,
        port: page.hasPort ? page.port : null,
        path: '$base$path',
      );
    }

    final wsBase = base.replaceFirst('http', 'ws');
    return Uri.parse('$wsBase$path');
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
    'sound' || 'orientation' => blue,
    'numbers' => green,
    'introductions' => purple,
    'components' => purple,
    'vocabulary' => green,
    'sentences' || 'grammar' => orange,
    _ => blue,
  };

  static Color phaseShadow(String phase) => switch (phase) {
    'sound' || 'orientation' => blueDark,
    'numbers' => greenDark,
    'introductions' => purpleDark,
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

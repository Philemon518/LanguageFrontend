import 'package:canto_mobile/core/config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('apiBaseUrl adds https when Railway omits the scheme', () {
    expect(
      AppConfig.normalizeBaseUrl('languagebackend-production.up.railway.app'),
      'https://languagebackend-production.up.railway.app',
    );
  });

  test('apiBaseUrl preserves explicit scheme and strips trailing slash', () {
    expect(
      AppConfig.normalizeBaseUrl('https://api.example.com/'),
      'https://api.example.com',
    );
  });
}

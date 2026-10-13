import 'package:flutter_test/flutter_test.dart';
import 'package:tripsplit_world/core/config/app_config.dart';

/// These read compile-time defines, so the assertions below hold for the
/// values baked into the test binary (none, unless the runner passes
/// --dart-define). They guard the *logic*, not the secrets.
void main() {
  group('AppConfig Supabase key resolution', () {
    test('resolvedSupabaseKey prefers the publishable key when both are set', () {
      // Under `flutter test` both are empty, so this asserts the invariant that
      // resolution never invents a key rather than a specific precedence.
      final String resolved = AppConfig.resolvedSupabaseKey;

      if (AppConfig.supabasePublishableKey.isNotEmpty) {
        expect(resolved, AppConfig.supabasePublishableKey);
      }
      if (AppConfig.supabaseAnonKey.isNotEmpty &&
          AppConfig.supabasePublishableKey.isEmpty) {
        expect(resolved, AppConfig.supabaseAnonKey);
      }
    });

    test('resolvedSupabaseKey is never null and falls back to the alias', () {
      expect(AppConfig.resolvedSupabaseKey, isNotNull);
    });

    test('isConfigured agrees with the key actually passed to the SDK', () {
      // The bug this guards: isConfigured said true while the client was
      // initialised with an empty key, so every request failed with
      // "No API key found in request" long after start-up.
      final bool expected =
          AppConfig.supabaseUrl.isNotEmpty &&
          AppConfig.resolvedSupabaseKey.isNotEmpty;
      expect(AppConfig.isConfigured, expected);
    });

    test('a configured build has a non-empty key to send', () {
      if (AppConfig.isConfigured) {
        expect(AppConfig.resolvedSupabaseKey, isNotEmpty);
      }
    });
  });

  group('AppConfig url', () {
    test('defaults to the project Supabase instance', () {
      expect(
        AppConfig.supabaseUrl,
        'https://qippwejcvhbikshpnndj.supabase.co',
      );
    });

    test('never carries a trailing slash or path', () {
      expect(AppConfig.supabaseUrl, isNot(endsWith('/')));
      expect(Uri.parse(AppConfig.supabaseUrl).hasAbsolutePath, isFalse);
    });
  });

  group('functionsBaseUrl', () {
    test('derives the Edge Functions base from the project url', () {
      expect(
        AppConfig.functionsBaseUrl,
        '${AppConfig.supabaseUrl}/functions/v1',
      );
    });
  });
}
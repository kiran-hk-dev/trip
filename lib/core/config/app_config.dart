/// Application configuration, supplied at build time via `--dart-define`.
///
/// Only PUBLIC values belong here. Supabase anon/publishable keys are designed
/// to be client-safe (they are protected by Row Level Security). The
/// service-role key and every third-party API secret live in Supabase Edge
/// Function secrets and must NEVER appear in this file or in the bundle.
class AppConfig {
  const AppConfig._();

  /// Public project URL. Safe to default here: it is not a secret — it appears
  /// in every network request the client makes and is visible in devtools.
  /// Override it per-environment with `--dart-define=SUPABASE_URL=...`.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://qippwejcvhbikshpnndj.supabase.co',
  );

  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: '',
  );

  /// Legacy alias, still accepted by the Supabase SDK.
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static const String appEnvironment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  /// When true the app runs entirely against bundled fictional data and never
  /// touches the network. Every screen is clearly labelled "Demo mode".
  static const bool demoMode = bool.fromEnvironment(
    'DEMO_MODE',
    defaultValue: false,
  );

  /// OpenStreetMap tile endpoint used by flutter_map. Swappable at build time
  /// for a commercial tile provider (self-hosted is recommended for production
  /// volume; see README > Maps).
  static const String mapTileUrl = String.fromEnvironment(
    'MAP_TILE_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );
  static const String mapTileAttribution = String.fromEnvironment(
    'MAP_TILE_ATTRIBUTION',
    defaultValue: '© OpenStreetMap contributors',
  );
  static const String mapUserAgent = String.fromEnvironment(
    'MAP_USER_AGENT',
    defaultValue: 'com.tripsplitworld.app',
  );

  static const String appName = 'TripSplit World';
  static const String supportEmail = String.fromEnvironment(
    'SUPPORT_EMAIL',
    defaultValue: 'support@tripsplitworld.example',
  );

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && resolvedSupabaseKey.isNotEmpty;

  /// The key actually handed to the Supabase SDK.
  ///
  /// Must be used instead of [supabasePublishableKey] directly: the SDK takes
  /// a single "publishable" argument, and the legacy [supabaseAnonKey] alias is
  /// equally valid. Reading only the publishable field would pass the
  /// [isConfigured] check while initialising the client with an empty key,
  /// which surfaces much later as "No API key found in request".
  static String get resolvedSupabaseKey => supabasePublishableKey.isNotEmpty
      ? supabasePublishableKey
      : supabaseAnonKey;

  static bool get isProduction => appEnvironment == 'production';

  /// Base URL for Edge Functions. Derived so only the project ref is configured.
  static String get functionsBaseUrl =>
      supabaseUrl.isEmpty ? '' : '$supabaseUrl/functions/v1';
}

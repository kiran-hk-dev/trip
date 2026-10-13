import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_config.dart';

/// Connection state, surfaced to the UI as an offline banner.
enum ConnectionStatus { online, offline, unknown }

/// Thin wrapper over the Supabase client that adds:
///  * a single place to configure the client,
///  * an offline flag driven by connectivity_plus,
///  * uniform error translation,
///  * access to Edge Functions with the caller's JWT attached.
class SupabaseService {
  SupabaseService._(this.client, this._connectivity);

  final SupabaseClient client;
  final Connectivity _connectivity;

  static SupabaseService? _instance;

  static bool get isInitialised => _instance != null;

  static SupabaseService get instance {
    final SupabaseService? service = _instance;
    if (service == null) {
      throw StateError(
        'SupabaseService.initialise() must be called before use.',
      );
    }
    return service;
  }

  static Future<SupabaseService> initialise() async {
    if (_instance != null) return _instance!;

    if (AppConfig.demoMode) {
      // Demo mode intentionally does not initialise a real client. Screens
      // check AppConfig.demoMode first and read bundled fixtures instead.
      throw StateError(
        'Demo mode does not initialise Supabase. Branch on AppConfig.demoMode.',
      );
    }

    if (!AppConfig.isConfigured) {
      throw StateError(
        'Supabase is not configured. Pass --dart-define=SUPABASE_URL=... and '
        '--dart-define=SUPABASE_PUBLISHABLE_KEY=..., or run with '
        '--dart-define=DEMO_MODE=true.',
      );
    }

    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.resolvedSupabaseKey,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: true,
        persistSession: true,
        detectSessionInUri: true,
      ),
    );

    final Connectivity connectivity = Connectivity();
    _instance = SupabaseService._(Supabase.instance.client, connectivity);
    return _instance!;
  }

  // ---------------------------------------------------------------------
  // Auth
  // ---------------------------------------------------------------------
  String? get currentUserId => client.auth.currentUser?.id;

  String? get currentEmail => client.auth.currentUser?.email;

  bool get isSignedIn => client.auth.currentSession != null;

  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  String? get accessToken => client.auth.currentSession?.accessToken;

  // ---------------------------------------------------------------------
  // Connectivity
  // ---------------------------------------------------------------------
  final ValueNotifier<ConnectionStatus> connection =
      ValueNotifier<ConnectionStatus>(ConnectionStatus.unknown);

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  void startConnectivityWatch() {
    _connectivitySub ??= _connectivity.onConnectivityChanged.listen((results) {
      final bool online = results.any((r) => r != ConnectivityResult.none);
      connection.value = online
          ? ConnectionStatus.online
          : ConnectionStatus.offline;
    });
    unawaited(
      _connectivity.checkConnectivity().then((results) {
        final bool online = results.any((r) => r != ConnectivityResult.none);
        connection.value = online
            ? ConnectionStatus.online
            : ConnectionStatus.offline;
      }),
    );
  }

  void dispose() {
    unawaited(_connectivitySub?.cancel());
    connection.dispose();
  }

  // ---------------------------------------------------------------------
  // Edge Functions
  // ---------------------------------------------------------------------

  /// Invokes an Edge Function with the caller's JWT.
  ///
  /// Throws [EdgeFunctionException] with a user-safe message so screens never
  /// have to interpret raw HTTP status codes.
  Future<Map<String, dynamic>> invokeFunction(
    String name, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    if (!AppConfig.isConfigured) {
      throw const EdgeFunctionException(
        'This feature needs a server connection. Check your configuration.',
        code: 'not_configured',
      );
    }

    try {
      final FunctionResponse response = await client.functions.invoke(
        name,
        body: body,
        method: body == null && query != null
            ? HttpMethod.get
            : HttpMethod.post,
        queryParameters: query,
        headers: <String, String>{
          'content-type': 'application/json',
          if (accessToken != null) 'authorization': 'Bearer $accessToken',
        },
      );

      final Map<String, dynamic> decoded = <String, dynamic>{};
      if (response.data is Map) {
        decoded.addAll(response.data as Map<String, dynamic>);
      } else if (response.data is String &&
          (response.data as String).isNotEmpty) {
        try {
          final Object? parsed = jsonDecode(response.data as String);
          if (parsed is Map<String, dynamic>) decoded.addAll(parsed);
        } on FormatException {
          // Non-JSON response: nothing useful to merge.
        }
      }

      if (response.status != 200) {
        final Object? error = decoded['error'];
        final String message = error is Map
            ? (error['message'] as String? ?? 'Request failed')
            : 'Request failed (${response.status})';
        final String code = error is Map
            ? (error['code'] as String? ?? 'error')
            : 'error';
        throw EdgeFunctionException(message, code: code);
      }

      return decoded;
    } on EdgeFunctionException {
      rethrow;
    } catch (err) {
      throw EdgeFunctionException(_friendlyNetworkMessage(err), cause: err);
    }
  }

  String _friendlyNetworkMessage(Object err) {
    final String text = '$err';
    if (text.contains('SocketException') ||
        text.contains('Failed host lookup')) {
      return 'No connection. Cached data is shown where available.';
    }
    if (text.contains('401')) {
      return 'Your session expired. Please sign in again.';
    }
    if (text.contains('403')) return 'You do not have permission to do that.';
    if (text.contains('429')) return 'Too many requests. Please wait a moment.';
    return 'Something went wrong. Please try again.';
  }
}

/// A failure that is safe to show to a user verbatim.
class EdgeFunctionException implements Exception {
  const EdgeFunctionException(this.message, {this.code, this.cause});

  final String message;
  final String? code;
  final Object? cause;

  bool get isRateLimited => code == 'rate_limited';
  bool get isNotConfigured =>
      code == 'ai_not_configured' || code == 'not_configured';
  bool get isUnavailable => code == 'provider_unavailable' || code == 'timeout';

  @override
  String toString() => message;
}

/// Repository-level error with a user-safe message.
class RepositoryException implements Exception {
  const RepositoryException(
    this.message, {
    this.code,
    this.statusCode,
    this.cause,
  });

  final String message;
  final String? code;
  final int? statusCode;
  final Object? cause;

  bool get isNotFound => statusCode == 404;
  bool get isForbidden => statusCode == 403 || code == '42501';
  bool get isOffline => statusCode == null;

  @override
  String toString() => message;
}

/// Small key/value store used for offline caches that are not sensitive.
/// Sensitive material (session, emergency contacts) uses flutter_secure_storage.
class LocalCache {
  LocalCache._(this._prefs);

  static const String _prefix = 'tsw_';

  final SharedPreferences _prefs;

  static Future<LocalCache> open() async =>
      LocalCache._(await SharedPreferences.getInstance());

  String _key(String key) => '$_prefix$key';

  Future<void> putJson(String key, Object value) async {
    await _prefs.setString(_key(key), jsonEncode(value));
  }

  Map<String, dynamic>? getJson(String key) {
    final String? raw = _prefs.getString(_key(key));
    if (raw == null) return null;
    try {
      final Object? decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  List<Map<String, dynamic>> getJsonList(String key) {
    final String? raw = _prefs.getString(_key(key));
    if (raw == null) return const <Map<String, dynamic>>[];
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) return const <Map<String, dynamic>>[];
      return decoded.whereType<Map<String, dynamic>>().toList();
    } on FormatException {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<void> remove(String key) async => _prefs.remove(_key(key));

  bool contains(String key) => _prefs.containsKey(_key(key));

  DateTime? lastUpdated(String key) {
    final String? raw = _prefs.getString(_key('meta_${key}_at'));
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> touch(String key) async => _prefs.setString(
    _key('meta_${key}_at'),
    DateTime.now().toIso8601String(),
  );
}

@immutable
class CachedEnvelope<T> {
  const CachedEnvelope({
    required this.value,
    this.fetchedAt,
    this.isStale = false,
  });

  final T value;
  final DateTime? fetchedAt;
  final bool isStale;
}

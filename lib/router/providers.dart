import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show OtpType;

import '../core/config/app_config.dart';
import '../core/money/currency.dart';
import '../data/demo/demo_fixtures.dart';
import '../data/models/expense.dart';
import '../data/models/trip.dart';
import '../data/repositories.dart';
import '../data/supabase_service.dart';

/// Auth state exposed to the router.
enum AuthStatus { unknown, signedOut, needsVerification, signedIn }

@immutable
class AuthState {
  const AuthState({
    required this.status,
    this.userId,
    this.email,
    this.sessionExpired = false,
  });

  const AuthState.unknown() : this(status: AuthStatus.unknown);

  final AuthStatus status;
  final String? userId;
  final String? email;

  /// True when the user was signed out because their session expired rather
  /// than because they tapped "sign out", so the UI can explain itself.
  final bool sessionExpired;

  bool get isSignedIn => status == AuthStatus.signedIn;
}

/// Owns sign-up, sign-in, sign-out, verification and password reset.
///
/// Uses a Riverpod 3 [Notifier] rather than the legacy `StateNotifier`.
class AuthController extends Notifier<AuthState> {
  StreamSubscription<Object?>? _subscription;

  @override
  AuthState build() {
    // Demo mode never initialises a client, and a misconfigured live build is
    // allowed to keep running so the user sees an explanation instead of a
    // black screen. Guarding here keeps `main()`'s tolerant startup honest:
    // without it the very first provider read throws and takes the app down.
    if (!AppConfig.demoMode && SupabaseService.isInitialised) {
      _subscription = SupabaseService.instance.authStateChanges.listen((_) {
        // Session refreshes are surfaced through explicit calls below; this
        // listener exists so a silent token refresh does not look like a
        // sign-out to the router.
      });
      ref.onDispose(() => unawaited(_subscription?.cancel()));
    }
    return const AuthState.unknown();
  }

  Future<void> bootstrap() async {
    if (AppConfig.demoMode) {
      state = const AuthState(status: AuthStatus.signedIn, userId: 'demo-user');
      return;
    }
    if (!SupabaseService.isInitialised ||
        !SupabaseService.instance.isSignedIn) {
      state = const AuthState(status: AuthStatus.signedOut);
      return;
    }
    await _resolveSession();
  }

  Future<void> _resolveSession({bool sessionExpired = false}) async {
    final String? userId = SupabaseService.instance.currentUserId;
    if (userId == null) {
      state = AuthState(
        status: AuthStatus.signedOut,
        sessionExpired: sessionExpired,
      );
      return;
    }

    // Deliberately no email-confirmation gate.
    //
    // Signing up lands the user straight in. Confirming an email is a second
    // screen between the user and the thing they came to do, and for a trip
    // planner it buys very little: there is no password reset that matters
    // more than the account itself, and the emergency data is public. A user
    // who mistypes their address can correct it in Settings.
    //
    // This only stops the APP from demanding confirmation. Supabase will still
    // refuse to hand out a session when the project has "Confirm email"
    // switched on, so signUp() falls back to signing in directly and reports a
    // clear, actionable message if even that is refused. See
    // docs/supabase.md for turning that project setting off.
    state = AuthState(
      status: AuthStatus.signedIn,
      userId: userId,
      email: SupabaseService.instance.currentEmail,
      sessionExpired: sessionExpired,
    );
  }

  /// Returns null on success, or a short error key the UI can map to a
  /// user-facing message.
  Future<String?> signUp({
    required String email,
    required String password,
    String? fullName,
    String? preferredCurrency,
  }) async {
    final res = await SupabaseService.instance.client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: AppConfig.isProduction
          ? null
          : 'io.supabase.tripsplitworld://login-callback',
      data: <String, dynamic>{
        'full_name': fullName ?? '',
        'preferred_currency': preferredCurrency ?? Currencies.defaultCode,
      },
    );

    // No session means the project is asking for email confirmation. Sign the
    // user straight in instead of showing them an inbox they may not check, so
    // the common case (confirmation disabled) is seamless and a project that
    // has it enabled still fails loudly rather than silently.
    if (res.session == null) {
      final session = await SupabaseService.instance.client.auth
          .signInWithPassword(email: email, password: password)
          .then((_) => true)
          .catchError((_) => false);
      if (!session) return 'email-confirmation-required';
    }

    await _resolveSession();
    return null;
  }

  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    final res = await SupabaseService.instance.client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (res.session == null) return 'invalid-credentials';
    await _resolveSession();
    return null;
  }

  Future<String?> sendPasswordReset(String email) async {
    await SupabaseService.instance.client.auth.resetPasswordForEmail(
      email,
      redirectTo: AppConfig.isProduction
          ? null
          : 'io.supabase.tripsplitworld://reset-password',
    );
    return null;
  }

  Future<void> resendVerification() async {
    final String? email = SupabaseService.instance.currentEmail;
    if (email == null) return;
    await SupabaseService.instance.client.auth.resend(
      type: OtpType.email,
      email: email,
    );
  }

  Future<void> signOut() async {
    await SupabaseService.instance.client.auth.signOut();
    state = const AuthState(status: AuthStatus.signedOut);
  }

  /// Called by the router when GoRouter finds an expired session.
  void markSessionExpired() {
    if (state.status == AuthStatus.signedIn) {
      state = const AuthState(
        status: AuthStatus.signedOut,
        sessionExpired: true,
      );
    }
  }
}

// ---------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

final isDemoModeProvider = Provider<bool>((Ref ref) => AppConfig.demoMode);

final connectionStatusProvider = Provider<ConnectionStatus>((Ref ref) {
  if (!SupabaseService.isInitialised) return ConnectionStatus.unknown;
  return ref.watch(supabaseServiceProvider).connection.value;
});

final supabaseServiceProvider = Provider<SupabaseService>((Ref ref) {
  if (!SupabaseService.isInitialised) {
    throw StateError('Supabase is not initialised in this mode.');
  }
  return SupabaseService.instance;
});

final tripRepositoryProvider = Provider<TripRepository>((Ref ref) {
  return TripRepository(SupabaseService.instance);
});

final destinationRepositoryProvider = Provider<DestinationRepository>((
  Ref ref,
) {
  return DestinationRepository(SupabaseService.instance);
});

final profileProvider = FutureProvider<Profile?>((Ref ref) async {
  if (AppConfig.demoMode) return DemoFixtures.profile;
  if (!SupabaseService.isInitialised) return null;
  final String? userId = SupabaseService.instance.currentUserId;
  if (userId == null) return null;
  final data = await SupabaseService.instance.client
      .from('profiles')
      .select('*')
      .eq('id', userId)
      .maybeSingle();
  return data == null ? null : Profile.fromJson(data);
});

final tripsProvider = FutureProvider.autoDispose<TripListResult>((
  Ref ref,
) async {
  if (AppConfig.demoMode) {
    return TripListResult(trips: DemoFixtures.trips, isStale: false);
  }
  return ref.watch(tripRepositoryProvider).listTrips();
});

/// The trip the user last opened, used to deep-link expenses and balances
/// from the dashboard.
class SelectedTripNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? tripId) => state = tripId;
  void clear() => state = null;
}

final selectedTripIdProvider = NotifierProvider<SelectedTripNotifier, String?>(
  SelectedTripNotifier.new,
);

final currentTripProvider = FutureProvider.autoDispose<Trip?>((Ref ref) async {
  final String? tripId = ref.watch(selectedTripIdProvider);
  if (tripId == null) return null;
  if (AppConfig.demoMode) {
    return DemoFixtures.trips.firstWhere(
      (Trip t) => t.id == tripId,
      orElse: () => DemoFixtures.trips.first,
    );
  }
  return ref.watch(tripRepositoryProvider).getTrip(tripId);
});

final membersProvider = FutureProvider.autoDispose
    .family<List<TripMember>, String>((Ref ref, String tripId) async {
      if (AppConfig.demoMode) return DemoFixtures.membersFor(tripId);
      return ref.watch(tripRepositoryProvider).listMembers(tripId);
    });

final unreadNotificationCountProvider = FutureProvider.autoDispose<int>((
  Ref ref,
) async {
  if (AppConfig.demoMode) {
    return DemoFixtures.notifications
        .where((dynamic n) => n.isUnread as bool)
        .length;
  }
  return ref.watch(tripRepositoryProvider).notifications.unreadCount();
});

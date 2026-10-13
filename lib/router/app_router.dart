import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/config/app_config.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/auth_shell.dart';
import '../features/budget/budget_page.dart';
import '../features/converter/converter_page.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/documents/documents_page.dart';
import '../features/emergency/emergency_center_page.dart';
import '../features/emergency/guide_page.dart';
import '../features/emergency/hk_emergency_page.dart';
import '../features/explore/destination_detail_page.dart';
import '../features/explore/explore_page.dart';
import '../features/expenses/add_expense_page.dart';
import '../features/expenses/balances_page.dart';
import '../features/expenses/expenses_page.dart';
import '../features/expenses/reports_page.dart';
import '../features/invite/accept_invite_page.dart';
import '../features/itinerary/ai_planner_page.dart';
import '../features/itinerary/itinerary_page.dart';
import '../features/notifications/notifications_page.dart';
import '../features/packing/packing_page.dart';
import '../features/profile/profile_page.dart';
import '../features/profile/settings_page.dart';
import '../features/trips/bookings_page.dart';
import '../features/trips/create_trip_page.dart';
import '../features/trips/trip_detail_page.dart';
import '../features/trips/trips_page.dart';
import '../features/trips/visa_page.dart';
import '../shared/widgets/common.dart';
import 'app_shell.dart';
import 'providers.dart';

/// Mirrors the auth status into something GoRouter can listen to.
class RouterAuthNotifier extends ChangeNotifier {
  AuthStatus? status;

  void update(AuthStatus? value) {
    if (status == value) return;
    status = value;
    notifyListeners();
  }
}

final RouterAuthNotifier routerAuthNotifier = RouterAuthNotifier();

/// Wired once from `main` via [attachRouterAuth].
void attachRouterAuth(ProviderContainer container) {
  container.listen<AuthState>(
    authControllerProvider,
    (AuthState? _, AuthState next) => routerAuthNotifier.update(next.status),
    fireImmediately: true,
  );
}

final GoRouter appRouter = GoRouter(
  initialLocation: '/home',
  debugLogDiagnostics: false,
  refreshListenable: routerAuthNotifier,
  redirect: (BuildContext context, GoRouterState state) {
    final AuthStatus? status = routerAuthNotifier.status;
    if (status == null) return null;

    final String location = state.matchedLocation;
    final bool onAuthRoute =
        location.startsWith('/welcome') ||
        location.startsWith('/onboarding') ||
        location.startsWith('/invite');

    // Demo mode never blocks on a session.
    if (AppConfig.demoMode) {
      return location == '/' ? '/home' : null;
    }

    switch (status) {
      case AuthStatus.unknown:
        // Nothing decided yet: hold on the splash screen.
        return location == '/' ? null : '/';
      case AuthStatus.signedOut:
        return onAuthRoute ? null : '/welcome';
      case AuthStatus.signedIn:
        if (location == '/') return '/home';
        if (onAuthRoute) return '/home';
        return null;
      // No email-confirmation gate: signing up lands the user straight in.
      case AuthStatus.needsVerification:
        return '/home';
    }
  },
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) =>
          const SplashPage(),
    ),

    // ---------------- Public -------------------------------------------------
    GoRoute(
      path: '/welcome',
      builder: (BuildContext context, GoRouterState state) => const AuthShell(),
      routes: <RouteBase>[
        GoRoute(
          path: 'sign-in',
          pageBuilder: (BuildContext context, GoRouterState state) =>
              _fadePage(state, const SignInPage()),
        ),
        GoRoute(
          path: 'sign-up',
          pageBuilder: (BuildContext context, GoRouterState state) =>
              _fadePage(state, const SignUpPage()),
        ),
        GoRoute(
          path: 'forgot-password',
          pageBuilder: (BuildContext context, GoRouterState state) =>
              _fadePage(state, const ForgotPasswordPage()),
        ),
      ],
    ),

    GoRoute(
      path: '/onboarding',
      builder: (BuildContext context, GoRouterState state) =>
          const OnboardingPage(),
    ),

    GoRoute(
      path: '/invite/:token',
      builder: (BuildContext context, GoRouterState state) =>
          AcceptInvitePage(token: state.pathParameters['token'] ?? ''),
    ),

    // ---------------- Authenticated shell ----------------------------------
    ShellRoute(
      builder: (BuildContext context, GoRouterState state, Widget child) {
        final String location = state.matchedLocation;
        final AppTab tab = _tabFor(location);
        return AppShell(tab: tab, child: child);
      },
      routes: <RouteBase>[
        GoRoute(
          path: '/home',
          pageBuilder: (BuildContext context, GoRouterState state) =>
              _fadePage(state, const DashboardPage()),
        ),
        GoRoute(
          path: '/trips',
          pageBuilder: (BuildContext context, GoRouterState state) =>
              _fadePage(state, const TripsPage()),
        ),
        GoRoute(
          path: '/trips/new',
          pageBuilder: (BuildContext context, GoRouterState state) =>
              _slidePage(state, const CreateTripPage()),
        ),
        GoRoute(
          path: '/trips/:tripId',
          pageBuilder: (BuildContext context, GoRouterState state) =>
              _slidePage(
                state,
                TripDetailPage(tripId: state.pathParameters['tripId'] ?? ''),
              ),
          routes: <RouteBase>[
            GoRoute(
              path: 'itinerary',
              pageBuilder: (BuildContext context, GoRouterState state) =>
                  _slidePage(
                    state,
                    ItineraryPage(tripId: state.pathParameters['tripId'] ?? ''),
                  ),
            ),
            GoRoute(
              path: 'budget',
              pageBuilder: (BuildContext context, GoRouterState state) =>
                  _slidePage(
                    state,
                    BudgetPage(tripId: state.pathParameters['tripId'] ?? ''),
                  ),
            ),
            GoRoute(
              path: 'expenses',
              pageBuilder: (BuildContext context, GoRouterState state) =>
                  _slidePage(
                    state,
                    ExpensesPage(tripId: state.pathParameters['tripId'] ?? ''),
                  ),
            ),
            GoRoute(
              path: 'balances',
              pageBuilder: (BuildContext context, GoRouterState state) =>
                  _slidePage(
                    state,
                    BalancesPage(tripId: state.pathParameters['tripId'] ?? ''),
                  ),
            ),
            GoRoute(
              path: 'reports',
              pageBuilder: (BuildContext context, GoRouterState state) =>
                  _slidePage(
                    state,
                    ReportsPage(tripId: state.pathParameters['tripId'] ?? ''),
                  ),
            ),
            GoRoute(
              path: 'bookings',
              pageBuilder: (BuildContext context, GoRouterState state) =>
                  _slidePage(
                    state,
                    BookingsPage(tripId: state.pathParameters['tripId'] ?? ''),
                  ),
            ),
            GoRoute(
              path: 'visa',
              pageBuilder: (BuildContext context, GoRouterState state) =>
                  _slidePage(
                    state,
                    VisaPage(tripId: state.pathParameters['tripId'] ?? ''),
                  ),
            ),
            GoRoute(
              path: 'packing',
              pageBuilder: (BuildContext context, GoRouterState state) =>
                  _slidePage(
                    state,
                    PackingPage(tripId: state.pathParameters['tripId'] ?? ''),
                  ),
            ),
            GoRoute(
              path: 'members',
              pageBuilder: (BuildContext context, GoRouterState state) =>
                  _slidePage(
                    state,
                    MembersPage(tripId: state.pathParameters['tripId'] ?? ''),
                  ),
            ),
          ],
        ),
        GoRoute(
          path: '/trips/:tripId/expenses/new',
          pageBuilder: (BuildContext context, GoRouterState state) =>
              _slidePage(
                state,
                AddExpensePage(tripId: state.pathParameters['tripId'] ?? ''),
              ),
        ),
        GoRoute(
          path: '/expenses',
          pageBuilder: (BuildContext context, GoRouterState state) =>
              _fadePage(state, const ExpensesPage()),
        ),
        GoRoute(
          path: '/expenses/new',
          pageBuilder: (BuildContext context, GoRouterState state) =>
              _slidePage(state, const AddExpensePage()),
        ),
        GoRoute(
          path: '/explore',
          pageBuilder: (BuildContext context, GoRouterState state) =>
              _fadePage(state, const ExplorePage()),
        ),
        GoRoute(
          path: '/explore/:destinationId',
          pageBuilder: (BuildContext context, GoRouterState state) =>
              _slidePage(
                state,
                DestinationDetailPage(
                  destinationId: state.pathParameters['destinationId'] ?? '',
                ),
              ),
        ),
        GoRoute(
          path: '/assistant',
          pageBuilder: (BuildContext context, GoRouterState state) =>
              _fadePage(state, const EmergencyCenterPage()),
        ),
      ],
    ),

    // ---------------- Full-screen routes ------------------------------------
    GoRoute(
      path: '/converter',
      pageBuilder: (BuildContext context, GoRouterState state) =>
          _slidePage(state, const ConverterPage()),
    ),
    GoRoute(
      path: '/ai-planner',
      pageBuilder: (BuildContext context, GoRouterState state) =>
          _slidePage(state, const AiPlannerPage()),
    ),
    GoRoute(
      path: '/documents',
      pageBuilder: (BuildContext context, GoRouterState state) =>
          _slidePage(state, const DocumentsPage()),
    ),
    GoRoute(
      path: '/emergency/:slug',
      pageBuilder: (BuildContext context, GoRouterState state) => _slidePage(
        state,
        EmergencyGuidePage(slug: state.pathParameters['slug'] ?? ''),
      ),
    ),
    GoRoute(
      path: '/emergency/hong-kong/lost-passport',
      pageBuilder: (BuildContext context, GoRouterState state) =>
          _slidePage(state, const HongKongLostPassportPage()),
    ),
    GoRoute(
      path: '/notifications',
      pageBuilder: (BuildContext context, GoRouterState state) =>
          _slidePage(state, const NotificationsPage()),
    ),
    GoRoute(
      path: '/profile',
      pageBuilder: (BuildContext context, GoRouterState state) =>
          _slidePage(state, const ProfilePage()),
    ),
    GoRoute(
      path: '/settings',
      pageBuilder: (BuildContext context, GoRouterState state) =>
          _slidePage(state, const SettingsPage()),
    ),
  ],
  errorBuilder: (BuildContext context, GoRouterState state) =>
      NotFoundPage(location: state.uri.toString()),
);

AppTab _tabFor(String location) {
  if (location.startsWith('/trips')) return AppTab.trips;
  if (location.startsWith('/expenses')) return AppTab.expenses;
  if (location.startsWith('/explore')) return AppTab.explore;
  if (location.startsWith('/assistant')) return AppTab.assistant;
  return AppTab.home;
}

CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: AppDurations.fast,
    transitionsBuilder: (
      _,
      Animation<double> animation,
      Animation<double> secondary,
      Widget? page,
    ) => FadeTransition(opacity: animation, child: page),
  );
}

CustomTransitionPage<void> _slidePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: AppDurations.normal,
    transitionsBuilder:
        (
          _,
          Animation<double> animation,
          Animation<double> secondary,
          Widget? page,
        ) {
          final CurvedAnimation curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.03),
              end: Offset.zero,
            ).animate(curved),
            child: FadeTransition(opacity: animation, child: page),
          );
        },
  );
}

/// Shown while the session is being resolved on cold start.
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authControllerProvider.notifier).bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: const Icon(Icons.explore, size: 32, color: Colors.white),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('TripSplit World', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xxl),
            const SizedBox(
              width: 120,
              child: LinearProgressIndicator(minHeight: 3),
            ),
          ],
        ),
      ),
    );
  }
}

/// 404 page that keeps navigation usable.
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key, required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Page not found')),
      body: EmptyState(
        icon: Icons.explore_off,
        title: 'We could not find that page',
        message: 'Nothing lives at "$location".',
        action: FilledButton(
          onPressed: () => context.go('/home'),
          child: const Text('Go to Home'),
        ),
      ),
    );
  }
}

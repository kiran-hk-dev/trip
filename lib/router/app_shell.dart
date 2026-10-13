import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/config/app_config.dart';
import '../core/theme/app_theme.dart';
import '../data/demo/demo_fixtures.dart';
import '../data/supabase_service.dart';
import '../data/models/trip.dart';
import '../shared/widgets/common.dart';
import 'providers.dart';

/// The five primary destinations. Kept in one place so the bottom bar, the
/// navigation rail and the widget tests all agree.
enum AppTab {
  home('home', 'Home', Icons.home_outlined, Icons.home),
  trips('trips', 'Trips', Icons.luggage_outlined, Icons.luggage),
  expenses(
    'expenses',
    'Expenses',
    Icons.receipt_long_outlined,
    Icons.receipt_long,
  ),
  explore(
    'explore',
    'Explore',
    Icons.travel_explore_outlined,
    Icons.travel_explore,
  ),
  assistant(
    'assistant',
    'Assistant',
    Icons.health_and_safety_outlined,
    Icons.health_and_safety,
  );

  const AppTab(this.route, this.label, this.icon, this.selectedIcon);

  final String route;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Adaptive shell: bottom navigation on phones, a navigation rail from the
/// tablet breakpoint up, and a rail plus a persistent detail pane on desktop.
class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.tab,
    required this.child,
    this.floatingActionButton,
    this.title,
    this.actions,
    this.showBackButton = false,
  });

  final AppTab tab;
  final Widget child;
  final Widget? floatingActionButton;
  final String? title;
  final List<Widget>? actions;
  final bool showBackButton;

  static const List<String> _railLabels = <String>[
    'Home',
    'My trips',
    'Expenses',
    'Explore',
    'Assistant',
  ];

  void _go(AppTab target, BuildContext context, WidgetRef ref) {
    if (target == tab) return;
    ref.read(selectedTripIdProvider.notifier).clear();
    GoRouter.of(context).go('/${target.route}');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double width = MediaQuery.sizeOf(context).width;
    final bool useRail = width >= AppBreakpoints.tablet;
    final bool useExtendedRail = width >= AppBreakpoints.desktop;

    final Widget content = Scaffold(
      appBar: title == null && actions == null && !showBackButton
          ? null
          : AppBar(
              title: title == null ? null : Text(title!),
              leading: showBackButton
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => context.canPop()
                          ? context.pop()
                          : context.go('/home'),
                      tooltip: 'Back',
                    )
                  : null,
              actions: actions,
            ),
      body: _WrapWithConnectionBanner(child: child),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: useRail
          ? null
          : NavigationBar(
              selectedIndex: AppTab.values.indexOf(tab),
              onDestinationSelected: (int i) =>
                  _go(AppTab.values[i], context, ref),
              destinations: <Widget>[
                for (final AppTab t in AppTab.values)
                  NavigationDestination(
                    icon: Icon(t.icon),
                    selectedIcon: Icon(t.selectedIcon),
                    label: t.label,
                    tooltip: t.label,
                  ),
              ],
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );

    if (!useRail) return content;

    return Scaffold(
      body: Row(
        children: <Widget>[
          SafeArea(
            right: false,
            child: NavigationRail(
              selectedIndex: AppTab.values.indexOf(tab),
              onDestinationSelected: (int i) =>
                  _go(AppTab.values[i], context, ref),
              labelType: useExtendedRail
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              extended: useExtendedRail,
              minExtendedWidth: 200,
              leading: Padding(
                padding: const EdgeInsets.only(
                  top: AppSpacing.lg,
                  bottom: AppSpacing.xl,
                ),
                child: _RailLogo(extended: useExtendedRail),
              ),
              destinations: <NavigationRailDestination>[
                for (final AppTab t in AppTab.values)
                  NavigationRailDestination(
                    icon: Icon(t.icon),
                    selectedIcon: Icon(t.selectedIcon),
                    label: Text(
                      useExtendedRail
                          ? _railLabels[AppTab.values.indexOf(t)]
                          : t.label,
                    ),
                  ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Scaffold(
              appBar: title == null && actions == null && !showBackButton
                  ? null
                  : AppBar(
                      title: title == null ? null : Text(title!),
                      automaticallyImplyLeading: false,
                      actions: actions,
                    ),
              body: _WrapWithConnectionBanner(child: child),
              floatingActionButton: floatingActionButton,
            ),
          ),
        ],
      ),
    );
  }
}

class _RailLogo extends StatelessWidget {
  const _RailLogo({required this.extended});

  final bool extended;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: const Icon(Icons.explore, size: 18, color: Colors.white),
        ),
        if (extended) ...<Widget>[
          const SizedBox(width: AppSpacing.md),
          Text('TripSplit', style: theme.textTheme.titleMedium),
        ],
      ],
    );
  }
}

/// Shows an offline banner when the device has no connection. It never blocks
/// content — cached data stays readable.
class _WrapWithConnectionBanner extends ConsumerWidget {
  const _WrapWithConnectionBanner({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (AppConfig.demoMode) {
      return Column(
        children: <Widget>[
          const _DemoBanner(),
          Expanded(child: child),
        ],
      );
    }

    final ConnectionStatus status = ref.watch(connectionStatusProvider);
    if (status != ConnectionStatus.offline) return child;

    return Column(
      children: <Widget>[
        Container(
          width: double.infinity,
          color: Theme.of(context).colorScheme.secondaryContainer,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.cloud_off,
                size: 16,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'You are offline. Cached data is shown where available.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _DemoBanner extends StatelessWidget {
  const _DemoBanner();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: double.infinity,
      color: AppColors.warningSoft,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.science_outlined,
            size: 16,
            color: AppColors.warning,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Demo mode — fictional data, nothing is saved and no network calls are made.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Standard header used at the top of each tab's scroll view.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const <Widget>[],
    this.avatar,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? avatar;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          if (avatar != null) ...<Widget>[
            avatar!,
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: theme.textTheme.titleLarge),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle!, style: theme.textTheme.bodySmall),
                  ),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// Notification bell with an unread badge, used in headers.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int count = ref.watch(unreadNotificationCountProvider).value ?? 0;

    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        IconButton(
          onPressed: () => context.push('/notifications'),
          icon: const Icon(Icons.notifications_none),
          tooltip: count > 0 ? '$count unread notifications' : 'Notifications',
        ),
        if (count > 0)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              constraints: const BoxConstraints(minWidth: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 1.5,
                ),
              ),
              child: Text(
                count > 9 ? '9+' : '$count',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Small helper for demo-mode-only actions: runs the callback in demo mode and
/// otherwise shows a clear "not available in demo mode" message.
Future<void> guardDemoAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  if (AppConfig.demoMode) {
    showFeedback(
      context,
      'This action is disabled in demo mode — nothing is saved.',
      isError: true,
    );
    return;
  }
  await action();
}

/// Reads the demo profile when in demo mode, otherwise the live profile.
Profile? demoOrNull(Profile? profile) =>
    AppConfig.demoMode ? DemoFixtures.profile : profile;

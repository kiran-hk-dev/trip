import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/money/currency.dart';
import '../../core/theme/app_theme.dart';
import '../../data/demo/demo_fixtures.dart';
import '../../data/models/misc.dart';
import '../../data/models/trip.dart';
import '../../data/repositories.dart';
import '../../router/app_shell.dart';
import '../../router/providers.dart';
import '../../shared/widgets/avatars.dart';
import '../../shared/widgets/common.dart';

/// Per-trip figures used by the dashboard cards.
class TripFinanceSummary {
  const TripFinanceSummary({
    required this.tripId,
    required this.tripName,
    required this.currency,
    required this.budgetMinor,
    required this.spentMinor,
    required this.owedToMeMinor,
    required this.iOweMinor,
  });

  final String tripId;
  final String tripName;
  final String currency;
  final int budgetMinor;
  final int spentMinor;
  final int owedToMeMinor;
  final int iOweMinor;

  int get remainingMinor => budgetMinor - spentMinor;

  double get utilisation => budgetMinor <= 0 ? 0 : spentMinor / budgetMinor;

  bool get isOverBudget => budgetMinor > 0 && spentMinor > budgetMinor;
}

final tripFinanceProvider =
    FutureProvider.autoDispose<List<TripFinanceSummary>>((Ref ref) async {
      if (AppConfig.demoMode) {
        return <TripFinanceSummary>[
          for (final Trip t in DemoFixtures.trips)
            if (t.id == DemoFixtures.hkTripId)
              TripFinanceSummary(
                tripId: t.id,
                tripName: t.name,
                currency: t.baseCurrency,
                budgetMinor: 3200000,
                spentMinor: 1908000,
                owedToMeMinor: 0,
                iOweMinor: 0,
              ),
        ];
      }

      final TripRepository repo = ref.watch(tripRepositoryProvider);
      final TripListResult trips = await ref.watch(tripsProvider.future);
      final List<TripFinanceSummary> out = <TripFinanceSummary>[];

      for (final Trip trip in trips.trips) {
        try {
          final balances = await repo.expenses.balances(trip.id);
          final budget = await repo.budget.load(
            trip.id,
            dayCount: trip.dayCount,
            daysRemaining: trip.daysUntilStart < 0 ? 0 : trip.daysUntilStart,
          );
          out.add(
            TripFinanceSummary(
              tripId: trip.id,
              tripName: trip.name,
              currency: trip.baseCurrency,
              budgetMinor: budget.totalMinor,
              spentMinor: budget.spentMinor,
              owedToMeMinor: balances
                  .where((b) => b.netMinor > 0)
                  .fold<int>(0, (sum, b) => sum + b.netMinor),
              iOweMinor: balances
                  .where((b) => b.netMinor < 0)
                  .fold<int>(0, (sum, b) => sum - b.netMinor),
            ),
          );
        } catch (_) {
          // One failing trip must not blank the whole dashboard.
          continue;
        }
      }

      return out;
    });

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<TripListResult> tripsAsync = ref.watch(tripsProvider);
    final AsyncValue<List<TripFinanceSummary>> financeAsync = ref.watch(
      tripFinanceProvider,
    );
    final AsyncValue<Profile?> profileAsync = ref.watch(profileProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(tripsProvider);
        ref.invalidate(tripFinanceProvider);
        ref.invalidate(profileProvider);
        await ref
            .read(tripsProvider.future)
            .catchError((Object _) => throw _Swallow());
      },
      child: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: PageHeader(
              title: _greeting(profileAsync.value),
              subtitle: DateTime.now().toIso8601String().substring(0, 10),
              avatar: UserAvatar(
                initials: profileAsync.value?.initials ?? '?',
                size: 38,
                onTap: () => context.push('/profile'),
              ),
              actions: const <Widget>[NotificationBell()],
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: _QuickActions(tripsAsync: tripsAsync),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),

          // ---- Next trip ------------------------------------------------
          SliverToBoxAdapter(
            child: SectionHeader(
              title: 'Next trip',
              action: TextButton(
                onPressed: () => context.go('/trips'),
                child: const Text('All trips'),
              ),
            ),
          ),
          // These three helpers return box widgets, so they have to be adapted
          // to slivers. Spreading them straight into `slivers:` throws
          // "A RenderViewport expected a child of type RenderSliver" as soon as
          // the corresponding branch is taken.
          ..._asSlivers(_buildNextTrip(context, ref, tripsAsync, financeAsync)),

          // ---- Money ----------------------------------------------------
          SliverToBoxAdapter(
            child: SectionHeader(
              title: 'Money',
              subtitle: 'Unsettled balances, per trip currency',
              action: TextButton(
                onPressed: () => context.go('/expenses'),
                child: const Text('Expenses'),
              ),
            ),
          ),
          ..._asSlivers(_buildMoney(context, financeAsync)),

          // ---- Activity -------------------------------------------------
          const SliverToBoxAdapter(
            child: SectionHeader(title: 'Recent activity'),
          ),
          ..._asSlivers(_buildActivity(context, ref, tripsAsync)),

          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.huge)),
        ],
      ),
    );
  }

  /// Wraps box widgets from the section helpers so they can live in a
  /// `CustomScrollView`'s sliver list.
  static List<Widget> _asSlivers(List<Widget> children) => <Widget>[
    for (final Widget child in children)
      if (child is SliverToBoxAdapter)
        child
      else
        SliverToBoxAdapter(child: child),
  ];

  String _greeting(Profile? profile) {
    final int hour = DateTime.now().hour;
    final String part = hour < 12
        ? 'Good morning'
        : hour < 18
        ? 'Good afternoon'
        : 'Good evening';
    final String name = profile?.displayName ?? '';
    return name.isEmpty ? part : '$part, $name';
  }

  List<Widget> _buildNextTrip(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<TripListResult> tripsAsync,
    AsyncValue<List<TripFinanceSummary>> financeAsync,
  ) {
    if (tripsAsync.isLoading) {
      return const <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: SkeletonCard(lines: 2, height: 180),
        ),
      ];
    }
    if (tripsAsync.hasError) {
      return <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: InlineBanner(
            message: 'Could not load your trips. ${tripsAsync.error}',
            tone: StatusTone.danger,
            action: TextButton(
              onPressed: () => ref.invalidate(tripsProvider),
              child: const Text('Retry'),
            ),
          ),
        ),
      ];
    }

    final List<Trip> trips = tripsAsync.value?.trips ?? const <Trip>[];
    if (trips.isEmpty) {
      return <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: AppCard(
            child: EmptyState(
              compact: true,
              icon: Icons.luggage_outlined,
              title: 'No trips yet',
              message: 'Create your first trip to start budgeting, planning days and splitting costs with friends.',
              action: FilledButton.icon(
                onPressed: () => context.push('/trips/new'),
                icon: const Icon(Icons.add),
                label: const Text('Create a trip'),
              ),
            ),
          ),
        ),
      ];
    }

    final Trip next = trips.firstWhere(
      (Trip t) => t.isUpcoming || t.isOngoing,
      orElse: () => trips.first,
    );
    final TripFinanceSummary? finance = financeAsync.value
        ?.where((TripFinanceSummary f) => f.tripId == next.id)
        .firstOrNull;

    return <Widget>[
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: _NextTripCard(trip: next, finance: finance),
      ),
    ];
  }

  List<Widget> _buildMoney(
    BuildContext context,
    AsyncValue<List<TripFinanceSummary>> financeAsync,
  ) {
    if (financeAsync.isLoading) {
      return const <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: SkeletonCard(lines: 2),
        ),
      ];
    }
    final List<TripFinanceSummary> all =
        financeAsync.value ?? const <TripFinanceSummary>[];
    if (all.isEmpty) {
      return const <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: AppCard(
            child: EmptyState(
              compact: true,
              icon: Icons.receipt_long_outlined,
              title: 'No expenses yet',
              message:
                  'Add your first expense to start tracking who paid for what.',
            ),
          ),
        ),
      ];
    }

    // Balances are per trip currency and are deliberately NOT summed across
    // trips with different currencies.
    return <Widget>[
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Column(
          children: <Widget>[
            for (final TripFinanceSummary f in all) ...<Widget>[
              _BalanceRow(summary: f),
              const SizedBox(height: AppSpacing.md),
            ],
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildActivity(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<TripListResult> tripsAsync,
  ) {
    final List<Trip> trips = tripsAsync.value?.trips ?? const <Trip>[];
    if (trips.isEmpty) return const <Widget>[];

    final Trip trip = trips.first;
    if (AppConfig.demoMode) {
      final List<ActivityLog> logs = DemoFixtures.activityFor(trip.id);
      return <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: AppCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Column(
              children: <Widget>[
                for (int i = 0; i < logs.length && i < 5; i++)
                  _ActivityTile(
                    log: logs[i],
                    showDivider: i < logs.length - 1 && i < 4,
                  ),
              ],
            ),
          ),
        ),
      ];
    }

    return <Widget>[
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: FutureBuilder<List<ActivityLog>>(
          future: ref
              .watch(tripRepositoryProvider)
              .listActivity(trip.id, limit: 6),
          builder:
              (
                BuildContext context,
                AsyncSnapshot<List<ActivityLog>> snapshot,
              ) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const AppCard(
                    child: EmptyState(
                      compact: true,
                      icon: Icons.history,
                      title: 'Nothing yet',
                      message: 'Activity on this trip will appear here.',
                    ),
                  );
                }
                final List<ActivityLog> logs = snapshot.data!;
                return AppCard(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Column(
                    children: <Widget>[
                      for (int i = 0; i < logs.length; i++)
                        _ActivityTile(
                          log: logs[i],
                          showDivider: i < logs.length - 1,
                        ),
                    ],
                  ),
                );
              },
        ),
      ),
    ];
  }
}

class _Swallow implements Exception {
  const _Swallow();
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.tripsAsync});

  final AsyncValue<TripListResult> tripsAsync;

  @override
  Widget build(BuildContext context) {
    final List<Trip> trips = tripsAsync.value?.trips ?? const <Trip>[];
    final Trip? first = trips.isEmpty ? null : trips.first;

    return Row(
      children: <Widget>[
        Expanded(
          child: FilledButton.icon(
            onPressed: () => context.push('/trips/new'),
            icon: const Icon(Icons.add),
            label: const Text('New trip'),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => first == null
                ? null
                : context.push('/trips/${first.id}/expenses/new'),
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('Add expense'),
          ),
        ),
      ],
    );
  }
}

class _NextTripCard extends StatelessWidget {
  const _NextTripCard({required this.trip, this.finance});

  final Trip trip;
  final TripFinanceSummary? finance;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String currency = trip.baseCurrency;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          context.push('/trips/${trip.id}');
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (trip.coverImageUrl != null && trip.coverImageUrl!.isNotEmpty)
              AspectRatio(
                aspectRatio: 16 / 7,
                child: Image.network(
                  trip.coverImageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  loadingBuilder:
                      (
                        BuildContext context,
                        Widget child,
                        ImageChunkEvent? progress,
                      ) {
                        if (progress == null) return child;
                        return const SkeletonBox();
                      },
                ),
              )
            else
              Container(
                height: 8,
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
              ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      StatusPill(
                        label: trip.effectiveStatus.label,
                        tone: trip.isOngoing
                            ? StatusTone.positive
                            : trip.isPast
                            ? StatusTone.neutral
                            : StatusTone.info,
                        dense: true,
                      ),
                      const Spacer(),
                      if (trip.isUpcoming)
                        Text(
                          'in ${trip.daysUntilStart} day${trip.daysUntilStart == 1 ? '' : 's'}',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    trip.name,
                    style: theme.textTheme.titleLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${trip.destinationLabel} · ${trip.dateRangeLabel} · ${trip.dayCount} days',
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (finance != null && finance!.budgetMinor > 0) ...<Widget>[
                    const SizedBox(height: AppSpacing.xl),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text('Spent', style: theme.textTheme.bodySmall),
                              Text(
                                Money(finance!.spentMinor, currency).format(),
                                style: theme.textTheme.titleMedium,
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            Text('of budget', style: theme.textTheme.bodySmall),
                            Text(
                              Money(finance!.budgetMinor, currency).format(),
                              style: theme.textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    BudgetProgressBar(value: finance!.utilisation),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      finance!.isOverBudget
                          ? 'Over budget by ${Money(finance!.spentMinor - finance!.budgetMinor, currency).format()}'
                          : '${Money(finance!.remainingMinor, currency).format()} left',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: finance!.isOverBudget
                            ? theme.colorScheme.error
                            : theme.textTheme.bodySmall?.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceRow extends StatelessWidget {
  const _BalanceRow({required this.summary});

  final TripFinanceSummary summary;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool hasMoney = summary.owedToMeMinor > 0 || summary.iOweMinor > 0;

    return AppCard(
      onTap: () => context.push('/trips/${summary.tripId}/balances'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  summary.tripName,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.chevron_right, size: 18),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: _MoneyFigure(
                  label: 'Owed to you',
                  amount: summary.owedToMeMinor,
                  currency: summary.currency,
                  color: AppColors.positive,
                ),
              ),
              Container(width: 1, height: 34, color: theme.colorScheme.outline),
              Expanded(
                child: _MoneyFigure(
                  label: 'You owe',
                  amount: summary.iOweMinor,
                  currency: summary.currency,
                  color: summary.iOweMinor > 0 ? AppColors.danger : null,
                ),
              ),
            ],
          ),
          if (!hasMoney) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Everyone is settled up on this trip.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.positive,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MoneyFigure extends StatelessWidget {
  const _MoneyFigure({
    required this.label,
    required this.amount,
    required this.currency,
    this.color,
  });

  final String label;
  final int amount;
  final String currency;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: theme.textTheme.bodySmall),
        const SizedBox(height: 2),
        Text(
          Money(amount, currency).format(),
          style: theme.textTheme.titleMedium?.copyWith(color: color),
        ),
      ],
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.log, this.showDivider = true});

  final ActivityLog log;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      children: <Widget>[
        ListTile(
          dense: true,
          leading: MemberAvatar(
            initials: (log.actorName ?? '?')
                .split(' ')
                .map((String w) {
                  return w.isEmpty ? '' : w[0];
                })
                .take(2)
                .join(),
            size: 34,
          ),
          title: Text(log.summary, style: theme.textTheme.bodyMedium),
          subtitle: Text(
            _relative(log.createdAt),
            style: theme.textTheme.bodySmall,
          ),
        ),
        if (showDivider) const Divider(indent: AppSpacing.lg + 44),
      ],
    );
  }
}

String _relative(DateTime when) {
  final Duration d = DateTime.now().difference(when);
  if (d.inMinutes < 1) return 'Just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  if (d.inDays < 7) return '${d.inDays} d ago';
  return '${when.day}/${when.month}/${when.year}';
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

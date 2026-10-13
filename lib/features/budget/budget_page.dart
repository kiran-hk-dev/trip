import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/money/currency.dart';
import '../../core/theme/app_theme.dart';
import '../../data/demo/demo_fixtures.dart';
import '../../data/models/expense.dart';
import '../../data/models/planning.dart';
import '../../data/supabase_service.dart';
import '../../data/models/trip.dart';
import '../../router/providers.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/form_fields.dart';

final budgetProvider = FutureProvider.autoDispose.family<Budget, String>((
  Ref ref,
  String tripId,
) async {
  if (AppConfig.demoMode) return DemoFixtures.budgetFor(tripId);
  final AsyncValue<Trip?> trip = ref.watch(currentTripProvider);
  final Trip? t = trip.value;
  return ref
      .watch(tripRepositoryProvider)
      .budget
      .load(
        tripId,
        dayCount: t?.dayCount ?? 1,
        daysRemaining: (t == null || t.isPast) ? 0 : t.daysUntilStart,
      );
});

class BudgetPage extends ConsumerStatefulWidget {
  const BudgetPage({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends ConsumerState<BudgetPage> {
  final TextEditingController _total = TextEditingController();
  final TextEditingController _contingency = TextEditingController();
  bool _busy = false;
  bool _editing = false;

  @override
  void dispose() {
    _total.dispose();
    _contingency.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Budget> async = ref.watch(budgetProvider(widget.tripId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget'),
        actions: <Widget>[
          if (async.hasValue)
            IconButton(
              onPressed: () => setState(() => _editing = !_editing),
              icon: Icon(_editing ? Icons.close : Icons.edit_outlined),
              tooltip: _editing ? 'Cancel' : 'Edit budget',
            ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object err, StackTrace _) => ErrorStateView(
          message: '$err',
          onRetry: () => ref.invalidate(budgetProvider(widget.tripId)),
        ),
        data: (Budget budget) => _buildBody(context, ref, budget),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, Budget budget) {
    final String currency = budget.currency;

    if (_editing) {
      _total.text = Money(budget.totalMinor, currency).format(locale: 'en');
      _contingency.text = Money(
        budget.contingencyMinor,
        currency,
      ).format(locale: 'en');
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        if (_editing) ...<Widget>[
          MoneyField(
            label: 'Total trip budget',
            currency: currency,
            controller: _total,
            helperText: 'The amount you plan to spend in total.',
          ),
          const SizedBox(height: AppSpacing.lg),
          MoneyField(
            label: 'Contingency reserve',
            currency: currency,
            controller: _contingency,
            helperText: 'Held back for the unexpected. Not counted in category budgets.',
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    try {
                      await ref
                          .read(tripRepositoryProvider)
                          .budget
                          .updateTotals(
                            widget.tripId,
                            totalMinor: Money.tryParse(
                              _total.text,
                              currency,
                            ).minorUnits,
                            contingencyMinor: Money.tryParse(
                              _contingency.text,
                              currency,
                            ).minorUnits,
                          );
                      ref.invalidate(budgetProvider(widget.tripId));
                      if (context.mounted) {
                        setState(() => _editing = false);
                        showFeedback(context, 'Budget updated.');
                      }
                    } catch (err) {
                      if (context.mounted) {
                        showFeedback(
                          context,
                          err is RepositoryException ? err.message : '$err',
                          isError: true,
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
            child: const Text('Save budget'),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],

        _SummaryCard(budget: budget),

        const SizedBox(height: AppSpacing.lg),
        if (budget.unallocatedMinor != 0)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: InlineBanner(
              tone: budget.unallocatedMinor > 0
                  ? StatusTone.warning
                  : StatusTone.danger,
              message: budget.unallocatedMinor > 0
                  ? '${Money(budget.unallocatedMinor, currency).format()} is not allocated to any '
                        'category yet.'
                  : 'Category budgets exceed the trip total by '
                        '${Money(-budget.unallocatedMinor, currency).format()}.',
            ),
          ),

        const SectionHeader(
          title: 'By category',
          subtitle: 'Planned versus actual, with per-person share',
          padding: EdgeInsets.only(bottom: AppSpacing.md),
        ),

        for (final BudgetCategoryAllocation c in budget.categories)
          AppCard(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _CategoryRow(
              allocation: c,
              currency: currency,
              travelers: 1,
            ),
          ),

        if (budget.categories.isEmpty)
          const AppCard(
            child: EmptyState(
              compact: true,
              icon: Icons.pie_chart_outline,
              title: 'No categories yet',
              message: 'Add categories to see planned versus actual spending at a glance.',
            ),
          ),

        const SizedBox(height: AppSpacing.lg),
        OutlinedButton.icon(
          onPressed: () => _allocate(context, ref, budget),
          icon: const Icon(Icons.add),
          label: const Text('Allocate a category'),
        ),

        const SizedBox(height: AppSpacing.huge),
      ],
    );
  }

  Future<void> _allocate(
    BuildContext context,
    WidgetRef ref,
    Budget budget,
  ) async {
    final ({ExpenseCategory category, int planned, bool essential})? result =
        await showAppSheet<
          ({ExpenseCategory category, int planned, bool essential})
        >(
          context: context,
          builder: (BuildContext context) =>
              _AllocateSheet(currency: budget.currency),
        );
    if (result == null) return;
    if (!context.mounted) return;

    if (AppConfig.demoMode) {
      showFeedback(
        context,
        'Allocations are disabled in demo mode.',
        isError: true,
      );
      return;
    }

    try {
      await ref
          .read(tripRepositoryProvider)
          .budget
          .upsertAllocation(
            tripId: widget.tripId,
            category: result.category,
            plannedMinor: result.planned,
            isEssential: result.essential,
          );
      ref.invalidate(budgetProvider(widget.tripId));
      if (context.mounted) showFeedback(context, 'Allocation saved.');
    } catch (err) {
      if (context.mounted) {
        showFeedback(
          context,
          err is RepositoryException ? err.message : '$err',
          isError: true,
        );
      }
    }
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.budget});

  final Budget budget;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String currency = budget.currency;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Spent', style: theme.textTheme.bodySmall),
                    Text(
                      Money(budget.spentMinor, currency).format(),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: budget.isOverBudget
                            ? theme.colorScheme.error
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text('of', style: theme.textTheme.bodySmall),
                  Text(
                    Money(budget.totalMinor, currency).format(),
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          BudgetProgressBar(value: budget.utilisation),
          const SizedBox(height: AppSpacing.sm),
          Text(
            budget.isOverBudget
                ? 'Over budget by ${Money(-budget.remainingMinor, currency).format()}'
                : '${(budget.utilisation * 100).round()}% used · '
                      '${Money(budget.remainingMinor, currency).format()} left',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: budget.isOverBudget ? theme.colorScheme.error : null,
            ),
          ),
          if (budget.isApproachingLimit)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: StatusPill(
                label:
                    'Past your ${budget.alertThresholdPct.round()}% alert threshold',
                tone: StatusTone.warning,
                icon: Icons.warning_amber_rounded,
                dense: true,
              ),
            ),
          const Divider(height: AppSpacing.xxl),
          Row(
            children: <Widget>[
              Expanded(
                child: _Figure(
                  label: 'Contingency',
                  value: Money(budget.contingencyMinor, currency).format(),
                ),
              ),
              Expanded(
                child: _Figure(
                  label: 'Safe daily spend',
                  value: Money(budget.safeDailySpendMinor, currency).format(),
                ),
              ),
              Expanded(
                child: _Figure(
                  label: 'Days left',
                  value: '${budget.daysRemaining}',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Safe daily spend is what is left divided by the remaining days. It is a guide, '
            'not a limit.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: theme.textTheme.bodySmall, maxLines: 2),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.allocation,
    required this.currency,
    required this.travelers,
  });

  final BudgetCategoryAllocation allocation;
  final String currency;
  final int travelers;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              allocation.category.emoji,
              style: const TextStyle(fontSize: 17),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                allocation.category.label,
                style: theme.textTheme.titleSmall,
              ),
            ),
            if (allocation.isEssential)
              const Padding(
                padding: EdgeInsets.only(right: AppSpacing.sm),
                child: StatusPill(label: 'Essential', dense: true),
              ),
            if (allocation.isOverBudget)
              const StatusPill(
                label: 'Over',
                dense: true,
                tone: StatusTone.danger,
                icon: Icons.trending_up,
              )
            else if (allocation.isApproachingLimit)
              const StatusPill(
                label: 'Near limit',
                dense: true,
                tone: StatusTone.warning,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        BudgetProgressBar(value: allocation.utilisation),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: <Widget>[
            Text(
              '${Money(allocation.actualMinor, currency).format()} spent',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              'planned ${Money(allocation.plannedMinor, currency).format()}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        if (allocation.remainingMinor != 0 && !allocation.isOverBudget)
          Text(
            '${Money(allocation.remainingMinor, currency).format()} left',
            style: theme.textTheme.bodySmall,
          )
        else if (allocation.isOverBudget)
          Text(
            '${Money(-allocation.remainingMinor, currency).format()} over',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
      ],
    );
  }
}

class _AllocateSheet extends StatefulWidget {
  const _AllocateSheet({required this.currency});

  final String currency;

  @override
  State<_AllocateSheet> createState() => _AllocateSheetState();
}

class _AllocateSheetState extends State<_AllocateSheet> {
  ExpenseCategory _category = ExpenseCategory.food;
  final TextEditingController _amount = TextEditingController();
  bool _essential = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Allocate to a category',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.lg),
          DropdownButtonFormField<ExpenseCategory>(
            initialValue: _category,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Category'),
            items: <DropdownMenuItem<ExpenseCategory>>[
              for (final ExpenseCategory c in ExpenseCategory.values)
                DropdownMenuItem<ExpenseCategory>(
                  value: c,
                  child: Text(
                    '${c.emoji}  ${c.label}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (ExpenseCategory? c) =>
                setState(() => _category = c ?? _category),
          ),
          const SizedBox(height: AppSpacing.md),
          MoneyField(
            label: 'Planned amount',
            currency: widget.currency,
            controller: _amount,
          ),
          const SizedBox(height: AppSpacing.md),
          SwitchListTile(
            value: _essential,
            onChanged: (bool v) => setState(() => _essential = v),
            contentPadding: EdgeInsets.zero,
            title: const Text('Essential'),
            subtitle: const Text(
              'Marked as something most trips cannot avoid.',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: () {
              final int amount = Money.tryParse(
                _amount.text,
                widget.currency,
              ).minorUnits;
              if (amount <= 0) return;
              Navigator.of(context).pop((
                category: _category,
                planned: amount,
                essential: _essential,
              ));
            },
            child: const Text('Save allocation'),
          ),
        ],
      ),
    );
  }
}

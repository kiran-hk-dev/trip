import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/money/currency.dart';
import '../../core/money/split_engine.dart';
import '../../core/theme/app_theme.dart';
import '../../data/demo/demo_fixtures.dart';
import '../../data/models/expense.dart';
import '../../data/repositories.dart';
import '../../router/providers.dart';
import '../../shared/widgets/form_fields.dart';
import '../../shared/widgets/avatars.dart';
import '../../shared/widgets/common.dart';

/// Expense filters. Uses a [Notifier] rather than the legacy `StateProvider`
/// so it survives Riverpod 3 and can be extended later.
class ExpenseFiltersNotifier extends Notifier<ExpenseFilters> {
  @override
  ExpenseFilters build() => const ExpenseFilters();

  void set(ExpenseFilters filters) => state = filters;
  void clear() => state = const ExpenseFilters();
}

final expenseFiltersProvider =
    NotifierProvider.autoDispose<ExpenseFiltersNotifier, ExpenseFilters>(
      ExpenseFiltersNotifier.new,
    );

/// Trip-scoped expense list with filtering, search and sorting.
class ExpensesPage extends ConsumerStatefulWidget {
  const ExpensesPage({super.key, this.tripId});

  /// When null, the page asks the user to pick a trip.
  final String? tripId;

  @override
  ConsumerState<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends ConsumerState<ExpensesPage> {
  final bool _compact = false;
  int _offset = 0;
  static const int _pageSize = 30;
  final List<Expense> _loaded = <Expense>[];

  String? get _tripId => widget.tripId ?? ref.watch(selectedTripIdProvider);

  @override
  void initState() {
    super.initState();
    if (widget.tripId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(selectedTripIdProvider.notifier).clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? tripId = _tripId;
    final ExpenseFilters filters = ref.watch(expenseFiltersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: <Widget>[
          IconButton(
            onPressed: () => context.push('/expenses/new'),
            icon: const Icon(Icons.add),
            tooltip: 'Add expense',
          ),
        ],
      ),
      floatingActionButton: tripId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push('/trips/$tripId/expenses/new'),
              icon: const Icon(Icons.add),
              label: const Text('Add expense'),
            ),
      body: tripId == null
          ? const _PickTripPrompt()
          : Column(
              children: <Widget>[
                _FilterBar(tripId: tripId, filters: filters, compact: _compact),
                Expanded(child: _buildList(tripId, filters)),
              ],
            ),
    );
  }

  Widget _buildList(String tripId, ExpenseFilters filters) {
    if (AppConfig.demoMode) {
      final List<Expense> all = _applyDemoFilters(
        DemoFixtures.expensesFor(tripId),
        filters,
      );
      if (all.isEmpty) return const _EmptyExpenses();
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.huge,
        ),
        itemCount: all.length,
        itemBuilder: (BuildContext context, int i) =>
            ExpenseTile(expense: all[i]),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        _loaded.clear();
        setState(() => _offset = 0);
        ref.invalidate(
          expenseListProvider((tripId, _offset, _pageSize, filters.hashCode)),
        );
      },
      child: Consumer(
        builder: (BuildContext context, WidgetRef ref, Widget? _) {
          final AsyncValue<List<Expense>> async = ref.watch(
            expenseListProvider((tripId, _offset, _pageSize, filters.hashCode)),
          );
          return async.when(
            loading: () => ListView(
              padding: EdgeInsets.all(AppSpacing.lg),
              children: <Widget>[
                SkeletonCard(lines: 3),
                SkeletonCard(lines: 3),
              ],
            ),
            error: (Object err, StackTrace _) => ErrorStateView(
              message: '$err',
              onRetry: () => ref.invalidate(expenseListProvider),
            ),
            data: (List<Expense> page) {
              if (page.isEmpty && _offset == 0) return const _EmptyExpenses();
              final List<Expense> all = <Expense>[..._loaded, ...page];
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.huge,
                ),
                itemCount: all.length + (page.length >= _pageSize ? 1 : 0),
                itemBuilder: (BuildContext context, int i) {
                  if (i >= all.length) {
                    return const Padding(
                      padding: EdgeInsets.all(AppSpacing.xl),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return ExpenseTile(
                    expense: all[i],
                    showTripName: widget.tripId == null,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  List<Expense> _applyDemoFilters(List<Expense> all, ExpenseFilters filters) {
    final String userId = DemoFixtures.aliceId;
    List<Expense> result = all.where((Expense e) {
      if (filters.category != null && e.category != filters.category) {
        return false;
      }
      if (filters.paidBy != null && e.paidBy != filters.paidBy) return false;
      if (filters.participant != null &&
          !e.participantIds.contains(filters.participant)) {
        return false;
      }
      if (filters.fromDate != null &&
          e.expenseDate.isBefore(filters.fromDate!)) {
        return false;
      }
      if (filters.toDate != null && e.expenseDate.isAfter(filters.toDate!)) {
        return false;
      }
      if (filters.search.isNotEmpty &&
          !e.title.toLowerCase().contains(filters.search.toLowerCase())) {
        return false;
      }
      if (filters.onlyMine && e.myShareMinor == 0) return false;
      if (filters.onlyOwedByMe && !(e.myShareMinor > 0 && e.paidBy != userId)) {
        return false;
      }
      if (filters.onlyOwedToMe &&
          !(e.paidBy == userId && e.myShareMinor == 0)) {
        return false;
      }
      return true;
    }).toList();

    result.sort((Expense a, Expense b) {
      switch (filters.sort) {
        case ExpenseSort.dateAsc:
          return a.expenseDate.compareTo(b.expenseDate);
        case ExpenseSort.amountAsc:
          return a.baseAmountMinor.compareTo(b.baseAmountMinor);
        case ExpenseSort.amountDesc:
          return b.baseAmountMinor.compareTo(a.baseAmountMinor);
        case ExpenseSort.category:
          return a.category.id.compareTo(b.category.id);
        case ExpenseSort.dateDesc:
          return b.expenseDate.compareTo(a.expenseDate);
      }
    });

    return result;
  }
}

final expenseListProvider = FutureProvider.autoDispose
    .family<List<Expense>, (String, int, int, int)>((Ref ref, args) async {
      final (String tripId, int offset, int limit, _) = args;
      return ref
          .watch(tripRepositoryProvider)
          .expenses
          .listExpenses(
            tripId,
            filters: ref.watch(expenseFiltersProvider),
            limit: limit,
            offset: offset,
          )
          .then((ExpensePage page) => page.expenses);
    });

class _PickTripPrompt extends StatelessWidget {
  const _PickTripPrompt();

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.receipt_long_outlined,
      title: 'Pick a trip first',
      message: 'Expenses always belong to a trip, so the group and currency are unambiguous.',
      action: FilledButton(
        onPressed: () => context.go('/trips'),
        child: const Text('Go to My Trips'),
      ),
    );
  }
}

class _EmptyExpenses extends ConsumerWidget {
  const _EmptyExpenses();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool filtered = ref.watch(expenseFiltersProvider).hasActiveFilter;

    return EmptyState(
      icon: filtered
          ? Icons.filter_alt_off_outlined
          : Icons.receipt_long_outlined,
      title: filtered ? 'No matching expenses' : 'No expenses yet',
      message: filtered ? 'Try clearing a filter or widening the date range.' : 'Add your first expense. Every share is calculated by the database, so the balances always add up.',
      action: filtered
          ? OutlinedButton.icon(
              onPressed: () =>
                  ref.read(expenseFiltersProvider.notifier).clear(),
              icon: const Icon(Icons.filter_alt_off),
              label: const Text('Clear filters'),
            )
          : null,
    );
  }
}

class _FilterBar extends ConsumerStatefulWidget {
  const _FilterBar({
    required this.tripId,
    required this.filters,
    required this.compact,
  });

  final String tripId;
  final ExpenseFilters filters;
  final bool compact;

  @override
  ConsumerState<_FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends ConsumerState<_FilterBar> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final ExpenseFilters filters = widget.filters;
    final AsyncValue<List<TripMember>> members = ref.watch(
      membersProvider(widget.tripId),
    );

    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: DebouncedSearchField(
                    hint: 'Search expenses',
                    initialValue: filters.search,
                    onChanged: (String value) =>
                        _update(filters.copyWith(search: value)),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Badge(
                  isLabelVisible: filters.activeCount > 0,
                  label: Text('${filters.activeCount}'),
                  child: IconButton.filledTonal(
                    onPressed: () => setState(() => _expanded = !_expanded),
                    icon: Icon(_expanded ? Icons.expand_less : Icons.tune),
                    tooltip: 'Filters',
                  ),
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            duration: AppDurations.fast,
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: <Widget>[
                      FilterChip(
                        label: const Text('All'),
                        selected: !filters.hasActiveFilter,
                        onSelected: (_) => _update(filters.cleared()),
                      ),
                      FilterChip(
                        label: const Text('I paid'),
                        selected: filters.onlyOwedToMe,
                        onSelected: (bool v) =>
                            _update(filters.copyWith(onlyOwedToMe: v)),
                      ),
                      FilterChip(
                        label: const Text('I owe'),
                        selected: filters.onlyOwedByMe,
                        onSelected: (bool v) =>
                            _update(filters.copyWith(onlyOwedByMe: v)),
                      ),
                      FilterChip(
                        label: const Text('Shared with me'),
                        selected: filters.onlyMine,
                        onSelected: (bool v) =>
                            _update(filters.copyWith(onlyMine: v)),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<ExpenseCategory?>(
                    initialValue: filters.category,
                    isDense: true,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: <DropdownMenuItem<ExpenseCategory?>>[
                      const DropdownMenuItem<ExpenseCategory?>(
                        value: null,
                        child: Text('All categories'),
                      ),
                      for (final ExpenseCategory c in ExpenseCategory.values)
                        DropdownMenuItem<ExpenseCategory?>(
                          value: c,
                          child: Text('${c.emoji}  ${c.label}'),
                        ),
                    ],
                    onChanged: (ExpenseCategory? v) => _update(
                      filters.copyWith(category: v, clearCategory: v == null),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          initialValue: filters.paidBy,
                          isDense: true,
                          decoration: const InputDecoration(
                            labelText: 'Paid by',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          items: <DropdownMenuItem<String?>>[
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Anyone'),
                            ),
                            for (final TripMember m
                                in members.value ?? const <TripMember>[])
                              DropdownMenuItem<String?>(
                                value: m.userId,
                                child: Text(m.displayName),
                              ),
                          ],
                          onChanged: (String? v) => _update(
                            filters.copyWith(paidBy: v, clearPaidBy: v == null),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: DropdownButtonFormField<ExpenseSort>(
                          initialValue: filters.sort,
                          isDense: true,
                          decoration: const InputDecoration(
                            labelText: 'Sort',
                            prefixIcon: Icon(Icons.sort),
                          ),
                          items: <DropdownMenuItem<ExpenseSort>>[
                            for (final ExpenseSort s in ExpenseSort.values)
                              DropdownMenuItem<ExpenseSort>(
                                value: s,
                                child: Text(s.label),
                              ),
                          ],
                          onChanged: (ExpenseSort? v) =>
                              _update(filters.copyWith(sort: v)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: DateField(
                          label: 'From',
                          value:
                              filters.fromDate ??
                              DateTime.now().subtract(const Duration(days: 90)),
                          firstDate: DateTime(2020),
                          onChanged: (DateTime d) =>
                              _update(filters.copyWith(fromDate: d)),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: DateField(
                          label: 'To',
                          value: filters.toDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          onChanged: (DateTime d) =>
                              _update(filters.copyWith(toDate: d)),
                        ),
                      ),
                    ],
                  ),
                  if (filters.hasActiveFilter)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _update(filters.cleared()),
                        icon: const Icon(Icons.filter_alt_off, size: 16),
                        label: const Text('Clear filters'),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }

  void _update(ExpenseFilters next) {
    ref.read(expenseFiltersProvider.notifier).set(next);
  }
}

/// One expense row. Shows the original amount and, when it differs, the
/// converted trip-currency amount with the rate used.
class ExpenseTile extends ConsumerWidget {
  const ExpenseTile({
    super.key,
    required this.expense,
    this.showTripName = false,
  });

  final Expense expense;
  final bool showTripName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      onTap: () => _openDetail(context, expense),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            alignment: Alignment.center,
            child: Text(
              expense.category.emoji,
              style: const TextStyle(fontSize: 19),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  expense.title,
                  style: theme.textTheme.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  <String>[
                    expense.payerName ?? 'Someone',
                    expense.splitMethod == SplitMethod.none
                        ? 'Personal'
                        : expense.splitMethod.label,
                    expense.expenseDate.toIso8601String().substring(0, 10),
                  ].join(' · '),
                  style: theme.textTheme.bodySmall,
                ),
                if (expense.isForeignCurrency) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  StatusPill(
                    label:
                        '${expense.currency} ${Money(expense.amountMinor, expense.currency).format()} '
                        '→ ${expense.fxRateLabel}',
                    dense: true,
                    tone: StatusTone.info,
                    icon: Icons.currency_exchange,
                  ),
                ],
                if (expense.hasReceipt) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  Icon(
                    Icons.attach_file,
                    size: 13,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                Money(expense.amountMinor, expense.currency).format(),
                style: theme.textTheme.titleSmall,
              ),
              if (expense.myShareMinor > 0)
                Text(
                  'your share ${Money(expense.myShareMinor, expense.currency).format()}',
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openDetail(BuildContext context, Expense expense) async {
    await showAppSheet<void>(
      context: context,
      builder: (BuildContext context) => ExpenseDetailSheet(expense: expense),
    );
  }
}

/// Read-only breakdown of one expense, including each participant's share.
class ExpenseDetailSheet extends ConsumerWidget {
  const ExpenseDetailSheet({super.key, required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final List<ExpenseShareEntry> shares = expense.shares;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(expense.title, style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${expense.category.label} · ${expense.expenseDate.toIso8601String().substring(0, 10)}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.xl),
            DetailRow(
              label: 'Amount',
              value: Money(expense.amountMinor, expense.currency).format(),
              icon: Icons.payments_outlined,
            ),
            if (expense.isForeignCurrency) ...<Widget>[
              DetailRow(
                label: 'Converted at',
                value:
                    '${expense.fxRateLabel}'
                    '${expense.fxProvider == null ? '' : ' (${expense.fxProvider})'}',
                icon: Icons.currency_exchange,
              ),
              DetailRow(
                label: 'Trip currency amount',
                value: Money(
                  expense.baseAmountMinor,
                  expense.currency,
                ).format(),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'The original amount is stored as entered. Changing exchange rates later never '
                'rewrites this expense.',
                style: theme.textTheme.bodySmall,
              ),
            ],
            DetailRow(
              label: 'Paid by',
              value: expense.payerName ?? 'A member',
              icon: Icons.person_outline,
            ),
            DetailRow(
              label: 'Split method',
              value: expense.splitMethod.label,
              icon: Icons.call_split,
            ),
            if (expense.notes != null && expense.notes!.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Text(expense.notes!, style: theme.textTheme.bodyMedium),
            ],
            if (shares.isNotEmpty) ...<Widget>[
              const Divider(height: AppSpacing.xxl),
              Text('Who owes what', style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              for (final ExpenseShareEntry share in shares)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Row(
                    children: <Widget>[
                      MemberAvatar(
                        initials: (share.fullName ?? '?').substring(0, 1),
                        size: 26,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          share.fullName ?? 'Member',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      Text(
                        Money(share.amountMinor, expense.currency).format(),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              const Divider(height: AppSpacing.xl),
              Row(
                children: <Widget>[
                  Text('Total', style: theme.textTheme.titleSmall),
                  const Spacer(),
                  Text(
                    Money(
                      shares.fold<int>(
                        0,
                        (int s, ExpenseShareEntry e) => s + e.amountMinor,
                      ),
                      expense.currency,
                    ).format(),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Shares always sum to the expense total exactly — any rounding difference is '
                'distributed deterministically, never dropped.',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (expense.isPersonal) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              const InlineBanner(
                message: 'This is a personal expense, so it does not affect anyone else\'s balance.',
                tone: StatusTone.info,
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}

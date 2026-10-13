import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/config/app_config.dart';
import '../../core/money/currency.dart';
import '../../core/money/split_engine.dart';
import '../../core/theme/app_theme.dart';
import '../../data/demo/demo_fixtures.dart';
import '../../data/models/expense.dart';
import '../../data/models/misc.dart';
import '../../data/models/trip.dart';
import '../../data/repositories.dart';
import '../../router/providers.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/form_fields.dart';
import '../../shared/widgets/reports_export.dart';
import 'balances_page.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  DateTimeRange _range = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 365)),
    end: DateTime.now().add(const Duration(days: 365)),
  );
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Trip?> tripAsync = ref.watch(currentTripProvider);
    final Trip? trip = tripAsync.value;
    final String currency = trip?.baseCurrency ?? Currencies.defaultCode;

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Date range',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: DateField(
                        label: 'From',
                        value: _range.start,
                        firstDate: DateTime(2020),
                        onChanged: (DateTime d) => setState(
                          () =>
                              _range = DateTimeRange(start: d, end: _range.end),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: DateField(
                        label: 'To',
                        value: _range.end,
                        firstDate: DateTime(2020),
                        onChanged: (DateTime d) => setState(
                          () => _range = DateTimeRange(
                            start: _range.start,
                            end: d,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Reports always reflect the stored records, filtered to this range.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _CategoryChart(
            tripId: widget.tripId,
            currency: currency,
            range: _range,
          ),
          const SizedBox(height: AppSpacing.lg),
          _DailyChart(tripId: widget.tripId, currency: currency, range: _range),
          const SizedBox(height: AppSpacing.lg),
          _TravelerTable(tripId: widget.tripId, currency: currency),
          const SizedBox(height: AppSpacing.lg),
          _ExportCard(
            tripId: widget.tripId,
            tripName: trip?.name ?? 'Trip',
            currency: currency,
            range: _range,
            busy: _busy,
            onBusy: (bool v) => setState(() => _busy = v),
          ),
          const SizedBox(height: AppSpacing.huge),
        ],
      ),
    );
  }
}

/// Simple bar chart drawn with plain widgets so it needs no chart dependency
/// and stays crisp at every screen size.
class _BarChart extends StatelessWidget {
  const _BarChart({
    required this.items,
    required this.maxValue,
    this.height = 160,
  });

  final List<({String label, int value, String caption})> items;
  final int maxValue;
  final double height;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (items.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'No data in this range.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          for (final ({String caption, int value, String label}) item in items)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: maxValue == 0
                              ? 0
                              : item.value / maxValue,
                          child: Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.75,
                              ),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(AppRadius.sm),
                              ),
                            ),
                            width: double.infinity,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      item.label,
                      style: theme.textTheme.labelSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryChart extends ConsumerWidget {
  const _CategoryChart({
    required this.tripId,
    required this.currency,
    required this.range,
  });

  final String tripId;
  final String currency;
  final DateTimeRange range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Spending by category',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.md),
          FutureBuilder<List<CategoryTotal>>(
            future: _load(ref),
            builder:
                (
                  BuildContext context,
                  AsyncSnapshot<List<CategoryTotal>> snapshot,
                ) {
                  if (!snapshot.hasData) {
                    return const SkeletonBox(height: 160);
                  }
                  final List<CategoryTotal> totals = snapshot.data!;
                  if (totals.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                      child: Text('No spending in this range.'),
                    );
                  }
                  totals.sort(
                    (CategoryTotal a, CategoryTotal b) =>
                        b.amountMinor.compareTo(a.amountMinor),
                  );
                  final int max = totals
                      .map((CategoryTotal t) => t.amountMinor)
                      .reduce((int a, int b) => a > b ? a : b);
                  final int total = totals.fold<int>(
                    0,
                    (int sum, CategoryTotal t) => sum + t.amountMinor,
                  );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _BarChart(
                        height: 140,
                        maxValue: max,
                        items: <({String label, int value, String caption})>[
                          for (final CategoryTotal t in totals)
                            (
                              label: ExpenseCategory.fromId(t.category).emoji,
                              value: t.amountMinor,
                              caption: ExpenseCategory.fromId(t.category).label,
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      for (final CategoryTotal t in totals)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  ExpenseCategory.fromId(t.category).label,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                              Text(
                                Money(t.amountMinor, currency).format(),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              SizedBox(
                                width: 40,
                                child: Text(
                                  '${(t.amountMinor / total * 100).round()}%',
                                  textAlign: TextAlign.end,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
          ),
        ],
      ),
    );
  }

  Future<List<CategoryTotal>> _load(WidgetRef ref) {
    if (AppConfig.demoMode) {
      final List<CategoryTotal> totals = <CategoryTotal>[];
      final Map<String, int> sums = <String, int>{};
      for (final Expense e in DemoFixtures.expensesFor(tripId)) {
        if (e.isPersonal) continue;
        sums[e.category.id] = (sums[e.category.id] ?? 0) + e.baseAmountMinor;
      }
      for (final MapEntry<String, int> e in sums.entries) {
        totals.add(CategoryTotal(category: e.key, amountMinor: e.value));
      }
      return Future<List<CategoryTotal>>.value(totals);
    }
    return ref
        .read(tripRepositoryProvider)
        .budget
        .categoryTotals(tripId, from: range.start, to: range.end);
  }
}

class _DailyChart extends ConsumerWidget {
  const _DailyChart({
    required this.tripId,
    required this.currency,
    required this.range,
  });

  final String tripId;
  final String currency;
  final DateTimeRange range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Daily spending', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.md),
          FutureBuilder<List<DailyTotal>>(
            future: _load(ref),
            builder:
                (
                  BuildContext context,
                  AsyncSnapshot<List<DailyTotal>> snapshot,
                ) {
                  if (!snapshot.hasData) {
                    return const SkeletonBox(height: 160);
                  }
                  final List<DailyTotal> totals = snapshot.data!;
                  if (totals.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                      child: Text('No spending in this range.'),
                    );
                  }
                  final int max = totals
                      .map((DailyTotal t) => t.amountMinor)
                      .reduce((int a, int b) => a > b ? a : b);
                  final int average =
                      (totals.fold<int>(
                                0,
                                (int s, DailyTotal t) => s + t.amountMinor,
                              ) /
                              totals.length)
                          .round();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _BarChart(
                        height: 140,
                        maxValue: max,
                        items: <({String label, int value, String caption})>[
                          for (final DailyTotal t in totals)
                            (
                              label: '${t.date.day}',
                              value: t.amountMinor,
                              caption: t.date.toIso8601String().substring(
                                0,
                                10,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Average per day with spending: ${Money(average, currency).format()}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  );
                },
          ),
        ],
      ),
    );
  }

  Future<List<DailyTotal>> _load(WidgetRef ref) {
    if (AppConfig.demoMode) {
      final Map<String, int> sums = <String, int>{};
      for (final Expense e in DemoFixtures.expensesFor(tripId)) {
        final String key = e.expenseDate.toIso8601String().substring(0, 10);
        sums[key] = (sums[key] ?? 0) + e.baseAmountMinor;
      }
      return Future<List<DailyTotal>>.value(<DailyTotal>[
        for (final MapEntry<String, int> e in sums.entries)
          DailyTotal(date: DateTime.parse(e.key), amountMinor: e.value),
      ]);
    }
    return ref
        .read(tripRepositoryProvider)
        .budget
        .dailyTotals(tripId, from: range.start, to: range.end);
  }
}

class _TravelerTable extends ConsumerWidget {
  const _TravelerTable({required this.tripId, required this.currency});

  final String tripId;
  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Cost per traveller',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.md),
          FutureBuilder<List<TravelerTotal>>(
            future: AppConfig.demoMode
                ? Future<List<TravelerTotal>>.value(<TravelerTotal>[
                    for (final MemberBalance b in DemoFixtures.balancesFor(
                      tripId,
                    ))
                      TravelerTotal(
                        userId: b.memberId,
                        name:
                            DemoFixtures.profileById(b.memberId)?.fullName ??
                            'Traveller',
                        paidMinor: b.paidMinor,
                        shareMinor: b.owesMinor,
                        netMinor: b.netMinor,
                      ),
                  ])
                : ref
                      .read(tripRepositoryProvider)
                      .budget
                      .travelerTotals(tripId),
            builder:
                (
                  BuildContext context,
                  AsyncSnapshot<List<TravelerTotal>> snapshot,
                ) {
                  if (!snapshot.hasData) return const SkeletonBox(height: 120);
                  final List<TravelerTotal> totals = snapshot.data!;
                  if (totals.isEmpty) {
                    return const Text('No data yet.');
                  }
                  return Column(
                    children: <Widget>[
                      for (final TravelerTotal t in totals)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.xs,
                          ),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                flex: 3,
                                child: Text(
                                  t.name,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  Money(t.paidMinor, currency).format(),
                                  textAlign: TextAlign.end,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  Money(t.shareMinor, currency).format(),
                                  textAlign: TextAlign.end,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  Money(t.netMinor, currency).format(),
                                  textAlign: TextAlign.end,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: t.netMinor >= 0
                                            ? AppColors.positive
                                            : AppColors.danger,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const Divider(),
                      Row(
                        children: <Widget>[
                          const Expanded(
                            flex: 3,
                            child: Text(
                              'Column header',
                              style: TextStyle(fontSize: 0),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Paid',
                              textAlign: TextAlign.end,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Share',
                              textAlign: TextAlign.end,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Net',
                              textAlign: TextAlign.end,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
          ),
        ],
      ),
    );
  }
}

class _ExportCard extends ConsumerWidget {
  const _ExportCard({
    required this.tripId,
    required this.tripName,
    required this.currency,
    required this.range,
    required this.busy,
    required this.onBusy,
  });

  final String tripId;
  final String tripName;
  final String currency;
  final DateTimeRange range;
  final bool busy;
  final ValueChanged<bool> onBusy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Export', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Reports contain amounts and names of the people on this trip. '
            'They are not encrypted — share them carefully.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () => _export(context, ref, pdf: false),
                icon: const Icon(Icons.table_view_outlined, size: 18),
                label: const Text('CSV'),
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : () => _export(context, ref, pdf: true),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: const Text('PDF'),
              ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<List<List<String>>> _rows(WidgetRef ref) async {
    final List<List<String>> rows = <List<String>>[
      <String>[
        'Date',
        'Expense',
        'Category',
        'Paid by',
        'Amount',
        'Currency',
        'Base amount',
        'Base currency',
        'Split',
      ],
    ];

    List<Expense> expenses;
    if (AppConfig.demoMode) {
      expenses = DemoFixtures.expensesFor(tripId);
    } else {
      expenses = await ref
          .read(tripRepositoryProvider)
          .expenses
          .listExpenses(tripId, limit: 200)
          .then((ExpensePage p) => p.expenses);
    }

    for (final Expense e in expenses) {
      rows.add(<String>[
        e.expenseDate.toIso8601String().substring(0, 10),
        e.title,
        e.category.label,
        e.payerName ?? '',
        Money(e.amountMinor, e.currency).format(),
        e.currency,
        Money(e.baseAmountMinor, currency).format(),
        currency,
        e.splitMethod.label,
      ]);
    }

    rows.add(<String>['', '', '', '', '', '', '', '', '']);
    rows.add(<String>['Member', 'Paid', 'Own share', 'Net']);
    final List<MemberBalance> balances = AppConfig.demoMode
        ? DemoFixtures.balancesFor(tripId)
        : await ref.watch(balancesProvider(tripId).future);
    for (final MemberBalance b in balances) {
      rows.add(<String>[
        DemoFixtures.profileById(b.memberId)?.fullName ?? b.memberId,
        Money(b.paidMinor, currency).format(),
        Money(b.owesMinor, currency).format(),
        Money(b.netMinor, currency).format(),
      ]);
    }
    return rows;
  }

  Future<void> _export(
    BuildContext context,
    WidgetRef ref, {
    required bool pdf,
  }) async {
    onBusy(true);
    try {
      final List<List<String>> rows = await _rows(ref);
      final String stamp =
          '${range.start.toIso8601String().substring(0, 10)}_${range.end.toIso8601String().substring(0, 10)}';

      if (!pdf) {
        await ExportService.shareCsv('tripsplit_${tripId}_$stamp.csv', rows);
      } else {
        final pw.Document doc = ExportService.buildDocument(
          '$tripName — expenses',
        );
        doc.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(32),
            header: (pw.Context _) => ExportService.reportHeader(
              tripName,
              'Expense report · $stamp · base currency $currency',
            ),
            build: (pw.Context _) => <pw.Widget>[
              ExportService.note(
                'Generated from stored records. Amounts are shown in the currency they were '
                'recorded in, alongside the trip base-currency total.',
              ),
              ExportService.table(rows),
            ],
          ),
        );
        await ExportService.sharePdf('tripsplit_${tripId}_$stamp.pdf', doc);
      }

      if (context.mounted) showFeedback(context, 'Report ready to share.');
    } catch (err) {
      if (context.mounted) {
        showFeedback(
          context,
          'Could not build the report: $err',
          isError: true,
        );
      }
    } finally {
      onBusy(false);
    }
  }
}

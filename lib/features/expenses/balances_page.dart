import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/money/currency.dart';
import '../../core/money/split_engine.dart';
import '../../core/theme/app_theme.dart';
import '../../data/demo/demo_fixtures.dart';
import '../../data/models/expense.dart';
import '../../data/models/trip.dart';
import '../../data/supabase_service.dart';
import '../../router/providers.dart';
import '../../shared/widgets/avatars.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/form_fields.dart';

final balancesProvider = FutureProvider.autoDispose
    .family<List<MemberBalance>, String>((Ref ref, String tripId) async {
      if (AppConfig.demoMode) return DemoFixtures.balancesFor(tripId);
      return ref.watch(tripRepositoryProvider).expenses.balances(tripId);
    });

final suggestionsProvider = FutureProvider.autoDispose
    .family<List<SettlementTransfer>, String>((Ref ref, String tripId) async {
      if (AppConfig.demoMode) return DemoFixtures.suggestionsFor(tripId);
      return ref
          .watch(tripRepositoryProvider)
          .expenses
          .suggestedSettlements(tripId);
    });

final settlementsProvider = FutureProvider.autoDispose
    .family<List<Settlement>, String>((Ref ref, String tripId) async {
      if (AppConfig.demoMode) return DemoFixtures.settlementsFor(tripId);
      return ref.watch(tripRepositoryProvider).expenses.listSettlements(tripId);
    });

class BalancesPage extends ConsumerWidget {
  const BalancesPage({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Trip?> tripAsync = ref.watch(currentTripProvider);
    final String currency =
        tripAsync.value?.baseCurrency ?? Currencies.defaultCode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Balances'),
        actions: <Widget>[
          IconButton(
            onPressed: () => context.push('/trips/$tripId/reports'),
            icon: const Icon(Icons.bar_chart_outlined),
            tooltip: 'Reports',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(balancesProvider(tripId));
          ref.invalidate(suggestionsProvider(tripId));
          ref.invalidate(settlementsProvider(tripId));
          await ref.read(balancesProvider(tripId).future);
        },
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            const InlineBanner(
              message: 'A settlement you record here is a note that a payment happened. TripSplit does not move money and cannot confirm that money arrived — that needs a bank or payment provider.',
              tone: StatusTone.info,
              icon: Icons.info_outline,
            ),
            const SizedBox(height: AppSpacing.lg),
            _BalanceSection(tripId: tripId, currency: currency),
            const SizedBox(height: AppSpacing.xl),
            _SuggestionSection(tripId: tripId, currency: currency),
            const SizedBox(height: AppSpacing.xl),
            _HistorySection(tripId: tripId, currency: currency),
            const SizedBox(height: AppSpacing.huge),
          ],
        ),
      ),
    );
  }
}

class _BalanceSection extends ConsumerWidget {
  const _BalanceSection({required this.tripId, required this.currency});

  final String tripId;
  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<MemberBalance>> async = ref.watch(
      balancesProvider(tripId),
    );
    final AsyncValue<List<TripMember>> membersAsync = ref.watch(
      membersProvider(tripId),
    );
    final Map<String, String> names = <String, String>{
      for (final TripMember m in membersAsync.value ?? const <TripMember>[])
        m.userId: m.displayName,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader(
          title: 'Net balances',
          subtitle: 'Paid, owed and settled per person',
          padding: EdgeInsets.only(bottom: AppSpacing.md),
        ),
        async.when(
          loading: () => const SkeletonCard(lines: 3),
          error: (Object err, StackTrace _) => ErrorStateView(message: '$err'),
          data: (List<MemberBalance> balances) {
            if (balances.isEmpty) {
              return const AppCard(
                child: EmptyState(
                  compact: true,
                  icon: Icons.balance_outlined,
                  title: 'No balances yet',
                  message: 'Add expenses to see who owes whom.',
                ),
              );
            }
            final List<MemberBalance> sorted = <MemberBalance>[...balances]
              ..sort(
                (MemberBalance a, MemberBalance b) =>
                    b.netMinor.compareTo(a.netMinor),
              );

            return Column(
              children: <Widget>[
                for (final MemberBalance b in sorted)
                  AppCard(
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Column(
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            MemberAvatar(
                              initials: (names[b.memberId] ?? '?').substring(
                                0,
                                1,
                              ),
                              size: 40,
                            ),
                            const SizedBox(width: AppSpacing.lg),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    names[b.memberId] ?? 'Member',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall,
                                  ),
                                  Text(
                                    b.netMinor == 0
                                        ? 'Settled up'
                                        : b.netMinor > 0
                                        ? 'Is owed'
                                        : 'Owes',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              Money(
                                b.netMinor,
                                currency,
                              ).format(withCode: true),
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: b.netMinor > 0
                                        ? AppColors.positive
                                        : b.netMinor < 0
                                        ? AppColors.danger
                                        : null,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                        const Divider(height: AppSpacing.xl),
                        Row(
                          children: <Widget>[
                            _MiniStat(
                              label: 'Paid',
                              value: Money(b.paidMinor, currency).format(),
                            ),
                            _MiniStat(
                              label: 'Own share',
                              value: Money(b.owesMinor, currency).format(),
                            ),
                            _MiniStat(
                              label: 'Settled in',
                              value: Money(b.settledInMinor, currency).format(),
                              color: b.settledInMinor > 0
                                  ? AppColors.positive
                                  : null,
                            ),
                            _MiniStat(
                              label: 'Settled out',
                              value: Money(
                                b.settledOutMinor,
                                currency,
                              ).format(),
                              color: b.settledOutMinor > 0
                                  ? AppColors.danger
                                  : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: theme.textTheme.bodySmall, maxLines: 1),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _SuggestionSection extends ConsumerWidget {
  const _SuggestionSection({required this.tripId, required this.currency});

  final String tripId;
  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<SettlementTransfer>> async = ref.watch(
      suggestionsProvider(tripId),
    );
    final AsyncValue<List<TripMember>> membersAsync = ref.watch(
      membersProvider(tripId),
    );
    final Map<String, String> names = <String, String>{
      for (final TripMember m in membersAsync.value ?? const <TripMember>[])
        m.userId: m.displayName,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(
          title: 'Who owes whom',
          subtitle: 'Fewest transfers that clear every balance',
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          action: IconButton(
            onPressed: () => context.push('/trips/$tripId/reports'),
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export settlement report',
          ),
        ),
        async.when(
          loading: () => const SkeletonCard(lines: 2),
          error: (Object err, StackTrace _) => ErrorStateView(message: '$err'),
          data: (List<SettlementTransfer> transfers) {
            if (transfers.isEmpty) {
              return const AppCard(
                child: EmptyState(
                  compact: true,
                  icon: Icons.celebration_outlined,
                  title: 'Everyone is square',
                  message: 'No outstanding transfers for this trip.',
                ),
              );
            }
            return Column(
              children: <Widget>[
                for (final SettlementTransfer t in transfers)
                  AppCard(
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Column(
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: _Party(
                                name: names[t.fromMemberId] ?? 'Member',
                                caption: 'pays',
                              ),
                            ),
                            const Icon(Icons.arrow_forward, size: 18),
                            Expanded(
                              child: _Party(
                                name: names[t.toMemberId] ?? 'Member',
                                caption: 'receives',
                                alignEnd: true,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Text(
                              Money(t.amountMinor, currency).format(),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _record(context, ref, t),
                            icon: const Icon(
                              Icons.check_circle_outline,
                              size: 18,
                            ),
                            label: const Text('Record this payment'),
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
    );
  }

  Future<void> _record(
    BuildContext context,
    WidgetRef ref,
    SettlementTransfer transfer,
  ) async {
    final SettlementDraft? draft = await showAppSheet<SettlementDraft>(
      context: context,
      builder: (BuildContext context) => SettlementSheet(
        fromMemberId: transfer.fromMemberId,
        toMemberId: transfer.toMemberId,
        amountMinor: transfer.amountMinor,
        currency: currency,
        tripId: tripId,
      ),
    );
    if (draft == null) return;
    if (!context.mounted) return;

    if (AppConfig.demoMode) {
      showFeedback(
        context,
        'Recording a settlement is disabled in demo mode.',
        isError: true,
      );
      return;
    }

    try {
      await ref
          .read(tripRepositoryProvider)
          .expenses
          .recordSettlement(
            tripId: tripId,
            fromUserId: draft.fromUserId,
            toUserId: draft.toUserId,
            amountMinor: draft.amountMinor,
            currency: currency,
            method: draft.method,
            reference: draft.reference,
            notes: draft.notes,
            settledAt: draft.settledAt,
            idempotencyKey: draft.idempotencyKey,
          );
      ref.invalidate(balancesProvider(tripId));
      ref.invalidate(suggestionsProvider(tripId));
      ref.invalidate(settlementsProvider(tripId));
      if (context.mounted) {
        showFeedback(
          context,
          'Settlement recorded. It is marked "Recorded" until a payment provider confirms it.',
        );
      }
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

class _Party extends StatelessWidget {
  const _Party({
    required this.name,
    required this.caption,
    this.alignEnd = false,
  });

  final String name;
  final String caption;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: <Widget>[
        Text(caption, style: theme.textTheme.bodySmall),
        Text(
          name,
          style: theme.textTheme.titleSmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _HistorySection extends ConsumerWidget {
  const _HistorySection({required this.tripId, required this.currency});

  final String tripId;
  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Settlement>> async = ref.watch(
      settlementsProvider(tripId),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader(
          title: 'Settlement history',
          subtitle: 'Recorded payments, with their verification status',
          padding: EdgeInsets.only(bottom: AppSpacing.md),
        ),
        async.when(
          loading: () => const SkeletonCard(lines: 2),
          error: (Object err, StackTrace _) => ErrorStateView(message: '$err'),
          data: (List<Settlement> settlements) {
            if (settlements.isEmpty) {
              return const AppCard(
                child: EmptyState(
                  compact: true,
                  icon: Icons.history,
                  title: 'No settlements yet',
                  message: 'Recorded payments will be listed here.',
                ),
              );
            }
            return Column(
              children: <Widget>[
                for (final Settlement s in settlements)
                  AppCard(
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                '${s.fromName ?? 'A member'} → ${s.toName ?? 'a member'}',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                            Text(
                              Money(s.baseAmountMinor, currency).format(),
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: <Widget>[
                            StatusPill(
                              label: s.status.label,
                              dense: true,
                              icon: s.isVerified
                                  ? Icons.verified
                                  : s.status == SettlementStatus.disputed
                                  ? Icons.report_outlined
                                  : Icons.edit_note,
                              tone: s.isVerified
                                  ? StatusTone.positive
                                  : s.status == SettlementStatus.disputed
                                  ? StatusTone.danger
                                  : StatusTone.warning,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              s.settledAt.toIso8601String().substring(0, 10),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const Spacer(),
                            Text(
                              s.method.label,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          s.status.explanation,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (s.reference != null)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.sm),
                            child: Text(
                              'Reference: ${s.reference}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(fontFamily: 'monospace'),
                            ),
                          ),
                        if (s.notes != null && s.notes!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.sm),
                            child: Text(
                              s.notes!,
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
    );
  }
}

class SettlementDraft {
  const SettlementDraft({
    required this.fromUserId,
    required this.toUserId,
    required this.amountMinor,
    required this.method,
    required this.reference,
    required this.notes,
    required this.settledAt,
    required this.idempotencyKey,
  });

  final String fromUserId;
  final String toUserId;
  final int amountMinor;
  final SettlementMethod method;
  final String? reference;
  final String? notes;
  final DateTime settledAt;

  /// Prevents a retried request from recording the same payment twice.
  final String idempotencyKey;
}

class SettlementSheet extends StatefulWidget {
  const SettlementSheet({
    super.key,
    required this.fromMemberId,
    required this.toMemberId,
    required this.amountMinor,
    required this.currency,
    required this.tripId,
  });

  final String fromMemberId;
  final String toMemberId;
  final int amountMinor;
  final String currency;
  final String tripId;

  @override
  State<SettlementSheet> createState() => _SettlementSheetState();
}

class _SettlementSheetState extends State<SettlementSheet> {
  late final TextEditingController _amount;
  late final TextEditingController _reference;
  late final TextEditingController _notes;
  late SettlementMethod _method;
  late DateTime _date;
  String? _error;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(
      text: Money(widget.amountMinor, widget.currency).format(locale: 'en'),
    );
    _reference = TextEditingController();
    _notes = TextEditingController();
    _method = SettlementMethod.bankTransfer;
    _date = DateTime.now();
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Record a settlement',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'This records that someone said they paid. It does not send money and does not '
              'confirm that money arrived.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_error != null) ...<Widget>[
              InlineBanner(message: _error!, tone: StatusTone.danger),
              const SizedBox(height: AppSpacing.lg),
            ],
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixIcon: const Icon(Icons.payments_outlined),
                helperText:
                    'Maximum valid is ${Money(widget.amountMinor, widget.currency).format()} for this pair.',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            DropdownButtonFormField<SettlementMethod>(
              initialValue: _method,
              decoration: const InputDecoration(
                labelText: 'How was it paid?',
                prefixIcon: Icon(Icons.account_balance_outlined),
              ),
              items: <DropdownMenuItem<SettlementMethod>>[
                for (final SettlementMethod m in SettlementMethod.values)
                  DropdownMenuItem<SettlementMethod>(
                    value: m,
                    child: Text(m.label),
                  ),
              ],
              onChanged: (SettlementMethod? m) =>
                  setState(() => _method = m ?? _method),
            ),
            const SizedBox(height: AppSpacing.lg),
            DateField(
              label: 'Date paid',
              value: _date,
              firstDate: DateTime(2020),
              onChanged: (DateTime d) => setState(() => _date = d),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _reference,
              decoration: const InputDecoration(
                labelText: 'Reference',
                hintText: 'Bank reference, UPI ID, anything you were given',
                prefixIcon: Icon(Icons.tag),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _notes,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _submit,
              child: const Text('Record settlement'),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final int amount = Money.tryParse(_amount.text, widget.currency).minorUnits;
    if (amount <= 0) {
      setState(() => _error = 'Enter an amount greater than zero.');
      return;
    }
    if (amount > widget.amountMinor) {
      setState(() {
        _error =
            'That is more than this person currently owes on this pair. '
            'The maximum is ${Money(widget.amountMinor, widget.currency).format()}.';
      });
      return;
    }

    Navigator.of(context).pop(
      SettlementDraft(
        fromUserId: widget.fromMemberId,
        toUserId: widget.toMemberId,
        amountMinor: amount,
        method: _method,
        reference: _reference.text.trim().isEmpty
            ? null
            : _reference.text.trim(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        settledAt: _date,
        idempotencyKey:
            '${widget.tripId}:${widget.fromMemberId}:${widget.toMemberId}:'
            '${_date.toIso8601String().substring(0, 10)}:$amount',
      ),
    );
  }
}

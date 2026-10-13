import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/money/currency.dart';
import '../../core/money/split_engine.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/expense.dart';
import '../../data/models/misc.dart';
import '../../data/models/trip.dart';
import '../../data/repositories.dart';
import '../../data/supabase_service.dart';
import '../../router/providers.dart';
import '../../shared/widgets/avatars.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/form_fields.dart';
import 'expenses_page.dart';

/// Add or edit an expense.
///
/// The screen previews the split locally with the same [SplitEngine] the
/// database uses, then sends only the user's *intent* (participants, method,
/// weights) — the server computes and stores the authoritative shares.
class AddExpensePage extends ConsumerStatefulWidget {
  const AddExpensePage({super.key, this.tripId, this.expense});

  final String? tripId;
  final Expense? expense;

  @override
  ConsumerState<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends ConsumerState<AddExpensePage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _notes = TextEditingController();
  final Map<String, TextEditingController> _exactControllers =
      <String, TextEditingController>{};
  final Map<String, TextEditingController> _percentControllers =
      <String, TextEditingController>{};
  final Map<String, int> _weights = <String, int>{};

  String? _tripId;
  String _currency = Currencies.defaultCode;
  String _payerId = '';
  ExpenseCategory _category = ExpenseCategory.food;
  SplitMethod _method = SplitMethod.equal;
  Set<String> _participants = <String>{};
  DateTime _date = DateTime.now();
  bool _isPersonal = false;
  bool _busy = false;
  String? _error;

  CachedRate? _fxRate;
  bool _converting = false;

  bool get _isEditing => widget.expense != null;

  @override
  void initState() {
    super.initState();
    _tripId = widget.tripId;
    final Expense? e = widget.expense;
    if (e != null) {
      _title.text = e.title;
      _amount.text = Money(e.amountMinor, e.currency).format(locale: 'en');
      _notes.text = e.notes ?? '';
      _currency = e.currency;
      _payerId = e.paidBy;
      _category = e.category;
      _method = e.splitMethod;
      _participants = e.participantIds.toSet();
      _date = e.expenseDate;
      _isPersonal = e.isPersonal;
    }
    _amount.addListener(_recalculate);
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _notes.dispose();
    for (final TextEditingController c in _exactControllers.values) {
      c.dispose();
    }
    for (final TextEditingController c in _percentControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _recalculate() => setState(() {});

  /// The live preview. Returns null when the inputs are not yet valid.
  SplitOutcome? get _preview {
    final List<String> ids = _isPersonal
        ? <String>[if (_payerId.isNotEmpty) _payerId]
        : _participants.toList();
    if (ids.isEmpty) return null;
    final int total = Money.tryParse(_amount.text, _currency).minorUnits;
    if (total <= 0) return null;

    try {
      return SplitEngine.split(
        method: _method,
        totalMinor: total,
        currencyCode: _currency,
        participantIds: ids,
        exactAmounts: <String, int>{
          for (final MapEntry<String, TextEditingController> e
              in _exactControllers.entries)
            e.key: Money.tryParse(e.value.text, _currency).minorUnits,
        },
        percentages: <String, double>{
          for (final MapEntry<String, TextEditingController> e
              in _percentControllers.entries)
            e.key: double.tryParse(e.value.text.trim()) ?? 0,
        },
        weights: _weights,
      );
    } on SplitValidationException {
      return null;
    }
  }

  /// Conversion into the trip's base currency, when they differ.
  ({int baseMinor, double rate, String provider})? get _conversion {
    final int total = Money.tryParse(_amount.text, _currency).minorUnits;
    if (total <= 0 || _fxRate == null) return null;
    return (
      baseMinor: _fxRate!.convert(Money(total, _currency)).minorUnits,
      rate: _fxRate!.rate,
      provider: _fxRate!.provider,
    );
  }

  Future<void> _convert(String targetCurrency) async {
    setState(() {
      _converting = true;
      _error = null;
    });
    try {
      final RateResult result = await ref
          .read(tripRepositoryProvider)
          .converter
          .rates(_currency, <String>[targetCurrency]);
      final CachedRate? rate = result.rates
          .where((CachedRate r) => r.quote == targetCurrency)
          .firstOrNull;
      if (rate == null) {
        setState(
          () => _error = 'No rate available for $targetCurrency right now.',
        );
        return;
      }
      setState(() => _fxRate = rate);
      if (!mounted) return;
      showFeedback(
        context,
        result.fromCache
            ? 'Using a cached rate from ${rate.ageLabel}. Not a live quote.'
            : 'Rate from ${rate.provider}, updated ${rate.ageLabel}.',
      );
    } catch (err) {
      if (mounted) {
        setState(
          () => _error = err is RepositoryException ? err.message : '$err',
        );
      }
    } finally {
      if (mounted) setState(() => _converting = false);
    }
  }

  Future<void> _save(List<TripMember> members) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_tripId == null) {
      setState(() => _error = 'Choose a trip for this expense.');
      return;
    }
    if (!_isPersonal && _participants.isEmpty) {
      setState(() => _error = 'Select at least one participant.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final int amountMinor = Money.tryParse(_amount.text, _currency).minorUnits;
    if (amountMinor <= 0) {
      setState(() {
        _busy = false;
        _error = 'Enter an amount greater than zero.';
      });
      return;
    }

    final ({int baseMinor, double rate, String provider})? conv = _conversion;

    try {
      final ExpenseRepository repo = ref.read(tripRepositoryProvider).expenses;
      if (_isEditing) {
        await repo.updateExpense(
          expenseId: widget.expense!.id,
          title: _title.text.trim(),
          amountMinor: amountMinor,
          currency: _currency,
          baseAmountMinor: conv?.baseMinor,
          fxRate: conv?.rate,
          fxProvider: conv?.provider,
          category: _category,
          expenseDate: _date,
          paidBy: _payerId,
          participantIds: _participants.toList(),
          exactAmounts: _method == SplitMethod.exact
              ? <String, int>{
                  for (final MapEntry<String, TextEditingController> e
                      in _exactControllers.entries)
                    e.key: Money.tryParse(e.value.text, _currency).minorUnits,
                }
              : const <String, int>{},
          percentages: _method == SplitMethod.percentage
              ? <String, double>{
                  for (final MapEntry<String, TextEditingController> e
                      in _percentControllers.entries)
                    e.key: double.tryParse(e.value.text.trim()) ?? 0,
                }
              : const <String, double>{},
          weights: _method == SplitMethod.shares
              ? _weights
              : const <String, int>{},
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        );
      } else {
        await repo.createExpense(
          tripId: _tripId!,
          title: _title.text.trim(),
          amountMinor: amountMinor,
          currency: _currency,
          category: _category,
          expenseDate: _date,
          paidBy: _payerId,
          splitMethod: _method,
          participantIds: _participants.toList(),
          exactAmounts: _method == SplitMethod.exact
              ? <String, int>{
                  for (final MapEntry<String, TextEditingController> e
                      in _exactControllers.entries)
                    e.key: Money.tryParse(e.value.text, _currency).minorUnits,
                }
              : const <String, int>{},
          percentages: _method == SplitMethod.percentage
              ? <String, double>{
                  for (final MapEntry<String, TextEditingController> e
                      in _percentControllers.entries)
                    e.key: double.tryParse(e.value.text.trim()) ?? 0,
                }
              : const <String, double>{},
          weights: _method == SplitMethod.shares
              ? _weights
              : const <String, int>{},
          isPersonal: _isPersonal,
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          baseAmountMinor: conv?.baseMinor,
          fxRate: conv?.rate,
          fxProvider: conv?.provider,
        );
      }

      ref.invalidate(expenseFiltersProvider);
      ref.invalidate(tripsProvider);
      if (!mounted) return;
      showFeedback(context, _isEditing ? 'Expense updated.' : 'Expense added.');
      context.pop();
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = err is RepositoryException
            ? err.message
            : 'Could not save the expense.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? tripId = _tripId ?? ref.watch(selectedTripIdProvider);

    if (tripId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Add expense')),
        body: const EmptyState(
          icon: Icons.luggage_outlined,
          title: 'Choose a trip first',
          message: 'Every expense belongs to a trip so the group and currency are clear.',
        ),
      );
    }

    final AsyncValue<Trip?> tripAsync = ref.watch(currentTripProvider);
    final Trip? trip = tripAsync.value;
    final AsyncValue<List<TripMember>> membersAsync = ref.watch(
      membersProvider(tripId),
    );

    if (_tripId == null) {
      _tripId = tripId;
      if (_payerId.isEmpty &&
          _currency == Currencies.defaultCode &&
          trip != null) {
        _currency = trip.baseCurrency;
      }
    }

    final List<TripMember> members = membersAsync.value ?? const <TripMember>[];
    if (_payerId.isEmpty && members.isNotEmpty) {
      _payerId = members.first.userId;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit expense' : 'Add expense'),
        actions: <Widget>[
          if (_isEditing)
            IconButton(
              onPressed: () => _delete(context, tripId),
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete expense',
            ),
        ],
      ),
      body: membersAsync.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.huge,
                ),
                children: <Widget>[
                  if (_error != null) ...<Widget>[
                    InlineBanner(message: _error!, tone: StatusTone.danger),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  TextFormField(
                    controller: _title,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'What was it for?',
                      hintText: 'Dinner at K Lok',
                      prefixIcon: Icon(Icons.title),
                    ),
                    validator: (String? v) => (v == null || v.trim().length < 2)
                        ? 'Give the expense a name.'
                        : null,
                  ),

                  const SizedBox(height: AppSpacing.lg),
                  MoneyField(
                    label: 'Amount',
                    currency: _currency,
                    controller: _amount,
                    onCurrencyChanged: (String c) {
                      setState(() {
                        _currency = c;
                        _fxRate = null;
                      });
                    },
                    helperText: 'Enter what was actually paid.',
                  ),

                  if (trip != null &&
                      _currency != trip.baseCurrency) ...<Widget>[
                    const SizedBox(height: AppSpacing.md),
                    _ConversionRow(
                      tripCurrency: trip.baseCurrency,
                      conversion: _conversion,
                      converting: _converting,
                      onConvert: () => _convert(trip.baseCurrency),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.lg),
                  DropdownButtonFormField<ExpenseCategory>(
                    initialValue: _category,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
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

                  const SizedBox(height: AppSpacing.lg),
                  DateField(
                    label: 'Date',
                    value: _date,
                    firstDate: DateTime(2020),
                    onChanged: (DateTime d) => setState(() => _date = d),
                  ),

                  const SizedBox(height: AppSpacing.lg),
                  DropdownButtonFormField<String>(
                    initialValue:
                        members.any((TripMember m) => m.userId == _payerId)
                        ? _payerId
                        : (members.isNotEmpty ? members.first.userId : null),
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Who paid?',
                      helperText: 'They are credited the full amount.',
                      prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                    ),
                    items: <DropdownMenuItem<String>>[
                      for (final TripMember m in members)
                        DropdownMenuItem<String>(
                          value: m.userId,
                          child: Text(
                            m.displayName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (String? v) =>
                        setState(() => _payerId = v ?? _payerId),
                  ),

                  const SizedBox(height: AppSpacing.xl),
                  SwitchListTile(
                    value: _isPersonal,
                    onChanged: (bool v) => setState(() {
                      _isPersonal = v;
                      if (v) {
                        _participants = <String>{
                          if (_payerId.isNotEmpty) _payerId,
                        };
                      }
                    }),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Personal expense'),
                    subtitle: const Text(
                      'Only you are involved. It will not affect anyone else\'s balance.',
                    ),
                  ),

                  if (!_isPersonal) ...<Widget>[
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'How should it be split?',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: <Widget>[
                        for (final SplitMethod m in <SplitMethod>[
                          SplitMethod.equal,
                          SplitMethod.exact,
                          SplitMethod.percentage,
                          SplitMethod.shares,
                        ])
                          ChoiceChip(
                            selected: _method == m,
                            onSelected: (_) => setState(() {
                              _method = m;
                              _ensureControllers(members);
                            }),
                            label: Text(m.label),
                          ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'Who was involved?',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    MemberPicker(
                      members: <({String id, String? subtitle, String name})>[
                        for (final TripMember m in members)
                          (
                            id: m.userId,
                            name: m.displayName,
                            subtitle: m.role.label,
                          ),
                      ],
                      selectedIds: _participants,
                      onChanged: (Set<String> next) => setState(() {
                        _participants = next;
                        _ensureControllers(members);
                      }),
                      helperText: _participants.length < members.length
                          ? 'Only the selected people share this cost.'
                          : null,
                    ),

                    if (_method != SplitMethod.equal) ...<Widget>[
                      const SizedBox(height: AppSpacing.xl),
                      _MethodInputs(
                        method: _method,
                        members: members,
                        participants: _participants,
                        currency: _currency,
                        totalMinor: Money.tryParse(
                          _amount.text,
                          _currency,
                        ).minorUnits,
                        exactControllers: _exactControllers,
                        percentControllers: _percentControllers,
                        weights: _weights,
                        onChanged: _recalculate,
                      ),
                    ],

                    const SizedBox(height: AppSpacing.xl),
                    _SplitPreview(
                      preview: _preview,
                      currency: _currency,
                      payerId: _payerId,
                      members: members,
                      isPersonal: _isPersonal,
                    ),
                  ],

                  const SizedBox(height: AppSpacing.xl),
                  TextFormField(
                    controller: _notes,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      hintText: 'Anything the group should know',
                      prefixIcon: Icon(Icons.notes),
                      alignLabelWithHint: true,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xxl),
                  FilledButton(
                    onPressed: _busy ? null : () => _save(members),
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isEditing ? 'Save changes' : 'Add expense'),
                  ),
                ],
              ),
            ),
    );
  }

  void _ensureControllers(List<TripMember> members) {
    final List<String> ids = _participants.toList()..sort();
    for (final String id in ids) {
      _weights.putIfAbsent(id, () => 1);
      _exactControllers.putIfAbsent(id, () => TextEditingController(text: ''));
      _percentControllers.putIfAbsent(
        id,
        () => TextEditingController(
          text: _participants.isEmpty
              ? ''
              : (100 / _participants.length).toStringAsFixed(2),
        ),
      );
    }
    _exactControllers.removeWhere((String k, _) => !ids.contains(k));
    _percentControllers.removeWhere((String k, _) => !ids.contains(k));
    _weights.removeWhere((String k, _) => !ids.contains(k));
  }

  Future<void> _delete(BuildContext context, String tripId) async {
    final bool ok = await confirmDestructive(
      context,
      title: 'Delete this expense?',
      message: 'Balances will be recalculated for everyone. The entry stays in the activity log so the change is explainable.',
      confirmLabel: 'Delete expense',
    );
    if (!ok) return;
    try {
      await ref
          .read(tripRepositoryProvider)
          .expenses
          .deleteExpense(widget.expense!.id);
      ref.invalidate(expenseFiltersProvider);
      if (context.mounted) {
        showFeedback(context, 'Expense deleted.');
        context.pop();
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

class _ConversionRow extends StatelessWidget {
  const _ConversionRow({
    required this.tripCurrency,
    required this.conversion,
    required this.converting,
    required this.onConvert,
  });

  final String tripCurrency;
  final ({int baseMinor, double rate, String provider})? conversion;
  final bool converting;
  final VoidCallback onConvert;

  @override
  Widget build(BuildContext context) {
    if (conversion == null) {
      return OutlinedButton.icon(
        onPressed: converting ? null : onConvert,
        icon: converting
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.currency_exchange, size: 18),
        label: Text(
          converting ? 'Converting…' : 'Get a rate into $tripCurrency',
        ),
      );
    }

    return InlineBanner(
      tone: StatusTone.info,
      icon: Icons.currency_exchange,
      message:
          'Recorded in the original currency and converted at ${conversion!.rate.toStringAsFixed(4)} '
          '(from ${conversion!.provider}). The rate is stored with the expense so it can be audited later.',
    );
  }
}

class _MethodInputs extends StatelessWidget {
  const _MethodInputs({
    required this.method,
    required this.members,
    required this.participants,
    required this.currency,
    required this.totalMinor,
    required this.exactControllers,
    required this.percentControllers,
    required this.weights,
    required this.onChanged,
  });

  final SplitMethod method;
  final List<TripMember> members;
  final Set<String> participants;
  final String currency;
  final int totalMinor;
  final Map<String, TextEditingController> exactControllers;
  final Map<String, TextEditingController> percentControllers;
  final Map<String, int> weights;
  final VoidCallback onChanged;

  String _name(String id) => members
      .firstWhere(
        (TripMember m) => m.userId == id,
        orElse: () => TripMember(userId: id, tripId: ''),
      )
      .displayName;

  @override
  Widget build(BuildContext context) {
    final List<String> ids = participants.toList()..sort();
    final ThemeData theme = Theme.of(context);

    final int pctTotal = ids.fold<int>(
      0,
      (int sum, String id) =>
          sum +
          ((double.tryParse(percentControllers[id]?.text ?? '') ?? 0) * 100)
              .round(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (method == SplitMethod.exact)
          Text(
            'Enter each person\'s amount. If they do not add up to the total, the difference is '
            'spread across everyone and you will see a note.',
            style: theme.textTheme.bodySmall,
          ),
        if (method == SplitMethod.percentage) ...<Widget>[
          Text(
            'Percentages must add up to 100%. Currently ${(pctTotal / 100).toStringAsFixed(2)}%.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: (pctTotal - 10000).abs() > 1
                  ? theme.colorScheme.error
                  : null,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        if (method == SplitMethod.shares)
          Text(
            'Weights let you split unevenly — for example two adults and a child with weights 1, 1, 0.5.',
            style: theme.textTheme.bodySmall,
          ),
        const SizedBox(height: AppSpacing.md),
        for (final String id in ids)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: <Widget>[
                MemberAvatar(initials: _name(id).substring(0, 1), size: 28),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(_name(id), style: theme.textTheme.bodyMedium),
                ),
                if (method == SplitMethod.exact)
                  SizedBox(
                    width: 130,
                    child: TextField(
                      controller: exactControllers[id],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      decoration: const InputDecoration(
                        isDense: true,
                        suffixText: '',
                      ),
                      onChanged: (_) => onChanged(),
                    ),
                  ),
                if (method == SplitMethod.percentage)
                  SizedBox(
                    width: 110,
                    child: TextField(
                      controller: percentControllers[id],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      decoration: const InputDecoration(
                        isDense: true,
                        suffixText: '%',
                      ),
                      onChanged: (_) => onChanged(),
                    ),
                  ),
                if (method == SplitMethod.shares) ...<Widget>[
                  IconButton(
                    onPressed: () {
                      onChanged();
                    },
                    icon: const Icon(Icons.remove_circle_outline, size: 18),
                    tooltip: 'Less',
                    visualDensity: VisualDensity.compact,
                  ),
                  Text(
                    '${weights[id] ?? 1}',
                    style: theme.textTheme.titleSmall,
                  ),
                  IconButton(
                    onPressed: () {
                      weights[id] = (weights[id] ?? 1) + 1;
                      onChanged();
                    },
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    tooltip: 'More',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ],
            ),
          ),
        if (method == SplitMethod.shares)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                for (final String id in ids) {
                  weights[id] = 0;
                }
                onChanged();
              },
              icon: const Icon(Icons.restart_alt, size: 16),
              label: const Text('Reset weights'),
            ),
          ),
      ],
    );
  }
}

/// Live, always-balanced preview of who owes what.
class _SplitPreview extends StatelessWidget {
  const _SplitPreview({
    required this.preview,
    required this.currency,
    required this.payerId,
    required this.members,
    required this.isPersonal,
  });

  final SplitOutcome? preview;
  final String currency;
  final String payerId;
  final List<TripMember> members;
  final bool isPersonal;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (preview == null) {
      return const AppCard(
        child: Text(
          'Enter an amount and choose participants to see the split.',
          style: TextStyle(fontSize: 13),
        ),
      );
    }

    String name(String id) => members
        .firstWhere(
          (TripMember m) => m.userId == id,
          orElse: () => TripMember(userId: id, tripId: ''),
        )
        .displayName;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text('Split preview', style: theme.textTheme.titleSmall),
              const Spacer(),
              Icon(
                preview!.isBalanced ? Icons.check_circle : Icons.error_outline,
                size: 16,
                color: preview!.isBalanced
                    ? AppColors.positive
                    : theme.colorScheme.error,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                preview!.isBalanced ? 'Balanced' : 'Does not add up',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: preview!.isBalanced
                      ? AppColors.positive
                      : theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (final MapEntry<String, int> entry
              in (preview!.shares.entries.toList()..sort(
                (MapEntry<String, int> a, MapEntry<String, int> b) =>
                    a.key.compareTo(b.key),
              )))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      name(entry.key) == entry.key
                          ? 'A member'
                          : name(entry.key),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    Money(entry.value, currency).format(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: AppSpacing.xl),
          Row(
            children: <Widget>[
              Text('Total', style: theme.textTheme.bodySmall),
              const Spacer(),
              Text(
                Money(
                  preview!.shares.values.fold<int>(0, (int a, int b) => a + b),
                  currency,
                ).format(),
                style: theme.textTheme.titleSmall,
              ),
            ],
          ),
          if (preview!.warnings.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: InlineBanner(
                message: preview!.warnings.join('\n'),
                tone: StatusTone.warning,
                icon: Icons.info_outline,
              ),
            ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

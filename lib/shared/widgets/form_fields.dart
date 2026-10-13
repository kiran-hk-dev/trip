import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/money/currency.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/common.dart';

/// Date picker field with a Material 3 date picker and an always-visible
/// label, so it stays usable at 320px width.
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
    this.helper,
  });

  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final DateTime now = DateTime.now();
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: firstDate ?? now.subtract(const Duration(days: 365 * 5)),
          lastDate: lastDate ?? now.add(const Duration(days: 365 * 5)),
        );
        if (picked != null) onChanged(picked);
      },
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          prefixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
          suffixIcon: const Icon(Icons.expand_more, size: 18),
          suffixIconConstraints: const BoxConstraints(minWidth: 36),
        ),
        child: Text(
          DateFormat('d MMM yyyy').format(value),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

/// Time picker field for itinerary items.
class TimeField extends StatelessWidget {
  const TimeField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.helper,
  });

  final String label;
  final TimeOfDay? value;
  final ValueChanged<TimeOfDay> onChanged;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final TimeOfDay? picked = await showTimePicker(
          context: context,
          initialTime: value ?? TimeOfDay.now(),
        );
        if (picked != null) onChanged(picked);
      },
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          prefixIcon: const Icon(Icons.schedule, size: 18),
        ),
        child: Text(
          value == null ? 'Not set' : value!.format(context),
          style: value == null
              ? TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)
              : null,
        ),
      ),
    );
  }
}

/// Money input that keeps the amount in integer minor units.
///
/// The user types in major units; the field parses with [Money.parse] so
/// locale-specific separators and half-up rounding behave consistently.
class MoneyField extends StatefulWidget {
  const MoneyField({
    super.key,
    required this.label,
    required this.currency,
    required this.controller,
    this.onCurrencyChanged,
    this.helperText,
    this.onChanged,
    this.autofocus = false,
  });

  final String label;
  final String currency;
  final TextEditingController controller;
  final ValueChanged<String>? onCurrencyChanged;
  final String? helperText;
  final ValueChanged<Money>? onChanged;
  final bool autofocus;

  @override
  State<MoneyField> createState() => _MoneyFieldState();
}

class _MoneyFieldState extends State<MoneyField> {
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onText);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    super.dispose();
  }

  void _onText() {
    if (widget.controller.text.isEmpty) {
      if (_error != null) setState(() => _error = null);
      return;
    }
    final Money parsed = Money.tryParse(
      widget.controller.text,
      widget.currency,
    );
    widget.onChanged?.call(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final Currency currency = Currencies.get(widget.currency);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: widget.controller,
                autofocus: widget.autofocus,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: <TextInputFormatter>[
                  // Allow digits, one separator, and a minus sign only.
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\- ]')),
                ],
                decoration: InputDecoration(
                  labelText: widget.label,
                  prefixIcon: const Icon(Icons.payments_outlined),
                  helperText: widget.helperText,
                  errorText: _error,
                  prefixText: '${currency.symbol} ',
                ),
                onChanged: (String value) {
                  setState(() {
                    _error =
                        value.trim().isNotEmpty &&
                            Money.tryParse(value, widget.currency).isNegative
                        ? 'Enter a positive amount'
                        : null;
                  });
                },
              ),
            ),
            if (widget.onCurrencyChanged != null) ...<Widget>[
              const SizedBox(width: AppSpacing.sm),
              _CurrencyButton(
                currency: widget.currency,
                onChanged: widget.onCurrencyChanged!,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _CurrencyButton extends StatelessWidget {
  const _CurrencyButton({required this.currency, required this.onChanged});

  final String currency;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final Currency c = Currencies.get(currency);
    return PopupMenuButton<String>(
      tooltip: 'Change currency',
      initialValue: currency,
      onSelected: onChanged,
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        const PopupMenuDivider(),
        for (final Currency option in Currencies.all)
          PopupMenuItem<String>(
            value: option.code,
            child: Row(
              children: <Widget>[
                if (option.flagEmoji != null) Text(option.flagEmoji!),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text('${option.code} — ${option.name}')),
                if (option.code == currency) const Icon(Icons.check, size: 16),
              ],
            ),
          ),
      ],
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(c.code, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(width: AppSpacing.xs),
            const Icon(Icons.expand_more, size: 16),
          ],
        ),
      ),
    );
  }
}

/// Searchable currency picker used by the converter and expense screens.
Future<String?> pickCurrency(
  BuildContext context, {
  required String title,
  String? selected,
}) {
  return showAppSheet<String>(
    context: context,
    builder: (BuildContext context) =>
        _CurrencyPicker(title: title, selected: selected),
  );
}

class _CurrencyPicker extends StatefulWidget {
  const _CurrencyPicker({required this.title, this.selected});

  final String title;
  final String? selected;

  @override
  State<_CurrencyPicker> createState() => _CurrencyPickerState();
}

class _CurrencyPickerState extends State<_CurrencyPicker> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String q = _query.trim().toLowerCase();
    final List<Currency> matches = Currencies.all.where((Currency c) {
      if (q.isEmpty) return true;
      return c.code.toLowerCase().contains(q) ||
          c.name.toLowerCase().contains(q) ||
          (c.regionName?.toLowerCase().contains(q) ?? false);
    }).toList();

    final List<Currency> popular = Currencies.all
        .where((Currency c) => Currencies.popular.contains(c.code))
        .toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _search,
            autofocus: true,
            onChanged: (String v) => setState(() => _query = v),
            decoration: const InputDecoration(
              hintText: 'Search by code, name or country',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: <Widget>[
                if (q.isEmpty) ...<Widget>[
                  const _PickerHeader('Popular'),
                  for (final Currency c in popular)
                    _PickerRow(currency: c, selected: widget.selected),
                  const Divider(),
                ],
                const _PickerHeader('All currencies'),
                for (final Currency c in matches)
                  _PickerRow(currency: c, selected: widget.selected),
                if (matches.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xl,
                    ),
                    child: Center(
                      child: Text(
                        'No currency matches "$_query".',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PickerHeader extends StatelessWidget {
  const _PickerHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
    child: Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        letterSpacing: 0.8,
      ),
    ),
  );
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({required this.currency, this.selected});

  final Currency currency;
  final String? selected;

  @override
  Widget build(BuildContext context) {
    final bool isSelected = currency.code == selected;
    return ListTile(
      dense: true,
      selected: isSelected,
      onTap: () => Navigator.of(context).pop(currency.code),
      leading: Text(
        currency.flagEmoji ?? '💱',
        style: const TextStyle(fontSize: 20),
      ),
      title: Text(currency.code, style: Theme.of(context).textTheme.titleSmall),
      subtitle: Text(
        currency.name,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: isSelected
          ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
          : null,
    );
  }
}

/// Search field with debounce, used for expenses and destinations.
class DebouncedSearchField extends StatefulWidget {
  const DebouncedSearchField({
    super.key,
    required this.onChanged,
    this.hint = 'Search',
    this.initialValue = '',
    this.debounce = const Duration(milliseconds: 300),
  });

  final ValueChanged<String> onChanged;
  final String hint;
  final String initialValue;
  final Duration debounce;

  @override
  State<DebouncedSearchField> createState() => _DebouncedSearchFieldState();
}

class _DebouncedSearchFieldState extends State<DebouncedSearchField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _controller.clear();
                  widget.onChanged('');
                  setState(() {});
                },
                icon: const Icon(Icons.clear),
                tooltip: 'Clear search',
              ),
      ),
      onChanged: (String value) {
        setState(() {});
        _timer?.cancel();
        _timer = Timer(widget.debounce, () => widget.onChanged(value));
      },
    );
  }
}

/// Multi-select member picker rendered as chips. Used by the expense editor
/// and the packing-list assigner.
class MemberPicker extends StatelessWidget {
  const MemberPicker({
    super.key,
    required this.members,
    required this.selectedIds,
    required this.onChanged,
    this.lockedIds = const <String>{},
    this.helperText,
  });

  final List<({String id, String name, String? subtitle})> members;
  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onChanged;

  /// Ids that cannot be removed (e.g. the payer of a personal expense).
  final Set<String> lockedIds;
  final String? helperText;

  void _toggle(String id, bool selected) {
    if (lockedIds.contains(id)) return;
    final Set<String> next = <String>{...selectedIds};
    if (selected) {
      next.add(id);
    } else {
      next.remove(id);
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (members.isEmpty) {
      return Text('No members yet.', style: theme.textTheme.bodySmall);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            for (final ({String id, String? subtitle, String name}) m
                in members)
              FilterChip(
                selected: selectedIds.contains(m.id),
                onSelected: lockedIds.contains(m.id)
                    ? null
                    : (bool v) => _toggle(m.id, v),
                avatar: CircleAvatar(
                  radius: 11,
                  child: Text(
                    m.name.isEmpty ? '?' : m.name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                label: Text(m.name),
              ),
          ],
        ),
        if (helperText != null) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text(helperText!, style: theme.textTheme.bodySmall),
        ],
      ],
    );
  }
}

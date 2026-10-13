import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/money/currency.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/misc.dart';
import '../../data/repositories.dart';
import '../../data/supabase_service.dart';
import '../../router/providers.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/form_fields.dart';

/// Live currency conversion centre.
///
/// Correctness rules enforced here:
///  * a cached rate is never labelled live — the age and provider are shown;
///  * the conversion states plainly that it is an indicative mid-market rate,
///    not what a bank or card issuer will charge;
///  * if no rate is available the screen says so instead of guessing.
class ConverterPage extends ConsumerStatefulWidget {
  const ConverterPage({super.key, this.tripId});

  final String? tripId;

  @override
  ConsumerState<ConverterPage> createState() => _ConverterPageState();
}

class _ConverterPageState extends ConsumerState<ConverterPage> {
  final TextEditingController _amount = TextEditingController(text: '100');
  final TextEditingController _fee = TextEditingController(text: '0');
  String _from = Currencies.defaultCode;
  String _to = 'EUR';
  RateResult? _rates;
  bool _loading = true;
  String? _error;
  bool _useFee = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _amount.dispose();
    _fee.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final RateResult result = AppConfig.demoMode
          ? RateResult(
              rates: DemoRateFixture.rates(_from),
              fromCache: true,
              notice:
                  'Demo rates. These are invented and are not market rates.',
            )
          : await ref.read(tripRepositoryProvider).converter.rates(
              _from,
              <String>[_to, _from],
            );
      if (!mounted) return;
      setState(() {
        _rates = result;
        _loading = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = err is RepositoryException ? err.message : '$err';
      });
    }
  }

  CachedRate? get _rate {
    if (_from == _to) return CachedRate.identity(_from);
    return _rates?.rates.where((CachedRate r) => r.quote == _to).firstOrNull;
  }

  ({Money converted, Money afterFee})? get _result {
    final CachedRate? rate = _rate;
    if (rate == null) return null;
    final Money input = Money.tryParse(_amount.text, _from);
    if (input.minorUnits == 0) return null;
    final Money converted = rate.convert(input);
    if (!_useFee) return (converted: converted, afterFee: converted);
    final double pct = double.tryParse(_fee.text) ?? 0;
    final Money afterFee = Money.fromDecimal(
      converted.major * Decimal.parse((1 - (pct / 100)).toStringAsFixed(6)),
      _to,
    );
    return (converted: converted, afterFee: afterFee);
  }

  Future<void> _swap() async {
    setState(() {
      final String tmp = _from;
      _from = _to;
      _to = tmp;
      _amount.text = _result?.converted.format(locale: 'en') ?? _amount.text;
    });
    await _load();
  }

  Future<void> _saveHistory() async {
    final ({Money afterFee, Money converted})? result = _result;
    final CachedRate? rate = _rate;
    if (result == null || rate == null) return;
    if (AppConfig.demoMode) {
      showFeedback(context, 'History is disabled in demo mode.', isError: true);
      return;
    }
    await ref
        .read(tripRepositoryProvider)
        .converter
        .saveConversion(
          from: _from,
          to: _to,
          inputMinor: Money.tryParse(_amount.text, _from).minorUnits,
          outputMinor: result.converted.minorUnits,
          rate: rate.rate,
          provider: rate.provider,
          isOfflineCached: _rates?.fromCache ?? false,
          feeEstimatePct: _useFee ? double.tryParse(_fee.text) : null,
        );
    if (mounted) showFeedback(context, 'Saved to your conversion history.');
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Currency converter')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          AppCard(
            child: Column(
              children: <Widget>[
                _CurrencyField(
                  label: 'From',
                  code: _from,
                  amount: _amount,
                  onPickCurrency: () => _pickCurrency(from: true),
                ),
                const SizedBox(height: AppSpacing.md),
                Center(
                  child: IconButton.filledTonal(
                    onPressed: _loading ? null : _swap,
                    icon: const Icon(Icons.swap_vert),
                    tooltip: 'Swap currencies',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _CurrencyField(
                  label: 'To',
                  code: _to,
                  amount: null,
                  readOnlyAmount: _result?.converted,
                  onPickCurrency: () => _pickCurrency(from: false),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),
          if (_loading)
            const AppCard(child: SkeletonBox(height: 80))
          else if (_error != null)
            InlineBanner(
              message: _error!,
              tone: StatusTone.warning,
              icon: Icons.cloud_off,
              action: TextButton(onPressed: _load, child: const Text('Retry')),
            )
          else
            _RateNotice(
              rate: _rate,
              result: _rates,
              fromCode: _from,
              toCode: _to,
            ),

          if (_result != null && _useFee) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: _fee,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Estimated fee',
                            suffixText: '%',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('After fee', style: theme.textTheme.bodySmall),
                            Text(
                              _result!.afterFee.format(),
                              style: theme.textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SwitchListTile(
                    value: _useFee,
                    onChanged: (bool v) => setState(() => _useFee = v),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Estimate a card or bank fee'),
                    subtitle: const Text(
                      'An estimate you set yourself — TripSplit does not know your provider\'s fee.',
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: _result == null ? null : _saveHistory,
            icon: const Icon(Icons.history, size: 18),
            label: const Text('Save to conversion history'),
          ),

          const SizedBox(height: AppSpacing.xl),
          const InlineBanner(
            message:
                'These are indicative mid-market reference rates. Your bank, card issuer or exchange '
                'counter may apply a different rate and their own fees, so the amount you actually '
                'receive can be lower. TripSplit does not connect to any payment provider.',
            tone: StatusTone.warning,
            icon: Icons.info_outline,
          ),

          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(title: 'Recent conversions'),
          const _HistoryList(),

          const SizedBox(height: AppSpacing.huge),
        ],
      ),
    );
  }

  Future<void> _pickCurrency({required bool from}) async {
    final String? picked = await pickCurrency(
      context,
      title: from ? 'Convert from' : 'Convert to',
      selected: from ? _from : _to,
    );
    if (picked == null) return;
    setState(() {
      if (from) {
        _from = picked;
      } else {
        _to = picked;
      }
    });
    await _load();
  }
}

class _CurrencyField extends StatelessWidget {
  const _CurrencyField({
    required this.label,
    required this.code,
    required this.amount,
    this.readOnlyAmount,
    this.onPickCurrency,
  });

  final String label;
  final String code;
  final TextEditingController? amount;
  final Money? readOnlyAmount;
  final VoidCallback? onPickCurrency;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Currency currency = Currencies.get(code);

    return InkWell(
      onTap: onPickCurrency,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixText: '${currency.flagEmoji ?? ''} ',
          suffixIcon: const Icon(Icons.expand_more),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
        ),
        child: Row(
          children: <Widget>[
            if (amount != null)
              Expanded(
                child: TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: theme.textTheme.headlineSmall,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onTap: () {},
                ),
              )
            else
              Expanded(
                child: Text(
                  readOnlyAmount?.format() ?? '—',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(width: AppSpacing.md),
            Text(
              code,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RateNotice extends StatelessWidget {
  const _RateNotice({
    required this.rate,
    required this.result,
    required this.fromCode,
    required this.toCode,
  });

  final String fromCode;
  final String toCode;

  final CachedRate? rate;
  final RateResult? result;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (rate == null) {
      return const InlineBanner(
        message:
            'No exchange rate is available for this pair right now. TripSplit will not guess a '
            'rate — try again when you are connected.',
        tone: StatusTone.warning,
        icon: Icons.cloud_off,
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              StatusPill(
                label: rate!.isStale || result!.fromCache
                    ? 'Cached rate'
                    : 'Rate',
                tone: rate!.isStale || result!.fromCache
                    ? StatusTone.warning
                    : StatusTone.positive,
                icon: rate!.isStale || result!.fromCache
                    ? Icons.schedule
                    : Icons.check_circle_outline,
                dense: true,
              ),
              const Spacer(),
              Text(rate!.ageLabel, style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          DetailRow(
            label: 'Rate',
            value: '1 $fromCode = ${rate!.rate.toStringAsFixed(6)} $toCode',
            monospace: true,
          ),
          DetailRow(label: 'Provider', value: rate!.provider),
          DetailRow(
            label: 'Type',
            value: rate!.isIndicative
                ? 'Indicative mid-market'
                : 'Provider rate',
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Indicative mid-market rates are reference points, not quotes. Your provider may '
            'add a margin or fee on top.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _HistoryList extends ConsumerWidget {
  const _HistoryList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (AppConfig.demoMode) {
      return const AppCard(
        child: Text(
          'Conversion history is disabled in demo mode.',
          style: TextStyle(fontSize: 13),
        ),
      );
    }

    return FutureBuilder<List<ConversionRecord>>(
      future: ref.read(tripRepositoryProvider).converter.history(limit: 20),
      builder: (BuildContext context, AsyncSnapshot<List<ConversionRecord>> snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const AppCard(
            child: Text(
              'No saved conversions yet.',
              style: TextStyle(fontSize: 13),
            ),
          );
        }
        final List<ConversionRecord> records = snapshot.data!;
        return AppCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            children: <Widget>[
              for (int i = 0; i < records.length && i < 10; i++)
                ListTile(
                  dense: true,
                  title: Text(
                    '${Money(records[i].inputMinor, records[i].from).format()} '
                    '→ ${Money(records[i].outputMinor, records[i].to).format()}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  subtitle: Text(
                    '${records[i].provider} · '
                    '${records[i].createdAt.toIso8601String().substring(0, 16).replaceAll('T', ' ')}'
                    '${records[i].isOfflineCached ? ' · cached' : ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Invented, clearly-labelled rates used only in demo mode.
abstract final class DemoRateFixture {
  static List<CachedRate> rates(String base) {
    const Map<String, double> perUsd = <String, double>{
      'USD': 1,
      'EUR': 0.92,
      'GBP': 0.79,
      'INR': 83.2,
      'JPY': 152.4,
      'HKD': 7.81,
      'SGD': 1.35,
      'AUD': 1.52,
      'CAD': 1.37,
      'THB': 36.1,
      'MYR': 4.71,
      'CHF': 0.89,
      'CNY': 7.24,
      'IDR': 15800,
      'AED': 3.67,
    };
    final double basePerUsd = perUsd[base] ?? 1;
    final DateTime fetched = DateTime.now().subtract(const Duration(hours: 4));
    return <CachedRate>[
      for (final MapEntry<String, double> e in perUsd.entries)
        CachedRate(
          base: base,
          quote: e.key,
          rate: e.value / basePerUsd,
          provider: 'demo-fixture',
          fetchedAt: fetched,
          isIndicative: true,
          isStale: false,
        ),
    ];
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

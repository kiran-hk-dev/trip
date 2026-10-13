import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/planning.dart';

import '../../core/money/currency.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/trip.dart';
import '../../data/supabase_service.dart';
import '../../router/providers.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/form_fields.dart';

/// One activity from a generated plan. Everything is editable and nothing is
/// saved until the user saves it.
class _PlanActivity {
  _PlanActivity({
    required this.title,
    required this.kind,
    required this.description,
    required this.costMinor,
    required this.address,
  });

  final String title;
  final String kind;
  final String description;
  final int costMinor;
  final String? address;
}

class _PlanDay {
  _PlanDay({
    required this.number,
    required this.date,
    required this.title,
    required this.summary,
    required this.morning,
    required this.afternoon,
    required this.evening,
    required this.badWeather,
    required this.lowCost,
  });

  final int number;
  final DateTime date;
  final String title;
  final String summary;
  final List<_PlanActivity> morning;
  final List<_PlanActivity> afternoon;
  final List<_PlanActivity> evening;
  final String? badWeather;
  final String? lowCost;

  List<_PlanActivity> get all => <_PlanActivity>[
    ...morning,
    ...afternoon,
    ...evening,
  ];
}

/// Guided AI trip planner.
///
/// The provider key stays on the server. Everything returned is an estimate,
/// validated server-side against a schema before it reaches this screen, and
/// editable here. If AI is unavailable the screen says so and the user can
/// build the itinerary manually.
class AiPlannerPage extends ConsumerStatefulWidget {
  const AiPlannerPage({super.key});

  @override
  ConsumerState<AiPlannerPage> createState() => _AiPlannerPageState();
}

class _AiPlannerPageState extends ConsumerState<AiPlannerPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _origin = TextEditingController();
  final TextEditingController _destinations = TextEditingController();
  final TextEditingController _budget = TextEditingController();
  late DateTime _start;
  late DateTime _end;
  late int _travelers;
  late String _currency;
  late String _style;
  late ItineraryPace _pace;
  final Set<String> _interests = <String>{};
  String _accommodation = '';
  String _transport = '';
  String _dietary = '';
  String _accessibility = '';

  bool _busy = false;
  String? _error;
  _PlanDay? _plan;
  String? _disclaimer;
  String? _tripId;

  @override
  void initState() {
    super.initState();
    final DateTime today = DateTime.now();
    _start = today.add(const Duration(days: 21));
    _end = _start.add(const Duration(days: 4));
    _travelers = 2;
    _currency = Currencies.defaultCode;
    _style = 'balanced';
    _pace = ItineraryPace.balanced;
  }

  @override
  void dispose() {
    _origin.dispose();
    _destinations.dispose();
    _budget.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
      _plan = null;
    });

    try {
      final Map<String, dynamic>
      result = await SupabaseService.instance.invokeFunction(
        'ai-itinerary',
        body: <String, dynamic>{
          if (_tripId != null) 'trip_id': _tripId,
          'origin': _origin.text.trim(),
          'destinations': _destinations.text
              .split(',')
              .map((String s) => s.trim())
              .where((String s) => s.isNotEmpty)
              .toList(),
          'start_date': _start.toIso8601String().substring(0, 10),
          'end_date': _end.toIso8601String().substring(0, 10),
          'travelers': _travelers,
          'budget_minor': Money.tryParse(_budget.text, _currency).minorUnits,
          'currency': _currency,
          'travel_style': _style,
          'interests': _interests.toList(),
          'pace': _pace.name,
          if (_accommodation.isNotEmpty)
            'accommodation_preference': _accommodation,
          if (_transport.isNotEmpty) 'transport_preference': _transport,
          if (_dietary.isNotEmpty) 'dietary_notes': _dietary,
          if (_accessibility.isNotEmpty) 'accessibility_notes': _accessibility,
        },
      );

      final Map<String, dynamic> plan =
          (result['plan'] as Map<String, dynamic>?) ??
          const <String, dynamic>{};
      final List<dynamic> rawDays =
          (plan['days'] as List?) ?? const <dynamic>[];

      final List<_PlanDay> days = <_PlanDay>[
        for (final dynamic raw in rawDays.whereType<Map<String, dynamic>>())
          _parseDay(raw, _start),
      ];

      if (days.isEmpty) {
        setState(
          () => _error = 'The AI returned a plan with no days. Try again.',
        );
        return;
      }

      setState(() {
        _plan = days.first;
        _disclaimer = plan['disclaimer'] as String?;
      });
    } on EdgeFunctionException catch (err) {
      setState(() => _error = err.message);
    } catch (err) {
      setState(() => _error = 'Could not generate a plan. $err');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  _PlanDay _parseDay(Map<String, dynamic> raw, DateTime fallbackStart) {
    List<_PlanActivity> parseSlot(String key) => <_PlanActivity>[
      for (final dynamic a
          in ((raw[key] as List?) ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>())
        _PlanActivity(
          title: '${a['title'] ?? ''}',
          kind: '${a['kind'] ?? 'other'}',
          description: '${a['description'] ?? ''}',
          costMinor: (a['estimated_cost_minor'] as num?)?.toInt() ?? 0,
          address: a['address'] as String?,
        ),
    ];

    final int dayNumber = (raw['day_number'] as num?)?.toInt() ?? 1;
    return _PlanDay(
      number: dayNumber,
      date:
          DateTime.tryParse('${raw['date']}') ??
          fallbackStart.add(Duration(days: dayNumber - 1)),
      title: '${raw['title'] ?? 'Day $dayNumber'}',
      summary: '${raw['summary'] ?? ''}',
      morning: parseSlot('morning'),
      afternoon: parseSlot('afternoon'),
      evening: parseSlot('evening'),
      badWeather: raw['bad_weather_alternative'] as String?,
      lowCost: raw['low_cost_alternative'] as String?,
    );
  }

  Future<void> _regenerateDay() async {
    final int days = _end.difference(_start).inDays + 1;
    final int? which = await showAppSheet<int>(
      context: context,
      builder: (BuildContext context) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Regenerate which day?',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.lg),
            for (int i = 1; i <= days; i++)
              ListTile(
                title: Text('Day $i'),
                onTap: () => Navigator.of(context).pop(i),
              ),
          ],
        ),
      ),
    );
    if (which == null) return;

    setState(() => _busy = true);
    try {
      final Map<String, dynamic> result = await SupabaseService.instance
          .invokeFunction(
            'ai-itinerary',
            body: <String, dynamic>{
              if (_tripId != null) 'trip_id': _tripId,
              'origin': _origin.text.trim(),
              'destinations': _destinations.text
                  .split(',')
                  .map((String s) => s.trim())
                  .toList(),
              'start_date': _start.toIso8601String().substring(0, 10),
              'end_date': _end.toIso8601String().substring(0, 10),
              'travelers': _travelers,
              'budget_minor': Money.tryParse(
                _budget.text,
                _currency,
              ).minorUnits,
              'currency': _currency,
              'travel_style': _style,
              'interests': _interests.toList(),
              'pace': _pace.name,
              'regenerate_day': which,
            },
          );
      final Map<String, dynamic> plan =
          (result['plan'] as Map<String, dynamic>?) ??
          const <String, dynamic>{};
      final List<dynamic> rawDays =
          (plan['days'] as List?) ?? const <dynamic>[];
      if (rawDays.isEmpty) return;
      setState(
        () => _plan = _parseDay(rawDays.first as Map<String, dynamic>, _start),
      );
      if (mounted) showFeedback(context, 'Day $which regenerated.');
    } on EdgeFunctionException catch (err) {
      if (mounted) setState(() => _error = err.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final _PlanDay? plan = _plan;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI trip planner'),
        actions: plan == null
            ? const <Widget>[]
            : <Widget>[
                IconButton(
                  onPressed: _busy ? null : _regenerateDay,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Regenerate a day',
                ),
              ],
      ),
      body: plan != null ? _planView(context, plan) : _form(context),
    );
  }

  Widget _form(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          const InlineBanner(
            message:
                'Generated plans are estimates. Prices, durations and suggestions are not '
                'confirmed quotes, and opening hours and availability change. Everything is '
                'editable before you save.',
            tone: StatusTone.warning,
            icon: Icons.auto_awesome,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            controller: _origin,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Starting from',
              hintText: 'London',
              prefixIcon: Icon(Icons.flight_takeoff),
            ),
            validator: (String? v) => (v == null || v.trim().isEmpty)
                ? 'Where are you starting from?'
                : null,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            controller: _destinations,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Destinations',
              hintText: 'Kyoto, Osaka',
              helperText: 'Separate several destinations with commas.',
              prefixIcon: Icon(Icons.place_outlined),
            ),
            validator: (String? v) => (v == null || v.trim().isEmpty)
                ? 'Where do you want to go?'
                : null,
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: <Widget>[
              Expanded(
                child: DateField(
                  label: 'Arrive',
                  value: _start,
                  onChanged: (DateTime d) => setState(() {
                    _start = d;
                    if (_end.isBefore(_start)) _end = _start;
                  }),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: DateField(
                  label: 'Leave',
                  value: _end,
                  firstDate: _start,
                  onChanged: (DateTime d) => setState(() => _end = d),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: <Widget>[
              Expanded(
                child: MoneyField(
                  label: 'Budget',
                  currency: _currency,
                  controller: _budget,
                  onCurrencyChanged: (String c) =>
                      setState(() => _currency = c),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _travelers,
                  decoration: const InputDecoration(labelText: 'Travellers'),
                  items: <DropdownMenuItem<int>>[
                    for (int i = 1; i <= 12; i++)
                      DropdownMenuItem<int>(value: i, child: Text('$i')),
                  ],
                  onChanged: (int? v) =>
                      setState(() => _travelers = v ?? _travelers),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SegmentedButton<String>(
            segments: const <ButtonSegment<String>>[
              ButtonSegment<String>(value: 'budget', label: Text('Budget')),
              ButtonSegment<String>(value: 'balanced', label: Text('Balanced')),
              ButtonSegment<String>(value: 'comfort', label: Text('Comfort')),
              ButtonSegment<String>(value: 'luxury', label: Text('Luxury')),
            ],
            selected: <String>{_style},
            onSelectionChanged: (Set<String> s) =>
                setState(() => _style = s.first),
            showSelectedIcon: false,
          ),
          const SizedBox(height: AppSpacing.lg),
          SegmentedButton<ItineraryPace>(
            segments: <ButtonSegment<ItineraryPace>>[
              for (final ItineraryPace p in ItineraryPace.values)
                ButtonSegment<ItineraryPace>(value: p, label: Text(p.label)),
            ],
            selected: <ItineraryPace>{_pace},
            onSelectionChanged: (Set<ItineraryPace> s) =>
                setState(() => _pace = s.first),
            showSelectedIcon: false,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(_pace.activityHint, style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.lg),
          Text('Interests', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final String i in const <String>[
                'nature',
                'beaches',
                'adventure',
                'food',
                'shopping',
                'culture',
                'nightlife',
                'relaxation',
                'photography',
                'history',
              ])
                FilterChip(
                  label: Text(i),
                  selected: _interests.contains(i),
                  onSelected: (bool v) => setState(() {
                    v ? _interests.add(i) : _interests.remove(i);
                  }),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: TextEditingController(text: _accommodation)
              ..addListener(() => _accommodation = _accommodation),
            decoration: const InputDecoration(
              labelText: 'Accommodation preference',
              prefixIcon: Icon(Icons.hotel_outlined),
            ),
            onChanged: (String v) => _accommodation = v,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            onChanged: (String v) => _transport = v,
            decoration: const InputDecoration(
              labelText: 'Transport preference',
              prefixIcon: Icon(Icons.directions_transit_outlined),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            onChanged: (String v) => _dietary = v,
            decoration: const InputDecoration(
              labelText: 'Dietary requirements',
              prefixIcon: Icon(Icons.restaurant_outlined),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            onChanged: (String v) => _accessibility = v,
            decoration: const InputDecoration(
              labelText: 'Mobility or accessibility needs',
              prefixIcon: Icon(Icons.accessible_outlined),
            ),
          ),

          if (_error != null) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            InlineBanner(message: _error!, tone: StatusTone.danger),
          ],

          const SizedBox(height: AppSpacing.xl),
          FilledButton.icon(
            onPressed: _busy ? null : _generate,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(_busy ? 'Generating…' : 'Generate my itinerary'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextButton.icon(
            onPressed: () {
              final String? tripId = ref.read(selectedTripIdProvider);
              if (tripId == null) {
                showFeedback(
                  context,
                  'Open a trip first to build the itinerary inside it.',
                  isError: true,
                );
                return;
              }
              context.push('/trips/$tripId/itinerary');
            },
            icon: const Icon(Icons.edit_calendar_outlined),
            label: const Text('Build it manually instead'),
          ),
          const SizedBox(height: AppSpacing.huge),
        ],
      ),
    );
  }

  Widget _planView(BuildContext context, _PlanDay day) {
    final ThemeData theme = Theme.of(context);
    final int estimated = day.all.fold<int>(
      0,
      (int s, _PlanActivity a) => s + a.costMinor,
    );

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        Text('Day ${day.number}', style: theme.textTheme.titleLarge),
        Text(
          '${day.date.toIso8601String().substring(0, 10)} · ${day.title}',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(day.summary, style: theme.textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.lg),
        InlineBanner(
          tone: StatusTone.warning,
          icon: Icons.info_outline,
          message:
              _disclaimer ??
              'AI-generated estimates. Confirm opening hours, prices and availability '
                  'independently before you travel.',
        ),
        const SizedBox(height: AppSpacing.lg),

        if (day.morning.isNotEmpty) _Slot(title: 'Morning', items: day.morning),
        if (day.afternoon.isNotEmpty)
          _Slot(title: 'Afternoon', items: day.afternoon),
        if (day.evening.isNotEmpty) _Slot(title: 'Evening', items: day.evening),

        if (day.badWeather != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(Icons.cloud_outlined),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('If it rains', style: theme.textTheme.titleSmall),
                      Text(day.badWeather!, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        if (day.lowCost != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(Icons.savings_outlined),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Cheaper option', style: theme.textTheme.titleSmall),
                      Text(day.lowCost!, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: AppSpacing.lg),
        AppCard(
          child: Row(
            children: <Widget>[
              Text('Estimated day cost', style: theme.textTheme.bodyMedium),
              const Spacer(),
              Text(
                Money(estimated, _currency).format(),
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xl),
        FilledButton.icon(
          onPressed: () => _save(context),
          icon: const Icon(Icons.save_outlined),
          label: Text(_tripId == null ? 'Save to a trip' : 'Save to this trip'),
        ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          onPressed: () => setState(() => _plan = null),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Change the request'),
        ),
        const SizedBox(height: AppSpacing.huge),
      ],
    );
  }

  Future<void> _save(BuildContext context) async {
    final _PlanDay? day = _plan;
    if (day == null) return;

    String? tripId = _tripId ?? ref.read(selectedTripIdProvider);
    if (tripId == null) {
      showFeedback(
        context,
        'Open a trip first so this plan can be saved against it.',
        isError: true,
      );
      return;
    }

    try {
      final List<ItineraryDay> days = await ref
          .read(tripRepositoryProvider)
          .itinerary
          .listDays(tripId);
      final ItineraryDay? target = days
          .where((ItineraryDay d) => d.dayNumber == day.number)
          .firstOrNull;
      if (target == null) {
        if (!context.mounted) return;
        showFeedback(
          context,
          'That day is not part of the trip.',
          isError: true,
        );
        return;
      }

      int position = target.items.length;
      for (final _PlanActivity a in day.all) {
        await ref.read(tripRepositoryProvider).itinerary.addItem(target.id, <
          String,
          dynamic
        >{
          'trip_id': tripId,
          'day_id': target.id,
          'title': a.title,
          'kind': a.kind,
          'description':
              '${a.description}\n\nAI-generated estimate — verify before relying on it.',
          'address': a.address,
          'cost_minor': a.costMinor,
          'cost_currency': _currency,
          'position': position++,
        });
      }

      if (context.mounted) {
        showFeedback(context, 'Saved. Edit anything you like.');
        context.push('/trips/$tripId/itinerary');
      }
    } catch (err) {
      if (context.mounted) {
        showFeedback(
          context,
          err is RepositoryException ? err.message : 'Could not save the plan.',
          isError: true,
        );
      }
    }
  }
}

class _Slot extends StatelessWidget {
  const _Slot({required this.title, required this.items});

  final String title;
  final List<_PlanActivity> items;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title.toUpperCase(), style: theme.textTheme.labelSmall),
        const SizedBox(height: AppSpacing.sm),
        for (final _PlanActivity a in items)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(a.title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(a.description, style: theme.textTheme.bodySmall),
                  if (a.costMinor > 0) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    StatusPill(
                      label: 'est. ${a.costMinor} minor units',
                      dense: true,
                      tone: StatusTone.info,
                    ),
                  ],
                ],
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

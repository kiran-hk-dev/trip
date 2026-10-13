import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/money/currency.dart';
import '../../core/reference/countries.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/trip.dart';
import '../../data/repositories.dart';
import '../../data/supabase_service.dart';
import '../../router/providers.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/form_fields.dart';
import '../../shared/widgets/place_picker.dart';

/// Create or edit a trip. Multi-city trips are supported by adding several
/// destinations in order.
class CreateTripPage extends ConsumerStatefulWidget {
  const CreateTripPage({super.key, this.trip});

  final Trip? trip;

  bool get isEditing => trip != null;

  @override
  ConsumerState<CreateTripPage> createState() => _CreateTripPageState();
}

class _CreateTripPageState extends ConsumerState<CreateTripPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _origin;
  late final TextEditingController _budget;
  late final TextEditingController _dietary;
  late final TextEditingController _accessibility;
  late final TextEditingController _notes;

  late DateTime _start;
  late DateTime _end;
  late String _currency;
  late int _travelers;
  late TravelStyle _style;
  late ItineraryPace _pace;
  late String _status;
  late Set<String> _interests;
  late Set<String> _transport;
  late Set<String> _accommodation;
  final List<({String name, String? country, String? code})> _destinations =
      <({String name, String? country, String? code})>[];

  bool _busy = false;
  String? _error;

  static const List<String> interestOptions = <String>[
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
  ];
  static const List<String> transportOptions = <String>[
    'walking',
    'public transport',
    'taxi / rideshare',
    'train',
    'rental car',
    'flights',
  ];
  static const List<String> accommodationOptions = <String>[
    'hotel',
    'hostel',
    'apartment',
    'guesthouse',
    'camping',
    'no preference',
  ];

  @override
  void initState() {
    super.initState();
    final Trip? t = widget.trip;
    _name = TextEditingController(text: t?.name ?? '');
    _description = TextEditingController(text: t?.description ?? '');
    _origin = TextEditingController(text: t?.origin ?? '');
    _budget = TextEditingController(
      text: (t == null || t.totalBudgetMinor == 0)
          ? ''
          : Money(t.totalBudgetMinor, t.baseCurrency).format(locale: 'en'),
    );
    _dietary = TextEditingController(text: t?.dietaryNotes ?? '');
    _accessibility = TextEditingController(text: t?.accessibilityNotes ?? '');
    _notes = TextEditingController(text: t?.notes ?? '');

    final DateTime today = DateTime.now();
    _start = t?.startDate ?? today.add(const Duration(days: 14));
    _end = t?.endDate ?? _start.add(const Duration(days: 3));
    _currency = t?.baseCurrency ?? Currencies.defaultCode;
    _travelers = t?.travelerCount ?? 2;
    _style = t?.travelStyle ?? TravelStyle.balanced;
    _pace = t?.itineraryPace ?? ItineraryPace.balanced;
    _status = t?.status.name ?? TripStatus.planning.name;
    _interests = <String>{...?t?.interests};
    _transport = <String>{...?t?.transportPreferences};
    _accommodation = <String>{...?t?.accommodationPreferences};
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _origin.dispose();
    _budget.dispose();
    _dietary.dispose();
    _accessibility.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      if (widget.isEditing) {
        await ref.read(tripRepositoryProvider).updateTrip(
          widget.trip!.id,
          <String, dynamic>{
            'name': _name.text.trim(),
            'description': _description.text.trim(),
            'origin': _origin.text.trim(),
            'start_date': _isoDate(_start),
            'end_date': _isoDate(_end),
            'traveler_count': _travelers,
            'base_currency': _currency,
            'total_budget_minor': Money.tryParse(
              _budget.text,
              _currency,
            ).minorUnits,
            'travel_style': _style.name,
            'itinerary_pace': _pace.name,
            'status': _status,
            'interests': _interests.toList(),
            'transport_preferences': _transport.toList(),
            'accommodation_preferences': _accommodation.toList(),
            'dietary_notes': _dietary.text.trim(),
            'accessibility_notes': _accessibility.text.trim(),
            'notes': _notes.text.trim(),
          },
        );
        if (mounted) context.pop();
      } else {
        final String id = await ref
            .read(tripRepositoryProvider)
            .createTrip(
              name: _name.text.trim(),
              startDate: _start,
              endDate: _end,
              description: _description.text.trim(),
              origin: _origin.text.trim(),
              baseCurrency: _currency,
              travelerCount: _travelers,
              totalBudgetMinor: Money.tryParse(
                _budget.text,
                _currency,
              ).minorUnits,
              travelStyle: _style,
              itineraryPace: _pace,
              status: TripStatus.values.firstWhere(
                (TripStatus s) => s.name == _status,
                orElse: () => TripStatus.planning,
              ),
              interests: _interests.toList(),
              transportPreferences: _transport.toList(),
              accommodationPreferences: _accommodation.toList(),
              dietaryNotes: _dietary.text.trim(),
              accessibilityNotes: _accessibility.text.trim(),
              notes: _notes.text.trim(),
              destinations: _destinations
                  .map(
                    (d) => TripDestinationDraft(
                      name: d.name,
                      country: d.country,
                      countryCode: d.code,
                    ),
                  )
                  .toList(),
            );
        ref.read(selectedTripIdProvider.notifier).clear();
        if (mounted) context.push('/trips/$id');
      }
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = err is RepositoryException
            ? err.message
            : 'Could not save the trip.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(widget.isEditing ? 'Edit trip' : 'New trip')),
      body: Form(
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
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Trip name',
                hintText: 'Kyoto in autumn',
                prefixIcon: Icon(Icons.title),
              ),
              validator: (String? v) => (v == null || v.trim().length < 2)
                  ? 'Give the trip a name.'
                  : null,
            ),

            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _origin,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Travelling from',
                hintText: 'London',
                prefixIcon: Icon(Icons.flight_takeoff),
              ),
            ),

            if (!widget.isEditing) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              _DestinationBuilder(
                destinations: _destinations,
                onChanged: () => setState(() {}),
              ),
            ],

            const SizedBox(height: AppSpacing.lg),
            Row(
              children: <Widget>[
                Expanded(
                  child: DateField(
                    label: 'Start date',
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
                    label: 'End date',
                    value: _end,
                    firstDate: _start,
                    onChanged: (DateTime d) => setState(() => _end = d),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.md),
            _DayCountRow(start: _start, end: _end),

            const SizedBox(height: AppSpacing.lg),
            Row(
              children: <Widget>[
                Expanded(
                  child: MoneyField(
                    label: 'Total budget',
                    currency: _currency,
                    controller: _budget,
                    onCurrencyChanged: (String c) =>
                        setState(() => _currency = c),
                    helperText:
                        'Optional. You can allocate it by category later.',
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _TravelerStepper(
                    value: _travelers,
                    onChanged: (int v) => setState(() => _travelers = v),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xl),
            _SectionLabel('Trip style'),
            const SizedBox(height: AppSpacing.md),
            SegmentedButton<TravelStyle>(
              segments: <ButtonSegment<TravelStyle>>[
                for (final TravelStyle s in TravelStyle.values)
                  ButtonSegment<TravelStyle>(value: s, label: Text(s.label)),
              ],
              selected: <TravelStyle>{_style},
              onSelectionChanged: (Set<TravelStyle> s) =>
                  setState(() => _style = s.first),
              showSelectedIcon: false,
            ),

            const SizedBox(height: AppSpacing.xl),
            _SectionLabel('Itinerary pace'),
            const SizedBox(height: AppSpacing.xs),
            Text(_pace.activityHint, style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.md),
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

            if (!widget.isEditing) ...<Widget>[
              const SizedBox(height: AppSpacing.xl),
              _SectionLabel('Status'),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                children: <Widget>[
                  for (final TripStatus s in <TripStatus>[
                    TripStatus.planning,
                    TripStatus.draft,
                  ])
                    ChoiceChip(
                      selected: _status == s.name,
                      label: Text(s.label),
                      onSelected: (_) => setState(() => _status = s.name),
                    ),
                ],
              ),
            ],

            const SizedBox(height: AppSpacing.xl),
            _SectionLabel('Interests'),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                for (final String option in interestOptions)
                  FilterChip(
                    label: Text(option),
                    selected: _interests.contains(option),
                    onSelected: (bool v) => setState(() {
                      v ? _interests.add(option) : _interests.remove(option);
                    }),
                  ),
              ],
            ),

            const SizedBox(height: AppSpacing.xl),
            _SectionLabel('Transport preference'),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                for (final String option in transportOptions)
                  FilterChip(
                    label: Text(option),
                    selected: _transport.contains(option),
                    onSelected: (bool v) => setState(() {
                      v ? _transport.add(option) : _transport.remove(option);
                    }),
                  ),
              ],
            ),

            const SizedBox(height: AppSpacing.xl),
            _SectionLabel('Accommodation preference'),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                for (final String option in accommodationOptions)
                  FilterChip(
                    label: Text(option),
                    selected: _accommodation.contains(option),
                    onSelected: (bool v) => setState(() {
                      v
                          ? _accommodation.add(option)
                          : _accommodation.remove(option);
                    }),
                  ),
              ],
            ),

            const SizedBox(height: AppSpacing.xl),
            TextFormField(
              controller: _dietary,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Dietary requirements',
                hintText: 'e.g. two vegetarians, one nut allergy',
                prefixIcon: Icon(Icons.restaurant_outlined),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _accessibility,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Accessibility needs',
                hintText: 'e.g. step-free access, limited walking',
                prefixIcon: Icon(Icons.accessible_outlined),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _description,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Description',
                prefixIcon: Icon(Icons.notes),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Private notes',
                hintText: 'Only visible to trip members',
                prefixIcon: Icon(Icons.lock_outline),
                alignLabelWithHint: true,
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.isEditing ? 'Save changes' : 'Create trip'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.titleSmall);
  }
}

class _DayCountRow extends StatelessWidget {
  const _DayCountRow({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  @override
  Widget build(BuildContext context) {
    final int days = end.difference(start).inDays + 1;
    final ThemeData theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Icon(
          Icons.event_note_outlined,
          size: 16,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '$days day${days == 1 ? '' : 's'} · ${DateFormatRange.of(start, end).label}',
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _TravelerStepper extends StatelessWidget {
  const _TravelerStepper({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  'Travellers',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text('$value', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
          IconButton(
            onPressed: value > 1 ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_circle_outline),
            tooltip: 'One fewer traveller',
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            onPressed: value < 40 ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'One more traveller',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _DestinationBuilder extends StatelessWidget {
  const _DestinationBuilder({
    required this.destinations,
    required this.onChanged,
  });

  final List<({String name, String? country, String? code})> destinations;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(Icons.place_outlined, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Destinations',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _add(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add'),
                  ),
                ],
              ),
              if (destinations.isEmpty)
                Text(
                  'Add every stop in order. Leave empty and you can add them later.',
                  style: Theme.of(context).textTheme.bodySmall,
                )
              else
                for (int i = 0; i < destinations.length; i++)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 12,
                      child: Text(
                        '${i + 1}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                    title: Text(destinations[i].name),
                    subtitle: destinations[i].country == null
                        ? null
                        : Text(destinations[i].country!),
                    trailing: IconButton(
                      onPressed: () {
                        destinations.removeAt(i);
                        onChanged();
                      },
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: 'Remove',
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _add(BuildContext context) async {
    final ({String name, String? code, String? country})? result =
        await showAppSheet<({String name, String? code, String? country})>(
          context: context,
          builder: (BuildContext context) => const _DestinationSheet(),
        );
    if (result == null) return;
    destinations.add(result);
    onChanged();
  }
}

class _DestinationSheet extends StatefulWidget {
  const _DestinationSheet();

  @override
  State<_DestinationSheet> createState() => _DestinationSheetState();
}

class _DestinationSheetState extends State<_DestinationSheet> {
  final TextEditingController _name = TextEditingController();

  /// Chosen country, or null if the user has not picked one yet.
  ///
  /// Held as a Country rather than free text so the ISO code is captured
  /// alongside the name. The name stays editable for a place the bundled list
  /// does not know about.
  Country? _country;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickCountry() async {
    final Country? picked = await showCountryPicker(
      context,
      initialCode: _country?.code.isEmpty ?? true ? null : _country?.code,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _country = picked;
      // Keep the city field in step so a user who picked "Japan, Tokyo" does
      // not then have to retype the city.
      if (picked.name.isNotEmpty && _name.text.trim().isEmpty) {
        _name.text = picked.name;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
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
            'Add a destination',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'City or place',
              prefixIcon: Icon(Icons.place_outlined),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // A searchable list rather than a free-text field: getting the ISO
          // code right matters later, because emergency contacts, visa links
          // and advisories are all looked up by country code.
          InkWell(
            onTap: _pickCountry,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Country',
                prefixIcon: const Icon(Icons.public),
                suffixIcon: IconButton(
                  tooltip: _country == null ? 'Choose a country' : 'Change',
                  icon: const Icon(Icons.arrow_drop_down),
                  onPressed: _pickCountry,
                ),
              ),
              child: Text(
                _country == null ? 'Choose a country' : _country!.name,
                style: _country == null
                    ? theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      )
                    : theme.textTheme.bodyLarge,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: () {
              final String name = _name.text.trim();
              if (name.isEmpty) return;
              Navigator.of(context).pop((
                name: name,
                code: _country?.code.isEmpty ?? true ? null : _country?.code,
                country: _country?.name.isEmpty ?? true
                    ? null
                    : _country?.name,
              ));
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

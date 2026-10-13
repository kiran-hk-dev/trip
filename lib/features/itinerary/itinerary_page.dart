import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/config/app_config.dart';
import '../../core/money/currency.dart';
import '../../core/theme/app_theme.dart';
import '../../data/demo/demo_fixtures.dart';
import '../../data/models/planning.dart';
import '../../data/models/trip.dart';
import '../../data/repositories.dart';
import '../../data/supabase_service.dart';
import '../../router/providers.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/form_fields.dart';

enum ItineraryView { list, calendar, map }

final itineraryDaysProvider = FutureProvider.autoDispose
    .family<List<ItineraryDay>, String>((Ref ref, String tripId) async {
      if (AppConfig.demoMode) return DemoFixtures.itineraryFor(tripId);
      return ref.watch(tripRepositoryProvider).itinerary.listDays(tripId);
    });

/// Day-by-day planner with list, calendar and map views.
class ItineraryPage extends ConsumerStatefulWidget {
  const ItineraryPage({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<ItineraryPage> createState() => _ItineraryPageState();
}

class _ItineraryPageState extends ConsumerState<ItineraryPage> {
  ItineraryView _view = ItineraryView.list;
  int _selectedDay = 0;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<ItineraryDay>> async = ref.watch(
      itineraryDaysProvider(widget.tripId),
    );
    final AsyncValue<Trip?> tripAsync = ref.watch(currentTripProvider);
    final Trip? trip = tripAsync.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Itinerary'),
        actions: <Widget>[
          IconButton(
            onPressed: () => context.push('/ai-planner'),
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Generate with AI',
          ),
        ],
      ),
      floatingActionButton: trip != null && trip.myRole.canEdit
          ? FloatingActionButton.extended(
              onPressed: () => _addItem(context),
              icon: const Icon(Icons.add),
              label: const Text('Add activity'),
            )
          : null,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object err, StackTrace _) => ErrorStateView(
          message: '$err',
          onRetry: () => ref.invalidate(itineraryDaysProvider(widget.tripId)),
        ),
        data: (List<ItineraryDay> days) {
          if (days.isEmpty) {
            return EmptyState(
              icon: Icons.map_outlined,
              title: 'No itinerary yet',
              message:
                  'Add activities day by day, or let the AI planner draft one you can edit '
                  'before you save anything.',
              action: FilledButton.icon(
                onPressed: () => context.push('/ai-planner'),
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Plan with AI'),
              ),
            );
          }
          final int index = _selectedDay.clamp(0, days.length - 1);
          return Column(
            children: <Widget>[
              _ViewSwitcher(
                view: _view,
                onChanged: (ItineraryView v) => setState(() => _view = v),
              ),
              _DayStrip(
                days: days,
                selected: index,
                onChanged: (int i) => setState(() => _selectedDay = i),
              ),
              Expanded(
                child: switch (_view) {
                  ItineraryView.list => _ListView(
                    days: days,
                    tripId: widget.tripId,
                  ),
                  ItineraryView.calendar => _CalendarView(days: days),
                  ItineraryView.map => _MapView(days: days),
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addItem(BuildContext context) async {
    final AsyncValue<List<ItineraryDay>> async = ref.read(
      itineraryDaysProvider(widget.tripId),
    );
    final List<ItineraryDay> days = async.value ?? const <ItineraryDay>[];
    if (days.isEmpty) return;

    final ItineraryDay? day = await showAppSheet<ItineraryDay>(
      context: context,
      builder: (BuildContext context) => _PickDaySheet(days: days),
    );
    if (day == null || !context.mounted) return;

    final bool? created = await showAppSheet<bool>(
      context: context,
      builder: (BuildContext context) =>
          _ItemSheet(dayId: day.id, tripId: widget.tripId),
    );
    if (created == true && context.mounted) {
      ref.invalidate(itineraryDaysProvider(widget.tripId));
      showFeedback(context, 'Activity added.');
    }
  }
}

class _ViewSwitcher extends StatelessWidget {
  const _ViewSwitcher({required this.view, required this.onChanged});

  final ItineraryView view;
  final ValueChanged<ItineraryView> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: SegmentedButton<ItineraryView>(
        segments: const <ButtonSegment<ItineraryView>>[
          ButtonSegment<ItineraryView>(
            value: ItineraryView.list,
            icon: Icon(Icons.view_agenda_outlined),
            label: Text('List'),
          ),
          ButtonSegment<ItineraryView>(
            value: ItineraryView.calendar,
            icon: Icon(Icons.calendar_month_outlined),
            label: Text('Calendar'),
          ),
          ButtonSegment<ItineraryView>(
            value: ItineraryView.map,
            icon: Icon(Icons.map_outlined),
            label: Text('Map'),
          ),
        ],
        selected: <ItineraryView>{view},
        onSelectionChanged: (Set<ItineraryView> s) => onChanged(s.first),
        showSelectedIcon: false,
      ),
    );
  }
}

class _DayStrip extends StatelessWidget {
  const _DayStrip({
    required this.days,
    required this.selected,
    required this.onChanged,
  });

  final List<ItineraryDay> days;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: days.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (BuildContext context, int i) {
          final ItineraryDay day = days[i];
          final bool isSelected = i == selected;
          return InkWell(
            onTap: () => onChanged(i),
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Container(
              width: 68,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    'Day ${day.dayNumber}',
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: isSelected ? Colors.white : null),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${day.date.day}/${day.date.month}',
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(color: isSelected ? Colors.white : null),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${day.items.length}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isSelected ? Colors.white70 : AppColors.inkFaint,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ListView extends ConsumerWidget {
  const _ListView({required this.days, required this.tripId});

  final List<ItineraryDay> days;
  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);

    return ReorderableListView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: days.length,
      onReorderItem: (int oldIndex, int newIndex) {
        // Reordering whole days is a display-only affordance here; activities
        // are reordered within a day from the trip repository.
        showFeedback(
          context,
          'Days are ordered by date and cannot be manually reordered.',
        );
      },
      itemBuilder: (BuildContext context, int i) {
        final ItineraryDay day = days[i];
        final List<List<ItineraryItem>> conflicts = day.conflicts;

        return Column(
          key: ValueKey<String>(day.id),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text('Day ${day.dayNumber}', style: theme.textTheme.titleSmall),
                const SizedBox(width: AppSpacing.sm),
                if (day.isToday)
                  const StatusPill(
                    label: 'Today',
                    dense: true,
                    tone: StatusTone.positive,
                  ),
                const Spacer(),
                Text(
                  day.date.toIso8601String().substring(0, 10),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            if (day.title != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(day.title!, style: theme.textTheme.bodyMedium),
              ),
            const SizedBox(height: AppSpacing.md),

            if (conflicts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: InlineBanner(
                  tone: StatusTone.warning,
                  icon: Icons.warning_amber_rounded,
                  message:
                      '${conflicts.length} overlapping ${conflicts.length == 1 ? 'activity' : 'activities'} '
                      'on this day. Adjust the times or move one.',
                ),
              ),

            if (day.items.isEmpty)
              AppCard(
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.free_breakfast_outlined),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        'Nothing planned yet.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              )
            else
              for (final ItineraryItem item in day.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _ItemTile(item: item, day: day),
                ),

            if (day.items.isNotEmpty)
              Text(
                'Estimated day cost: ${Money(day.estimatedCostMinor, day.costCurrency).format()}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(height: AppSpacing.xl),
          ],
        );
      },
    );
  }
}

class _ItemTile extends ConsumerStatefulWidget {
  const _ItemTile({required this.item, required this.day});

  final ItineraryItem item;
  final ItineraryDay day;

  @override
  ConsumerState<_ItemTile> createState() => _ItemTileState();
}

class _ItemTileState extends ConsumerState<_ItemTile> {
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ItineraryItem item = widget.item;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      onTap: () async {
        final bool? changed = await showAppSheet<bool>(
          context: context,
          builder: (BuildContext context) => _ItemSheet(
            dayId: item.dayId,
            tripId: item.tripId,
            existing: item,
          ),
        );
        if (changed == true) ref.invalidate(itineraryDaysProvider(item.tripId));
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Checkbox(
            value: item.completed,
            onChanged: (bool? v) async {
              await ref.read(tripRepositoryProvider).itinerary.updateItem(
                item.id,
                <String, dynamic>{'completed': v ?? false},
              );
              ref.invalidate(itineraryDaysProvider(item.tripId));
            },
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(item.kind.emoji, style: const TextStyle(fontSize: 15)),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        item.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          decoration: item.completed
                              ? TextDecoration.lineThrough
                              : null,
                          color: item.completed ? AppColors.inkFaint : null,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  <String>[
                    if (item.hasTime)
                      '${_hhmm(item.startTime)}–${_hhmm(item.endTime)}',
                    if (item.address != null) item.address!,
                    if (item.costMinor > 0)
                      Money(item.costMinor, item.costCurrency).format(),
                  ].join(' · '),
                  style: theme.textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.crossesMidnight)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: StatusPill(
                      label: 'Ends after midnight',
                      dense: true,
                      tone: StatusTone.warning,
                    ),
                  ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (String value) => _menu(value),
            itemBuilder: (BuildContext context) =>
                const <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(value: 'edit', child: Text('Edit')),
                  PopupMenuItem<String>(
                    value: 'duplicate',
                    child: Text('Duplicate'),
                  ),
                  PopupMenuItem<String>(value: 'up', child: Text('Move up')),
                  PopupMenuItem<String>(
                    value: 'down',
                    child: Text('Move down'),
                  ),
                  PopupMenuDivider(),
                  PopupMenuItem<String>(value: 'delete', child: Text('Delete')),
                ],
          ),
        ],
      ),
    );
  }

  Future<void> _menu(String action) async {
    final ItineraryItem item = widget.item;
    final ItineraryRepository repo = ref.read(tripRepositoryProvider).itinerary;
    final List<ItineraryItem> items = <ItineraryItem>[...widget.day.items];

    switch (action) {
      case 'duplicate':
        await repo.addItem(item.dayId, <String, dynamic>{
          ...item.toJson(),
          'id': null,
          'position': items.length,
        });
      case 'up':
      case 'down':
        final int i = items.indexWhere((ItineraryItem x) => x.id == item.id);
        final int j = action == 'up' ? i - 1 : i + 1;
        if (i < 0 || j < 0 || j >= items.length) return;
        final ItineraryItem tmp = items[i];
        items[i] = items[j];
        items[j] = tmp;
        await repo.reorderItems(item.dayId, items);
      case 'delete':
        final bool ok = await confirmDestructive(
          context,
          title: 'Delete "${item.title}"?',
          message: 'This activity is removed from the day.',
          confirmLabel: 'Delete',
        );
        if (!ok) return;
        await repo.deleteItem(item.id);
      case 'edit':
        final bool? changed = await showAppSheet<bool>(
          context: context,
          builder: (BuildContext context) => _ItemSheet(
            dayId: item.dayId,
            tripId: item.tripId,
            existing: item,
          ),
        );
        if (changed == true) {
          ref.invalidate(itineraryDaysProvider(item.tripId));
          return;
        }
        return;
    }

    ref.invalidate(itineraryDaysProvider(item.tripId));
  }
}

String _hhmm(DateTime? t) {
  if (t == null) return '';
  return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

class _CalendarView extends StatelessWidget {
  const _CalendarView({required this.days});

  final List<ItineraryDay> days;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: days.length,
      itemBuilder: (BuildContext context, int i) {
        final ItineraryDay day = days[i];
        return AppCard(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Day ${day.dayNumber} · ${day.date.toIso8601String().substring(0, 10)}',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              if (day.items.isEmpty)
                Text('Nothing planned', style: theme.textTheme.bodySmall)
              else
                for (final ItineraryItem item in day.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: <Widget>[
                        SizedBox(
                          width: 46,
                          child: Text(
                            item.startTime == null
                                ? '—'
                                : _hhmm(item.startTime),
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            item.title,
                            style: theme.textTheme.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}

/// Map view of everything that has coordinates.
///
/// Travel times are NOT estimated unless a routing provider is configured, so
/// the screen says so rather than inventing a number.
class _MapView extends StatelessWidget {
  const _MapView({required this.days});

  final List<ItineraryDay> days;

  @override
  Widget build(BuildContext context) {
    final List<ItineraryItem> located = <ItineraryItem>[
      for (final ItineraryDay d in days)
        for (final ItineraryItem i in d.items)
          if (i.hasLocation) i,
    ];

    if (located.isEmpty) {
      return const EmptyState(
        icon: Icons.location_off_outlined,
        title: 'No locations yet',
        message: 'Add an address or coordinates to an activity and it will appear on the map.',
      );
    }

    return Stack(
      children: <Widget>[
        FlutterMap(
          options: MapOptions(
            initialCenter: LatLng(
              located.first.latitude!,
              located.first.longitude!,
            ),
            initialZoom: 12,
          ),
          children: <Widget>[
            TileLayer(
              urlTemplate: AppConfig.mapTileUrl,
              userAgentPackageName: AppConfig.mapUserAgent,
            ),
            MarkerLayer(
              markers: <Marker>[
                for (final ItineraryItem item in located)
                  Marker(
                    point: LatLng(item.latitude!, item.longitude!),
                    width: 40,
                    height: 40,
                    child: Tooltip(
                      message: item.title,
                      child: const Icon(
                        Icons.place,
                        color: AppColors.teal,
                        size: 30,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        Positioned(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          bottom: AppSpacing.lg,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                '${located.length} located ${located.length == 1 ? 'activity' : 'activities'}. '
                'Travel times between stops are not shown — TripSplit does not estimate '
                'them without a configured routing provider.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PickDaySheet extends StatelessWidget {
  const _PickDaySheet({required this.days});

  final List<ItineraryDay> days;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Which day?', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.lg),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: days.length,
              itemBuilder: (BuildContext context, int i) => ListTile(
                title: Text('Day ${days[i].dayNumber}'),
                subtitle: Text(days[i].date.toIso8601String().substring(0, 10)),
                onTap: () => Navigator.of(context).pop(days[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemSheet extends ConsumerStatefulWidget {
  const _ItemSheet({required this.dayId, required this.tripId, this.existing});

  final String dayId;
  final String tripId;
  final ItineraryItem? existing;

  @override
  ConsumerState<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends ConsumerState<_ItemSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _address;
  late final TextEditingController _cost;
  late final TextEditingController _bookingUrl;
  late final TextEditingController _bookingRef;
  late ItineraryItemKind _kind;
  late String _currency;
  TimeOfDay? _start;
  TimeOfDay? _end;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    final ItineraryItem? e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _address = TextEditingController(text: e?.address ?? '');
    _bookingUrl = TextEditingController(text: e?.bookingUrl ?? '');
    _bookingRef = TextEditingController(text: e?.bookingReference ?? '');
    _cost = TextEditingController(
      text: e == null || e.costMinor == 0
          ? ''
          : Money(e.costMinor, e.costCurrency).format(locale: 'en'),
    );
    _kind = e?.kind ?? ItineraryItemKind.attraction;
    _currency = e?.costCurrency ?? Currencies.defaultCode;
    _completed = e?.completed ?? false;
    _start = e?.startTime == null
        ? null
        : TimeOfDay(hour: e!.startTime!.hour, minute: e.startTime!.minute);
    _end = e?.endTime == null
        ? null
        : TimeOfDay(hour: e!.endTime!.hour, minute: e.endTime!.minute);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _address.dispose();
    _cost.dispose();
    _bookingUrl.dispose();
    _bookingRef.dispose();
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
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                widget.existing == null ? 'Add an activity' : 'Edit activity',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _title,
                autofocus: widget.existing == null,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'What are you doing?',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (String? v) => (v == null || v.trim().isEmpty)
                    ? 'Give the activity a name.'
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<ItineraryItemKind>(
                initialValue: _kind,
                decoration: const InputDecoration(labelText: 'Type'),
                items: <DropdownMenuItem<ItineraryItemKind>>[
                  for (final ItineraryItemKind k in ItineraryItemKind.values)
                    DropdownMenuItem<ItineraryItemKind>(
                      value: k,
                      child: Text('${k.emoji}  ${k.label}'),
                    ),
                ],
                onChanged: (ItineraryItemKind? k) =>
                    setState(() => _kind = k ?? _kind),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TimeField(
                      label: 'Starts',
                      value: _start,
                      onChanged: (TimeOfDay t) => setState(() => _start = t),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TimeField(
                      label: 'Ends',
                      value: _end,
                      onChanged: (TimeOfDay t) => setState(() => _end = t),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _address,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  prefixIcon: Icon(Icons.place_outlined),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              MoneyField(
                label: 'Estimated cost',
                currency: _currency,
                controller: _cost,
                onCurrencyChanged: (String c) => setState(() => _currency = c),
                helperText: 'An estimate you control — TripSplit does not look up prices.',
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _description,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _bookingRef,
                decoration: const InputDecoration(
                  labelText: 'Booking reference',
                  prefixIcon: Icon(Icons.tag),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _bookingUrl,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Booking link',
                  prefixIcon: Icon(Icons.link),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SwitchListTile(
                value: _completed,
                onChanged: (bool v) => setState(() => _completed = v),
                contentPadding: EdgeInsets.zero,
                title: const Text('Done'),
                subtitle: const Text(
                  'Tick this once you have actually done it.',
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: _save,
                child: Text(
                  widget.existing == null ? 'Add activity' : 'Save changes',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final Map<String, dynamic> data = <String, dynamic>{
      'day_id': widget.dayId,
      'trip_id': widget.tripId,
      'title': _title.text.trim(),
      'kind': _kind.id,
      'description': _description.text.trim(),
      'address': _address.text.trim(),
      'start_time': _start == null ? null : _formatTime(_start!),
      'end_time': _end == null ? null : _formatTime(_end!),
      'cost_minor': Money.tryParse(_cost.text, _currency).minorUnits,
      'cost_currency': _currency,
      'booking_reference': _bookingRef.text.trim(),
      'booking_url': _bookingUrl.text.trim(),
      'completed': _completed,
    };

    try {
      final ItineraryRepository repo = ref
          .read(tripRepositoryProvider)
          .itinerary;
      if (widget.existing == null) {
        final List<ItineraryDay> all = await repo.listDays(widget.tripId);
        final int position = all
            .firstWhere(
              (ItineraryDay d) => d.id == widget.dayId,
              orElse: () => all.isEmpty
                  ? ItineraryDay(
                      id: '',
                      tripId: '',
                      dayNumber: 1,
                      date: DateTime.now(),
                    )
                  : all.first,
            )
            .items
            .length;
        await repo.addItem(widget.dayId, <String, dynamic>{
          ...data,
          'position': position,
        });
      } else {
        await repo.updateItem(widget.existing!.id, data);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (err) {
      if (mounted) {
        showFeedback(
          context,
          err is RepositoryException
              ? err.message
              : 'Could not save that activity.',
          isError: true,
        );
      }
    }
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

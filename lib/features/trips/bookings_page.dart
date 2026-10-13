import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/money/currency.dart';
import '../../core/theme/app_theme.dart';
import '../../data/demo/demo_fixtures.dart';
import '../../data/models/planning.dart';
import '../../data/models/trip.dart';
import '../../data/supabase_service.dart';
import '../../router/providers.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/form_fields.dart';

/// Organises confirmed bookings. It does NOT make reservations — it records
/// ones you have already made, with the reference you were given.
class BookingsPage extends ConsumerStatefulWidget {
  const BookingsPage({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends ConsumerState<BookingsPage> {
  @override
  Widget build(BuildContext context) {
    final AsyncValue<Trip?> tripAsync = ref.watch(currentTripProvider);
    final Trip? trip = tripAsync.value;

    return Scaffold(
      appBar: AppBar(title: const Text('Bookings')),
      floatingActionButton: trip != null && trip.myRole.canEdit
          ? FloatingActionButton.extended(
              onPressed: () => _edit(context, null),
              icon: const Icon(Icons.add),
              label: const Text('Add booking'),
            )
          : null,
      body: Column(
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              0,
            ),
            child: InlineBanner(
              message: 'TripSplit records bookings you have already made. It does not reserve anything and cannot confirm availability or prices.',
              tone: StatusTone.info,
              icon: Icons.info_outline,
            ),
          ),
          Expanded(
            child: AppConfig.demoMode
                ? _DemoList(tripId: widget.tripId)
                : FutureBuilder<List<Booking>>(
                    future: ref
                        .watch(tripRepositoryProvider)
                        .bookings
                        .list(widget.tripId),
                    builder:
                        (
                          BuildContext context,
                          AsyncSnapshot<List<Booking>> snapshot,
                        ) {
                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          final List<Booking> bookings = snapshot.data!;
                          if (bookings.isEmpty) {
                            return EmptyState(
                              icon: Icons.confirmation_number_outlined,
                              title: 'No bookings yet',
                              message: 'Add the flights, trains, hotels and restaurant reservations you have already made so the whole group has the references.',
                              action: FilledButton.icon(
                                onPressed: () => _edit(context, null),
                                icon: const Icon(Icons.add),
                                label: const Text('Add a booking'),
                              ),
                            );
                          }
                          return ListView.builder(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            itemCount: bookings.length,
                            itemBuilder: (BuildContext context, int i) =>
                                _BookingCard(
                                  booking: bookings[i],
                                  onEdit: () => _edit(context, bookings[i]),
                                  onDelete: () => _delete(context, bookings[i]),
                                ),
                          );
                        },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, Booking? existing) async {
    if (AppConfig.demoMode) {
      showFeedback(context, 'Editing is disabled in demo mode.', isError: true);
      return;
    }
    final BookingDraft? draft = await showAppSheet<BookingDraft>(
      context: context,
      builder: (BuildContext context) => _BookingSheet(existing: existing),
    );
    if (draft == null) return;

    try {
      await ref
          .read(tripRepositoryProvider)
          .bookings
          .upsert(widget.tripId, draft.toJson(), id: existing?.id);
      ref.invalidate(tripRepositoryProvider);
      if (context.mounted) {
        showFeedback(
          context,
          existing == null ? 'Booking added.' : 'Booking updated.',
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

  Future<void> _delete(BuildContext context, Booking booking) async {
    if (AppConfig.demoMode) return;
    final bool ok = await confirmDestructive(
      context,
      title: 'Delete this booking?',
      message:
          'Removes "${booking.title}". Any uploaded attachments stay in your documents.',
      confirmLabel: 'Delete',
    );
    if (!ok) return;
    await ref.read(tripRepositoryProvider).bookings.delete(booking.id);
    ref.invalidate(tripRepositoryProvider);
  }
}

class _DemoList extends StatelessWidget {
  const _DemoList({required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context) {
    final List<Booking> bookings = DemoFixtures.bookingsFor(tripId);
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: bookings.length,
      itemBuilder: (BuildContext context, int i) =>
          _BookingCard(booking: bookings[i]),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking, this.onEdit, this.onDelete});

  final Booking booking;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      onTap: onEdit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(booking.kind.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      booking.title,
                      style: theme.textTheme.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(booking.provider, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              StatusPill(
                label: booking.status.label,
                dense: true,
                tone: switch (booking.status) {
                  BookingStatus.confirmed => StatusTone.positive,
                  BookingStatus.cancelled => StatusTone.danger,
                  BookingStatus.refunded => StatusTone.warning,
                  _ => StatusTone.neutral,
                },
              ),
            ],
          ),
          if (booking.confirmationReference != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                const Icon(Icons.tag, size: 14),
                const SizedBox(width: AppSpacing.sm),
                SelectableText(
                  booking.confirmationReference!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                    letterSpacing: 0.6,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: booking.confirmationReference!),
                    );
                    showFeedback(context, 'Reference copied');
                  },
                  icon: const Icon(Icons.copy, size: 15),
                  tooltip: 'Copy reference',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
          const Divider(height: AppSpacing.xl),
          if (booking.origin != null || booking.destination != null)
            DetailRow(
              label: 'Route',
              value: <String?>[
                booking.origin,
                booking.destination,
              ].whereType<String>().join(' → '),
              icon: Icons.route_outlined,
            ),
          if (booking.startsAt != null)
            DetailRow(
              label: 'When',
              value: _fmt(booking.startsAt!),
              icon: Icons.event_outlined,
            ),
          DetailRow(
            label: 'Paid',
            value: Money(booking.amountPaidMinor, booking.currency).format(),
            icon: Icons.payments_outlined,
          ),
          if (booking.cancellationDeadline != null)
            DetailRow(
              label: 'Cancel by',
              value: _fmt(booking.cancellationDeadline!),
              icon: booking.cancellationUrgent
                  ? Icons.warning_amber_rounded
                  : Icons.event_busy_outlined,
              valueColor: booking.cancellationUrgent ? AppColors.danger : null,
            ),
          if (booking.cancellationUrgent)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: StatusPill(
                label: 'Cancellation deadline is close',
                tone: StatusTone.danger,
                icon: Icons.priority_high,
                dense: true,
              ),
            ),
          if (booking.externalUrl != null && booking.externalUrl!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: OutlinedButton.icon(
                onPressed: () => _open(context, booking.externalUrl!),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Open booking page'),
              ),
            ),
          if (onDelete != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: TextButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Delete'),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _fmt(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

Future<void> _open(BuildContext context, String url) async {
  final Uri? uri = Uri.tryParse(url);
  if (uri == null) {
    showFeedback(context, 'That link is not valid.', isError: true);
    return;
  }
  showFeedback(context, 'Opening $url');
}

class BookingDraft {
  const BookingDraft({
    required this.kind,
    required this.provider,
    required this.title,
    this.reference,
    this.origin,
    this.destination,
    this.startsAt,
    this.address,
    this.amountPaidMinor = 0,
    this.currency = Currencies.defaultCode,
    this.cancellationDeadline,
    this.status = BookingStatus.confirmed,
    this.externalUrl,
    this.notes,
  });

  final BookingKind kind;
  final String provider;
  final String title;
  final String? reference;
  final String? origin;
  final String? destination;
  final DateTime? startsAt;
  final String? address;
  final int amountPaidMinor;
  final String currency;
  final DateTime? cancellationDeadline;
  final BookingStatus status;
  final String? externalUrl;
  final String? notes;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'kind': kind.id,
    'provider': provider,
    'title': title,
    'confirmation_reference': reference,
    'origin': origin,
    'destination': destination,
    'starts_at': startsAt?.toUtc().toIso8601String(),
    'address': address,
    'amount_paid_minor': amountPaidMinor,
    'currency': currency,
    'cancellation_deadline': cancellationDeadline?.toUtc().toIso8601String(),
    'status': status.id,
    'external_url': externalUrl,
    'notes': notes,
  };
}

class _BookingSheet extends StatefulWidget {
  const _BookingSheet({this.existing});

  final Booking? existing;

  @override
  State<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<_BookingSheet> {
  late BookingKind _kind;
  late BookingStatus _status;
  late final TextEditingController _provider;
  late final TextEditingController _title;
  late final TextEditingController _reference;
  late final TextEditingController _origin;
  late final TextEditingController _destination;
  late final TextEditingController _address;
  late final TextEditingController _amount;
  late final TextEditingController _url;
  late final TextEditingController _notes;
  late String _currency;
  DateTime? _startsAt;
  DateTime? _deadline;

  @override
  void initState() {
    super.initState();
    final Booking? b = widget.existing;
    _kind = b?.kind ?? BookingKind.flight;
    _status = b?.status ?? BookingStatus.confirmed;
    _provider = TextEditingController(text: b?.provider ?? '');
    _title = TextEditingController(text: b?.title ?? '');
    _reference = TextEditingController(text: b?.confirmationReference ?? '');
    _origin = TextEditingController(text: b?.origin ?? '');
    _destination = TextEditingController(text: b?.destination ?? '');
    _address = TextEditingController(text: b?.address ?? '');
    _amount = TextEditingController(
      text: b == null || b.amountPaidMinor == 0
          ? ''
          : Money(b.amountPaidMinor, b.currency).format(locale: 'en'),
    );
    _url = TextEditingController(text: b?.externalUrl ?? '');
    _notes = TextEditingController(text: b?.notes ?? '');
    _currency = b?.currency ?? Currencies.defaultCode;
    _startsAt = b?.startsAt;
    _deadline = b?.cancellationDeadline;
  }

  @override
  void dispose() {
    _provider.dispose();
    _title.dispose();
    _reference.dispose();
    _origin.dispose();
    _destination.dispose();
    _address.dispose();
    _amount.dispose();
    _url.dispose();
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
              widget.existing == null ? 'Add a booking' : 'Edit booking',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.lg),
            DropdownButtonFormField<BookingKind>(
              initialValue: _kind,
              decoration: const InputDecoration(labelText: 'Type'),
              items: <DropdownMenuItem<BookingKind>>[
                for (final BookingKind k in BookingKind.values)
                  DropdownMenuItem<BookingKind>(
                    value: k,
                    child: Text('${k.emoji}  ${k.label}'),
                  ),
              ],
              onChanged: (BookingKind? k) => setState(() => _kind = k ?? _kind),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Outbound flight to Hong Kong',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _provider,
              decoration: const InputDecoration(labelText: 'Provider'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _reference,
              decoration: const InputDecoration(
                labelText: 'Confirmation reference',
                prefixIcon: Icon(Icons.tag),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _origin,
                    decoration: const InputDecoration(labelText: 'From'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextField(
                    controller: _destination,
                    decoration: const InputDecoration(labelText: 'To'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _OptionalDateTime(
              label: 'Date and time',
              value: _startsAt,
              onChanged: (DateTime? v) => setState(() => _startsAt = v),
            ),
            const SizedBox(height: AppSpacing.md),
            MoneyField(
              label: 'Amount paid',
              currency: _currency,
              controller: _amount,
              onCurrencyChanged: (String c) => setState(() => _currency = c),
            ),
            const SizedBox(height: AppSpacing.md),
            _OptionalDateTime(
              label: 'Free cancellation until',
              value: _deadline,
              onChanged: (DateTime? v) => setState(() => _deadline = v),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<BookingStatus>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: <DropdownMenuItem<BookingStatus>>[
                for (final BookingStatus s in BookingStatus.values)
                  DropdownMenuItem<BookingStatus>(
                    value: s,
                    child: Text(s.label),
                  ),
              ],
              onChanged: (BookingStatus? s) =>
                  setState(() => _status = s ?? _status),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _address,
              decoration: const InputDecoration(
                labelText: 'Address',
                prefixIcon: Icon(Icons.place_outlined),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _url,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Booking link',
                prefixIcon: Icon(Icons.link),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _notes,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: () {
                if (_title.text.trim().isEmpty) return;
                Navigator.of(context).pop(
                  BookingDraft(
                    kind: _kind,
                    provider: _provider.text.trim().isEmpty
                        ? 'Unknown'
                        : _provider.text.trim(),
                    title: _title.text.trim(),
                    reference: _emptyToNull(_reference.text),
                    origin: _emptyToNull(_origin.text),
                    destination: _emptyToNull(_destination.text),
                    startsAt: _startsAt,
                    address: _emptyToNull(_address.text),
                    amountPaidMinor: Money.tryParse(
                      _amount.text,
                      _currency,
                    ).minorUnits,
                    currency: _currency,
                    cancellationDeadline: _deadline,
                    status: _status,
                    externalUrl: _emptyToNull(_url.text),
                    notes: _emptyToNull(_notes.text),
                  ),
                );
              },
              child: Text(
                widget.existing == null ? 'Add booking' : 'Save changes',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionalDateTime extends StatelessWidget {
  const _OptionalDateTime({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: DateField(
            label: value == null ? label : '$label · ${_fmt(value!)}',
            value: value ?? DateTime.now(),
            firstDate: DateTime.now().subtract(const Duration(days: 365 * 3)),
            onChanged: (DateTime d) => onChanged(d),
          ),
        ),
        if (value != null)
          IconButton(
            onPressed: () => onChanged(null),
            icon: const Icon(Icons.clear),
            tooltip: 'Clear',
          ),
      ],
    );
  }
}

String? _emptyToNull(String value) =>
    value.trim().isEmpty ? null : value.trim();

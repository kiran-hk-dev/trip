import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/reference.dart';
import '../../data/models/trip.dart';
import '../../data/supabase_service.dart';
import '../../router/providers.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/form_fields.dart';

/// Visa and entry-requirement organiser.
///
/// This screen never states what a rule IS. It records what the user found on
/// an official page, keeps the source link and the date it was checked, and
/// links out to the official publisher.
class VisaPage extends ConsumerStatefulWidget {
  const VisaPage({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<VisaPage> createState() => _VisaPageState();
}

class _VisaPageState extends ConsumerState<VisaPage> {
  @override
  Widget build(BuildContext context) {
    final AsyncValue<Trip?> tripAsync = ref.watch(currentTripProvider);
    final Trip? trip = tripAsync.value;

    return Scaffold(
      appBar: AppBar(title: const Text('Visa & entry')),
      floatingActionButton: trip != null && trip.myRole.canEdit
          ? FloatingActionButton.extended(
              onPressed: () => _edit(context, null),
              icon: const Icon(Icons.add),
              label: const Text('Add destination'),
            )
          : null,
      body: AppConfig.demoMode
          ? const _VisaDemoBody()
          : FutureBuilder<List<VisaRecord>>(
              future: ref
                  .watch(tripRepositoryProvider)
                  .emergency
                  .visaRecords(widget.tripId),
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<List<VisaRecord>> snapshot,
                  ) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.data!.isEmpty) {
                      return EmptyState(
                        icon: Icons.assignment_outlined,
                        title: 'No destinations recorded',
                        message: 'Add each destination you will enter so you can track what you checked and where you found it.',
                        action: FilledButton.icon(
                          onPressed: () => _edit(context, null),
                          icon: const Icon(Icons.add),
                          label: const Text('Add a destination'),
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      itemCount: snapshot.data!.length,
                      itemBuilder: (BuildContext context, int i) =>
                          VisaRecordCard(
                            record: snapshot.data![i],
                            onEdit: () => _edit(context, snapshot.data![i]),
                          ),
                    );
                  },
            ),
    );
  }

  Future<void> _edit(BuildContext context, VisaRecord? existing) async {
    if (AppConfig.demoMode) {
      showFeedback(context, 'Editing is disabled in demo mode.', isError: true);
      return;
    }
    final Trip? trip = ref.read(currentTripProvider).value;
    final VisaRecord? draft = await showAppSheet<VisaRecord>(
      context: context,
      builder: (BuildContext context) => VisaRecordSheet(
        tripId: widget.tripId,
        existing: existing,
        defaultNationality: trip?.ownerId == null ? null : null,
      ),
    );
    if (draft == null) return;
    try {
      await ref.read(tripRepositoryProvider).emergency.upsertVisaRecord(draft);
      ref.invalidate(tripRepositoryProvider);
      if (context.mounted) showFeedback(context, 'Visa record saved.');
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

/// Shows a record with an explicit "you confirmed this" framing rather than
/// an authoritative claim.
class VisaRecordCard extends StatelessWidget {
  const VisaRecordCard({super.key, required this.record, this.onEdit});

  final VisaRecord record;
  final VoidCallback? onEdit;

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
              Expanded(
                child: Text(
                  record.destinationCountry,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              StatusPill(
                label: record.statusLabel,
                dense: true,
                tone: switch (record.status) {
                  'approved' => StatusTone.positive,
                  'required' => StatusTone.warning,
                  'expired' => StatusTone.danger,
                  _ => StatusTone.neutral,
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          DetailRow(
            label: 'Nationality used',
            value: record.nationalityCountry,
          ),
          if (record.residenceCountry != null)
            DetailRow(label: 'Residence', value: record.residenceCountry!),
          if (record.travelPurpose != null)
            DetailRow(label: 'Purpose', value: record.travelPurpose!),
          if (record.transitCountries.isNotEmpty)
            DetailRow(
              label: 'Transit',
              value: record.transitCountries.join(', '),
            ),
          if (record.entryDate != null)
            DetailRow(
              label: 'Entry',
              value: record.entryDate!.toIso8601String().substring(0, 10),
            ),
          if (record.authorizationType != null)
            DetailRow(label: 'Type', value: record.authorizationType!),
          const Divider(height: AppSpacing.xl),
          Row(
            children: <Widget>[
              Icon(
                Icons.verified_user_outlined,
                size: 14,
                color: theme.textTheme.bodySmall?.color,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  record.verification == VerificationState.verified
                      ? 'Checked against the official source'
                      : 'You confirmed this. TripSplit has not verified it.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              if (record.lastVerifiedAt != null)
                Text(
                  record.lastVerifiedAt!.toIso8601String().substring(0, 10),
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ),
          if (record.officialUrl != null &&
              record.officialUrl!.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: () => showFeedback(
                context,
                'Open the official source to re-check.',
              ),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Open official source'),
            ),
          ],
        ],
      ),
    );
  }
}

class VisaRecordSheet extends StatefulWidget {
  const VisaRecordSheet({
    super.key,
    required this.tripId,
    this.existing,
    this.defaultNationality,
  });

  final String tripId;
  final VisaRecord? existing;
  final String? defaultNationality;

  @override
  State<VisaRecordSheet> createState() => _VisaRecordSheetState();
}

class _VisaRecordSheetState extends State<VisaRecordSheet> {
  late final TextEditingController _destination;
  late final TextEditingController _nationality;
  late final TextEditingController _residence;
  late final TextEditingController _purpose;
  late final TextEditingController _transit;
  late final TextEditingController _type;
  late final TextEditingController _url;
  late final TextEditingController _notes;
  late String _status;
  DateTime? _entry;
  DateTime? _exit;

  @override
  void initState() {
    super.initState();
    final VisaRecord? r = widget.existing;
    _destination = TextEditingController(text: r?.destinationCountry ?? '');
    _nationality = TextEditingController(
      text: r?.nationalityCountry ?? widget.defaultNationality ?? '',
    );
    _residence = TextEditingController(text: r?.residenceCountry ?? '');
    _purpose = TextEditingController(text: r?.travelPurpose ?? '');
    _transit = TextEditingController(
      text: r?.transitCountries.join(', ') ?? '',
    );
    _type = TextEditingController(text: r?.authorizationType ?? '');
    _url = TextEditingController(text: r?.officialUrl ?? '');
    _notes = TextEditingController(text: r?.notes ?? '');
    _status = r?.status ?? 'not_checked';
    _entry = r?.entryDate;
    _exit = r?.exitDate;
  }

  @override
  void dispose() {
    _destination.dispose();
    _nationality.dispose();
    _residence.dispose();
    _purpose.dispose();
    _transit.dispose();
    _type.dispose();
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
              widget.existing == null
                  ? 'Add a destination'
                  : 'Edit destination',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Requirements depend on your nationality, residence, transit route and purpose of travel. '
              'Record what you found on the official page, and keep the link.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _destination,
              decoration: const InputDecoration(
                labelText: 'Destination country',
                prefixIcon: Icon(Icons.flag_outlined),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _nationality,
              decoration: const InputDecoration(
                labelText: 'Nationality used for the check',
                helperText: 'The passport you will travel with.',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _residence,
              decoration: const InputDecoration(
                labelText: 'Country of residence (if different)',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _purpose,
              decoration: const InputDecoration(
                labelText: 'Purpose of travel',
                hintText: 'tourism / business / visiting family',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _transit,
              decoration: const InputDecoration(
                labelText: 'Transit countries',
                helperText: 'Separate with commas.',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: DateField(
                    label: 'Entry date',
                    value: _entry ?? DateTime.now(),
                    firstDate: DateTime.now().subtract(
                      const Duration(days: 365),
                    ),
                    onChanged: (DateTime d) => setState(() => _entry = d),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: DateField(
                    label: 'Exit date',
                    value: _exit ?? DateTime.now(),
                    firstDate: DateTime.now().subtract(
                      const Duration(days: 365),
                    ),
                    onChanged: (DateTime d) => setState(() => _exit = d),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _type,
              decoration: const InputDecoration(
                labelText: 'Visa or authorisation type',
                hintText: 'eVisa / sticker visa / eTA / none',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(
                labelText: 'Status you confirmed',
              ),
              items: <DropdownMenuItem<String>>[
                for (final ({String id, String label}) s in VisaRecord.statuses)
                  DropdownMenuItem<String>(value: s.id, child: Text(s.label)),
              ],
              onChanged: (String? v) => setState(() => _status = v ?? _status),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _url,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Official source URL',
                prefixIcon: Icon(Icons.link),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: () {
                if (_destination.text.trim().isEmpty) return;
                Navigator.of(context).pop(
                  VisaRecord(
                    id: widget.existing?.id ?? '',
                    tripId: widget.tripId,
                    destinationCountry: _destination.text.trim(),
                    nationalityCountry: _nationality.text.trim(),
                    residenceCountry: _nullIfEmpty(_residence.text),
                    transitCountries: _transit.text
                        .split(',')
                        .map((String s) => s.trim())
                        .where((String s) => s.isNotEmpty)
                        .toList(),
                    travelPurpose: _nullIfEmpty(_purpose.text),
                    entryDate: _entry,
                    exitDate: _exit,
                    authorizationType: _nullIfEmpty(_type.text),
                    status: _status,
                    officialUrl: _nullIfEmpty(_url.text),
                    lastVerifiedAt: DateTime.now(),
                    notes: _nullIfEmpty(_notes.text),
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class _VisaDemoBody extends StatelessWidget {
  const _VisaDemoBody();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        const InlineBanner(
          message: 'TripSplit cannot tell you whether you need a visa. Requirements change, and they depend on your nationality, residence, transit route and purpose.',
          tone: StatusTone.warning,
          icon: Icons.gavel_outlined,
        ),
        const SizedBox(height: AppSpacing.lg),
        VisaRecordCard(
          record: const VisaRecord(
            id: 'demo-visa-1',
            tripId: 'demo-trip-hong-kong',
            destinationCountry: 'Hong Kong SAR',
            nationalityCountry: 'United Kingdom',
            residenceCountry: 'United Kingdom',
            travelPurpose: 'tourism',
            entryDate: null,
            status: 'not_checked',
            officialUrl: 'https://www.immd.gov.hk/eng/services/visas/visas-entry-permit.html',
            sourceOrganization: 'Hong Kong Immigration Department',
          ),
        ),
        VisaRecordCard(
          record: const VisaRecord(
            id: 'demo-visa-2',
            tripId: 'demo-trip-hong-kong',
            destinationCountry: 'China (Shenzhen)',
            nationalityCountry: 'United Kingdom',
            travelPurpose: 'tourism',
            status: 'not_checked',
            officialUrl: 'https://www.immd.gov.hk/eng/services/visas/visas-entry-permit.html',
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        OutlinedButton.icon(
          onPressed: () => showFeedback(
            context,
            'In a connected build this opens the official immigration page in your browser.',
          ),
          icon: const Icon(Icons.open_in_new),
          label: const Text('Open the official immigration directory'),
        ),
      ],
    );
  }
}

String? _nullIfEmpty(String value) =>
    value.trim().isEmpty ? null : value.trim();

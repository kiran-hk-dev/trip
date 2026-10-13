import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/money/currency.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/reference.dart';
import '../../data/supabase_service.dart';
import '../../router/providers.dart';
import '../../shared/widgets/common.dart';

class DestinationDetailPage extends ConsumerStatefulWidget {
  const DestinationDetailPage({super.key, required this.destinationId});

  final String destinationId;

  @override
  ConsumerState<DestinationDetailPage> createState() =>
      _DestinationDetailPageState();
}

class _DestinationDetailPageState extends ConsumerState<DestinationDetailPage> {
  final MapController _map = MapController();
  bool _showMap = true;
  bool _saved = false;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Destination?> async = ref.watch(
      destinationProvider(widget.destinationId),
    );

    return Scaffold(
      appBar: AppBar(
        actions: <Widget>[
          IconButton(
            onPressed: () => setState(() => _showMap = !_showMap),
            icon: Icon(_showMap ? Icons.map_outlined : Icons.photo_outlined),
            tooltip: _showMap ? 'Hide map' : 'Show map',
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object err, StackTrace _) =>
            ErrorStateView(message: 'Could not load this destination.\n$err'),
        data: (Destination? d) {
          if (d == null) {
            return const EmptyState(
              icon: Icons.travel_explore,
              title: 'Destination not found',
              message: 'It may have been removed from the catalogue.',
            );
          }
          return _body(context, d);
        },
      ),
    );
  }

  Widget _body(BuildContext context, Destination d) {
    final ThemeData theme = Theme.of(context);

    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        if (d.imageUrl != null)
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.network(
              d.imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
              ),
              loadingBuilder: (
                BuildContext c,
                Widget child,
                ImageChunkEvent? p,
              ) => p == null ? child : const SkeletonBox(),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(d.name, style: theme.textTheme.headlineSmall),
              Text(
                <String?>[d.city, d.country].whereType<String>().join(', '),
                style: theme.textTheme.bodyMedium,
              ),
              if (d.summary != null) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                Text(d.summary!, style: theme.textTheme.bodyLarge),
              ],
              const SizedBox(height: AppSpacing.lg),

              if (_showMap && d.hasCoordinates)
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: SizedBox(
                    height: 220,
                    child: FlutterMap(
                      mapController: _map,
                      options: MapOptions(
                        initialCenter: LatLng(d.latitude!, d.longitude!),
                        initialZoom: 11,
                      ),
                      children: <Widget>[
                        TileLayer(
                          urlTemplate: AppConfig.mapTileUrl,
                          userAgentPackageName: AppConfig.mapUserAgent,
                        ),
                        MarkerLayer(
                          markers: <Marker>[
                            Marker(
                              point: LatLng(d.latitude!, d.longitude!),
                              width: 40,
                              height: 40,
                              child: const Icon(
                                Icons.place,
                                color: AppColors.danger,
                                size: 34,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

              if (_showMap && d.hasCoordinates) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Map tiles by ${AppConfig.mapTileAttribution}. Positions come from the '
                  'TripSplit catalogue and are approximate.',
                  style: theme.textTheme.bodySmall,
                ),
              ],

              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.lg,
                runSpacing: AppSpacing.md,
                children: <Widget>[
                  _Fact(
                    icon: Icons.payments_outlined,
                    label: 'Local currency',
                    value: d.currency ?? 'Not recorded',
                  ),
                  _Fact(
                    icon: Icons.schedule,
                    label: 'Time zone',
                    value: d.timezone ?? 'Not recorded',
                  ),
                  _Fact(
                    icon: Icons.translate,
                    label: 'Languages',
                    value: d.languages.isEmpty
                        ? 'Not recorded'
                        : d.languages.join(', '),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),
              if (d.typicalDailyBudgetMinor != null)
                InlineBanner(
                  tone: StatusTone.info,
                  icon: Icons.pie_chart_outline,
                  message:
                      'TripSplit estimates about ${Money(d.typicalDailyBudgetMinor!, d.currency ?? Currencies.defaultCode).format()} '
                      'per person per day in ${d.currency ?? 'local currency'}. This is an '
                      'estimate you can edit in your budget, not a quoted price.',
                ),

              const SizedBox(height: AppSpacing.lg),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('When to go', style: theme.textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.sm),
                    Text(d.seasonalGuidance, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'This is general seasonal guidance from the TripSplit catalogue. Weather '
                      'is not forecast here — check an actual forecast before you book.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),

              if (d.categories.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                Text('Good for', style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: <Widget>[
                    for (final String c in d.categories) Chip(label: Text(c)),
                  ],
                ),
              ],

              const SizedBox(height: AppSpacing.xl),
              FilledButton.icon(
                onPressed: () => _save(context, d),
                icon: Icon(_saved ? Icons.check : Icons.bookmark_add_outlined),
                label: Text(_saved ? 'Saved to your list' : 'Save to my list'),
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: () => _compare(context, d),
                icon: const Icon(Icons.compare_arrows),
                label: const Text('Compare estimated cost'),
              ),

              const SizedBox(height: AppSpacing.xl),
              const _DestinationSafetyCard(countryCode: '', name: ''),
              const SizedBox(height: AppSpacing.huge),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _save(BuildContext context, Destination d) async {
    try {
      await ref
          .read(destinationRepositoryProvider)
          .saveToWishlist(
            name: d.name,
            country: d.country,
            countryCode: d.countryCode,
          );
      if (mounted) setState(() => _saved = true);
      if (context.mounted) showFeedback(context, 'Saved to your list.');
    } catch (err) {
      if (context.mounted) {
        showFeedback(
          context,
          err is RepositoryException ? err.message : 'Could not save that.',
          isError: true,
        );
      }
    }
  }

  Future<void> _compare(BuildContext context, Destination d) async {
    final List<Destination> all = await ref
        .read(destinationRepositoryProvider)
        .search(limit: 8);
    final List<Destination> withBudget = all
        .where((Destination x) => x.typicalDailyBudgetMinor != null)
        .toList();
    if (withBudget.length < 2) {
      if (context.mounted) {
        showFeedback(
          context,
          'Not enough destinations with cost estimates to compare yet.',
          isError: true,
        );
      }
      return;
    }
    if (!context.mounted) return;
    await showAppSheet<void>(
      context: context,
      builder: (BuildContext context) =>
          _CompareSheet(destinations: withBudget, selected: d),
    );
  }
}

final destinationProvider = FutureProvider.autoDispose
    .family<Destination?, String>((Ref ref, String id) {
      return ref.watch(destinationRepositoryProvider).byId(id);
    });

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: AppSpacing.sm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(label, style: theme.textTheme.bodySmall),
            Text(value, style: theme.textTheme.bodyMedium),
          ],
        ),
      ],
    );
  }
}

/// Links to the official safety and entry resources for a country. It never
/// states a rule — it points at the publisher.
class _DestinationSafetyCard extends ConsumerWidget {
  const _DestinationSafetyCard({required this.countryCode, required this.name});

  final String countryCode;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (countryCode.isEmpty) return const SizedBox.shrink();
    final ThemeData theme = Theme.of(context);

    return FutureBuilder<List<TravelAdvisory>>(
      future: ref
          .watch(tripRepositoryProvider)
          .emergency
          .advisories(countryCode: countryCode),
      builder:
          (BuildContext context, AsyncSnapshot<List<TravelAdvisory>> snapshot) {
            final List<TravelAdvisory> advisories =
                snapshot.data ?? const <TravelAdvisory>[];
            return AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Official safety information',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'TripSplit links to official publishers. It does not summarise advisories or '
                    'entry rules for you — read the source yourself.',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (advisories.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.md),
                    for (final TravelAdvisory a in advisories)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          a.sourceOrg,
                          style: theme.textTheme.bodyMedium,
                        ),
                        trailing: const Icon(Icons.open_in_new, size: 16),
                        onTap: () => launchUrl(
                          Uri.parse(a.officialUrl),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: () => context.push(
                      '/trips/${ref.read(selectedTripIdProvider)}/visa',
                    ),
                    icon: const Icon(Icons.assignment_outlined, size: 18),
                    label: const Text('Check visa requirements in a trip'),
                  ),
                ],
              ),
            );
          },
    );
  }
}

class _CompareSheet extends StatelessWidget {
  const _CompareSheet({required this.destinations, required this.selected});

  final List<Destination> destinations;
  final Destination selected;

  @override
  Widget build(BuildContext context) {
    final List<Destination> sorted = <Destination>[...destinations]
      ..sort(
        (Destination a, Destination b) => (a.typicalDailyBudgetMinor ?? 0)
            .compareTo(b.typicalDailyBudgetMinor ?? 0),
      );

    final int? max = sorted.isEmpty
        ? null
        : sorted
              .map((Destination d) => d.typicalDailyBudgetMinor ?? 0)
              .reduce((int a, int b) => a > b ? a : b);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Estimated cost per person, per day',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'TripSplit estimates only. They are not quotes and your own style of travel will '
            'differ.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: <Widget>[
                for (final Destination d in sorted)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                d.name,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      fontWeight: d.id == selected.id
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                    ),
                              ),
                            ),
                            Text(
                              Money(
                                d.typicalDailyBudgetMinor ?? 0,
                                d.currency ?? Currencies.defaultCode,
                              ).format(),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          child: LinearProgressIndicator(
                            value: max == null || max == 0
                                ? 0
                                : (d.typicalDailyBudgetMinor ?? 0) / max,
                            minHeight: 6,
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/reference.dart';
import '../../data/repositories.dart';
import '../../data/supabase_service.dart';
import '../../router/providers.dart';
import '../../router/app_shell.dart';
import '../../shared/widgets/common.dart';
import 'emergency_data.dart';

/// Emergency hub. Everything here works without an account and, once
/// downloaded, works without a network connection.
class EmergencyCenterPage extends ConsumerStatefulWidget {
  const EmergencyCenterPage({super.key});

  @override
  ConsumerState<EmergencyCenterPage> createState() =>
      _EmergencyCenterPageState();
}

class _EmergencyCenterPageState extends ConsumerState<EmergencyCenterPage> {
  String _countryCode = 'HK';
  bool _downloaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _download());
  }

  /// Saves the emergency content locally. Someone who needs this guide is
  /// exactly the person who will not have signal.
  Future<void> _download() async {
    if (!SupabaseService.isInitialised) {
      // Bundled content is already on the device.
      if (mounted) setState(() => _downloaded = true);
      return;
    }
    try {
      final EmergencyRepository repo = ref
          .read(tripRepositoryProvider)
          .emergency;
      await repo.resources();
      await repo.guides();
      if (mounted) setState(() => _downloaded = true);
    } catch (_) {
      if (mounted) setState(() => _downloaded = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          const SliverToBoxAdapter(
            child: PageHeader(
              title: 'Travel Assistant',
              subtitle: 'What to do when something goes wrong abroad',
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const InlineBanner(
                    message:
                        'TripSplit is not a substitute for local authorities, your embassy, '
                        'legal advice or professional medical care. Confirm details with the '
                        'official source before you rely on them.',
                    tone: StatusTone.warning,
                    icon: Icons.gavel_outlined,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _CountryCard(
                    selected: _countryCode,
                    onChanged: (String c) => setState(() => _countryCode = c),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  if (_countryCode == 'HK')
                    _HongKongBanner(
                      onTap: () =>
                          context.push('/emergency/hong-kong/lost-passport'),
                    ),

                  SectionHeader(
                    title: 'Emergency contacts',
                    subtitle:
                        'For $_countryCode — always shown with its source',
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    action: IconButton(
                      onPressed: _download,
                      icon: Icon(
                        _downloaded
                            ? Icons.offline_pin
                            : Icons.download_outlined,
                      ),
                      tooltip: _downloaded
                          ? 'Saved for offline use'
                          : 'Save emergency guides for offline use',
                    ),
                  ),
                  _ContactsList(countryCode: _countryCode),

                  const SectionHeader(
                    title: 'What happened?',
                    subtitle: 'Pick a situation for a step-by-step plan',
                    padding: EdgeInsets.only(
                      top: AppSpacing.xxl,
                      bottom: AppSpacing.md,
                    ),
                  ),
                  for (final ({
                        IconData icon,
                        EmergencyCategory category,
                        String guideSlug,
                      })
                      s
                      in kEmergencyScenarios) ...<Widget>[
                    _ScenarioTile(
                      category: s.category,
                      icon: s.icon,
                      onTap: () => context.push('/emergency/${s.guideSlug}'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],

                  const SectionHeader(
                    title: 'Before you need this',
                    padding: EdgeInsets.only(
                      top: AppSpacing.xxl,
                      bottom: AppSpacing.md,
                    ),
                  ),
                  const _PreparednessCard(),
                  const SizedBox(height: AppSpacing.huge),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountryCard extends StatelessWidget {
  const _CountryCard({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Where are you?', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final ({String code, String name}) c in kSupportedCountries)
                ChoiceChip(
                  selected: selected == c.code,
                  onSelected: (_) => onChanged(c.code),
                  label: Text(c.name),
                  avatar: Text(
                    c.code,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'TripSplit does not know your location automatically and does not ask for it. '
            'Choose the country you are in.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _HongKongBanner extends StatelessWidget {
  const _HongKongBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.location_city, color: AppColors.danger, size: 22),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Lost passport in Hong Kong',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              const Icon(Icons.chevron_right, size: 18),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'A focused walkthrough with the Hong Kong SAR emergency contacts and Traditional '
            'Chinese phrases you can show someone.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Contacts for a country, always with the source and verification state.
///
/// Falls back to the bundled copy when there is no server, which is what makes
/// the Emergency Center usable offline and without an account.
class _ContactsList extends ConsumerWidget {
  const _ContactsList({required this.countryCode});

  final String countryCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<EmergencyResource> bundled =
        kBundledEmergencyContacts[countryCode] ?? const <EmergencyResource>[];

    if (!SupabaseService.isInitialised) {
      return _contactCards(bundled);
    }

    return FutureBuilder<List<EmergencyResource>>(
      future: ref
          .watch(tripRepositoryProvider)
          .emergency
          .resources(countryCode: countryCode)
          .catchError((Object _) => bundled),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<List<EmergencyResource>> snapshot,
          ) {
            return _contactCards(snapshot.data ?? bundled);
          },
    );
  }

  Widget _contactCards(List<EmergencyResource> resources) {
    if (resources.isEmpty) {
      return const AppCard(
        child: EmptyState(
          compact: true,
          icon: Icons.help_outline,
          title: 'No contacts recorded',
          message:
              'TripSplit has no contacts for this country. Use the official emergency '
              'directory for your location rather than guessing.',
        ),
      );
    }
    return Column(
      children: <Widget>[
        for (final EmergencyResource r in resources)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: EmergencyContactCard(resource: r),
          ),
      ],
    );
  }
}

/// A single emergency contact. The source and verification state are part of
/// the card, never hidden behind a tap.
class EmergencyContactCard extends StatelessWidget {
  const EmergencyContactCard({super.key, required this.resource});

  final EmergencyResource resource;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  resource.serviceName,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              VerificationBadge(state: resource.verification),
            ],
          ),
          if (resource.hasPhone) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: SelectableText(
                    resource.phone!,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => launchUrl(
                    Uri(
                      scheme: 'tel',
                      path: resource.phone!.replaceAll(' ', ''),
                    ),
                  ),
                  icon: const Icon(Icons.call, size: 16),
                  label: const Text('Call'),
                ),
              ],
            ),
          ],
          if (resource.hours != null)
            DetailRow(
              label: 'Hours',
              value: resource.hours!,
              icon: Icons.schedule,
            ),
          if (resource.availabilityNote != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                resource.availabilityNote!,
                style: theme.textTheme.bodySmall,
              ),
            ),
          if (resource.address != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(resource.address!, style: theme.textTheme.bodySmall),
            ),
          const SizedBox(height: AppSpacing.md),
          SourceFooter(
            sourceOrg: resource.sourceOrg,
            sourceUrl: resource.sourceUrl,
            lastVerifiedAt: resource.lastVerifiedAt,
          ),
        ],
      ),
    );
  }
}

/// Provenance block. Nothing safety-critical is displayed without it.
class SourceFooter extends StatelessWidget {
  const SourceFooter({
    super.key,
    required this.sourceOrg,
    required this.sourceUrl,
    this.lastVerifiedAt,
    this.reviewDueAt,
    this.verification,
  });

  final String sourceOrg;
  final String sourceUrl;
  final DateTime? lastVerifiedAt;
  final DateTime? reviewDueAt;
  final VerificationState? verification;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String date =
        lastVerifiedAt?.toIso8601String().substring(0, 10) ??
        'not yet verified';
    final bool overdue =
        reviewDueAt != null && reviewDueAt!.isBefore(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Source: $sourceOrg',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Text('Last checked: $date', style: theme.textTheme.bodySmall),
          if (overdue)
            Text(
              'This entry is past its review date. Confirm it before you rely on it.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.danger,
              ),
            ),
          if (sourceUrl.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse(sourceUrl),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.open_in_new, size: 15),
                    label: const Text('Open official source'),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: sourceUrl));
                    showFeedback(context, 'Source link copied');
                  },
                  icon: const Icon(Icons.copy, size: 16),
                  tooltip: 'Copy source link',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class VerificationBadge extends StatelessWidget {
  const VerificationBadge({super.key, required this.state});

  final VerificationState state;

  @override
  Widget build(BuildContext context) {
    return StatusPill(
      label: state.label,
      dense: true,
      tone: switch (state) {
        VerificationState.verified => StatusTone.positive,
        VerificationState.stale => StatusTone.danger,
        VerificationState.needsReview => StatusTone.warning,
        VerificationState.unverified => StatusTone.neutral,
      },
      icon: state.isTrusted ? Icons.verified : Icons.info_outline,
    );
  }
}

class _ScenarioTile extends StatelessWidget {
  const _ScenarioTile({
    required this.category,
    required this.icon,
    required this.onTap,
  });

  final EmergencyCategory category;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 20,
              color: theme.colorScheme.onErrorContainer,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Text(category.label, style: theme.textTheme.titleSmall),
          ),
          const Icon(Icons.chevron_right, size: 18),
        ],
      ),
    );
  }
}

class _PreparednessCard extends StatelessWidget {
  const _PreparednessCard();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Reduce how often you need this',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.md),
          for (final String tip in const <String>[
            'Save your embassy and consulate contact details offline, not just in your phone.',
            'Keep a copy of your passport photo and number somewhere secure and separate.',
            'Record your travel insurance assistance number and save it in the app.',
            'Keep one emergency contact at home who knows your itinerary.',
            'Download the guides before you travel — they work without a connection.',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(
                    Icons.check_circle_outline,
                    size: 16,
                    color: AppColors.positive,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: Text(tip, style: theme.textTheme.bodyMedium)),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: () => context.push('/documents'),
            icon: const Icon(Icons.folder_outlined, size: 18),
            label: const Text('Open my documents'),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/reference.dart';
import '../../data/supabase_service.dart';
import '../../router/providers.dart';
import '../../shared/widgets/common.dart';
import 'emergency_center_page.dart';
import 'emergency_data.dart';
import 'guide_page.dart';

/// Hong Kong–specific lost-passport flow.
///
/// This is the general procedure specialised for the Hong Kong SAR: the local
/// emergency number, the Hong Kong Police and Immigration contacts, the
/// consular directory, and Traditional Chinese phrases.
///
/// Every contact is shown with its source and verification state. TripSplit
/// does not decide anything here — the Hong Kong authorities and the traveler's
/// own embassy do.
class HongKongLostPassportPage extends ConsumerWidget {
  const HongKongLostPassportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!SupabaseService.isInitialised) {
      return _build(
        context,
        kBundledEmergencyContacts['HK'] ?? const <EmergencyResource>[],
      );
    }

    return FutureBuilder<List<EmergencyResource>>(
      future: ref
          .watch(tripRepositoryProvider)
          .emergency
          .resources(countryCode: 'HK')
          .catchError((Object _) => const <EmergencyResource>[]),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<List<EmergencyResource>> snapshot,
          ) {
            final List<EmergencyResource> server =
                snapshot.data ?? const <EmergencyResource>[];
            return _build(
              context,
              server.isNotEmpty
                  ? server
                  : (kBundledEmergencyContacts['HK'] ??
                        const <EmergencyResource>[]),
            );
          },
    );
  }

  Widget _build(BuildContext context, List<EmergencyResource> contacts) {
    final EmergencyGuide? bundled = kBundledGuides
        .where((EmergencyGuide g) => g.slug == 'lost-passport-hong-kong')
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lost passport in Hong Kong'),
        actions: <Widget>[
          IconButton(
            onPressed: () => context.push('/emergency/lost-passport-abroad'),
            icon: const Icon(Icons.public),
            tooltip: 'General guide for any country',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          const InlineBanner(
            message:
                'If you are in danger right now, call 999. In the Hong Kong SAR, 999 '
                'reaches police, fire services and ambulance.',
            tone: StatusTone.danger,
            icon: Icons.priority_high,
          ),
          const SizedBox(height: AppSpacing.lg),

          // Immediate danger check
          _ImmediateDangerCard(
            onCall: () => launchUrl(Uri.parse('tel:999')),
            onMap: () => launchUrl(
              Uri.parse(
                'https://www.openstreetmap.org/search?query=police%20station%20Hong%20Kong',
              ),
              mode: LaunchMode.externalApplication,
            ),
          ),

          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(
            title: 'Hong Kong contacts',
            subtitle: 'Shown with their source and verification state',
            padding: EdgeInsets.only(bottom: AppSpacing.md),
          ),
          for (final EmergencyResource r in contacts)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _HkContactCard(resource: r),
            ),

          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(
            title: 'Show this to someone who speaks Cantonese or Mandarin',
            padding: EdgeInsets.only(bottom: AppSpacing.md),
          ),
          PhraseCard(
            phrases: bundled?.phrasesFor('zh-Hant') ?? const <String>[],
            language: 'zh-Hant',
          ),

          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(
            title: 'Full procedure',
            subtitle: 'The same six steps as the general guide',
            padding: EdgeInsets.only(bottom: AppSpacing.md),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (
                  int i = 0;
                  i < (bundled?.steps.length ?? 0);
                  i++
                ) ...<Widget>[
                  if (i > 0) const SizedBox(width: AppSpacing.md),
                  SizedBox(
                    width: 220,
                    child: AppCard(
                      onTap: () =>
                          context.push('/emergency/lost-passport-hong-kong'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            bundled!.steps[i].heading,
                            style: Theme.of(context).textTheme.titleSmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            bundled.steps[i].body,
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: () => context.push('/emergency/lost-passport-hong-kong'),
            icon: const Icon(Icons.list_alt),
            label: const Text('Open the step-by-step guide'),
          ),

          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(
            title: 'Consular coverage in Hong Kong',
            padding: EdgeInsets.only(bottom: AppSpacing.md),
          ),
          const AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Not every country maintains a resident consulate in the Hong Kong SAR. '
                  'Some are represented by an honorary consulate, or a mission accredited '
                  'from another city.',
                  style: TextStyle(fontSize: 13, height: 1.5),
                ),
                SizedBox(height: 8),
                Text(
                  'Your own foreign ministry directory will tell you which arrangement '
                  'applies to your nationality. If your mission is not in Hong Kong, they '
                  'will tell you which office to contact instead.',
                  style: TextStyle(fontSize: 13, height: 1.5),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),
          const InlineBanner(
            message:
                'TripSplit cannot confirm your identity, issue documents, or guarantee '
                'that any airline will let you board. Those decisions rest with the Hong '
                'Kong authorities, your embassy and your airline.',
            tone: StatusTone.warning,
            icon: Icons.gavel_outlined,
          ),
          const SizedBox(height: AppSpacing.huge),
        ],
      ),
    );
  }
}

class _ImmediateDangerCard extends StatelessWidget {
  const _ImmediateDangerCard({required this.onCall, required this.onMap});

  final VoidCallback onCall;
  final VoidCallback onMap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Are you in immediate danger?',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'If you are being followed, threatened or hurt right now, call 999. '
            'If you cannot speak the local language, show someone the phrase below or '
            'ask a passer-by to help you call.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: <Widget>[
              Expanded(
                flex: 3,
                child: FilledButton.icon(
                  onPressed: onCall,
                  icon: const Icon(Icons.call),
                  label: const Text('Call 999'),
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: theme.colorScheme.onError,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: onMap,
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: const Text('Police stations'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Show this', style: theme.textTheme.labelMedium),
                const SizedBox(height: AppSpacing.sm),
                const SelectableText(
                  '請幫我叫警察。\n我需要幫助，我的護照遺失了。',
                  style: TextStyle(fontSize: 20, height: 1.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HkContactCard extends StatelessWidget {
  const _HkContactCard({required this.resource});

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
          if (resource.officialUrl != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: () => launchUrl(
                Uri.parse(resource.officialUrl!),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Open official page'),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          SourceFooter(
            sourceOrg: resource.sourceOrg,
            sourceUrl: resource.sourceUrl,
            lastVerifiedAt: resource.lastVerifiedAt,
            reviewDueAt: resource.reviewDueAt,
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Renders a step-by-step emergency guide.
///
/// Server content is preferred; the bundled offline copy is used when there is
/// no connection, so the guide is never blank. Both carry the same
/// verification state and the same source requirement.
class EmergencyGuidePage extends ConsumerWidget {
  const EmergencyGuidePage({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final EmergencyGuide? bundled = kBundledGuides
        .where((EmergencyGuide g) => g.slug == slug)
        .firstOrNull;

    // Without a server there is nothing to fetch: the bundled copy is the
    // whole answer, and the guide is already offline-capable.
    if (!SupabaseService.isInitialised) {
      return Scaffold(
        appBar: AppBar(title: Text(bundled?.title ?? 'Emergency guide')),
        body: _GuideBody(
          guide: bundled,
          contacts: _contactsFor(bundled),
          fallbackContacts: _allBundled(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(bundled?.title ?? 'Emergency guide')),
      body: FutureBuilder<EmergencyGuide?>(
        future: ref
            .watch(tripRepositoryProvider)
            .emergency
            .savedGuide(slug)
            .catchError((Object _) => null),
        builder: (BuildContext context, AsyncSnapshot<EmergencyGuide?> saved) {
          return FutureBuilder<List<EmergencyResource>>(
            future: ref
                .watch(tripRepositoryProvider)
                .emergency
                .resources()
                .catchError((Object _) => const <EmergencyResource>[]),
            builder:
                (
                  BuildContext context,
                  AsyncSnapshot<List<EmergencyResource>> contacts,
                ) {
                  return _GuideBody(
                    guide: saved.data ?? bundled,
                    contacts: contacts.data ?? _contactsFor(bundled),
                    fallbackContacts: _allBundled(),
                  );
                },
          );
        },
      ),
    );
  }

  static List<EmergencyResource> _contactsFor(EmergencyGuide? guide) {
    final String? code = guide?.countryCode;
    if (code == null) return const <EmergencyResource>[];
    return kBundledEmergencyContacts[code] ?? const <EmergencyResource>[];
  }

  static List<EmergencyResource> _allBundled() => <EmergencyResource>[
    for (final List<EmergencyResource> list in kBundledEmergencyContacts.values)
      ...list,
  ];
}

class _GuideBody extends StatefulWidget {
  const _GuideBody({
    required this.guide,
    required this.contacts,
    required this.fallbackContacts,
  });

  final EmergencyGuide? guide;
  final List<EmergencyResource> contacts;
  final List<EmergencyResource> fallbackContacts;

  @override
  State<_GuideBody> createState() => _GuideBodyState();
}

class _GuideBodyState extends State<_GuideBody> {
  int _step = 0;
  String _language = 'en';

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final EmergencyGuide? guide = widget.guide;

    if (guide == null) {
      return EmptyState(
        icon: Icons.help_outline,
        title: 'Guide unavailable',
        message:
            'This guide has not been downloaded. Connect to the internet once to save it for '
            'offline use.',
        action: OutlinedButton.icon(
          onPressed: () => context.go('/assistant'),
          icon: const Icon(Icons.arrow_back),
          label: const Text('Back to the Travel Assistant'),
        ),
      );
    }

    final List<GuideStep> steps = guide.steps;
    final List<String> languages = <String>[
      'en',
      ...guide.phrases.keys.where((String k) => k != 'en'),
    ];

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        Text(guide.title, style: theme.textTheme.headlineSmall),
        if (guide.summary != null) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text(guide.summary!, style: theme.textTheme.bodyMedium),
        ],
        const SizedBox(height: AppSpacing.lg),
        InlineBanner(
          message: guide.verification.label == 'Verified'
              ? 'Verified against the source shown below. Still confirm details with local '
                    'authorities — situations change.'
              : '${guide.verification.label}. Confirm every detail with the official source '
                    'before you rely on it.',
          tone: guide.verification.isTrusted
              ? StatusTone.positive
              : StatusTone.warning,
          icon: guide.verification.isTrusted
              ? Icons.verified
              : Icons.info_outline,
        ),

        const SizedBox(height: AppSpacing.lg),
        _StepProgress(current: _step, total: steps.length),

        const SizedBox(height: AppSpacing.lg),
        if (steps.isNotEmpty)
          _StepCard(
            step: steps[_step.clamp(0, steps.length - 1)],
            index: _step,
          ),

        const SizedBox(height: AppSpacing.lg),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton(
                onPressed: _step == 0 ? null : () => setState(() => _step--),
                child: const Text('Previous'),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: FilledButton(
                onPressed: _step >= steps.length - 1
                    ? null
                    : () => setState(() => _step++),
                child: Text(_step >= steps.length - 1 ? 'Done' : 'Next step'),
              ),
            ),
          ],
        ),

        if (_step >= steps.length - 1) ...<Widget>[
          const SizedBox(height: AppSpacing.xxl),
          const SectionHeader(
            title: 'Show this to someone who speaks the local language',
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            children: <Widget>[
              for (final String lang in languages)
                ChoiceChip(
                  selected: _language == lang,
                  onSelected: (_) => setState(() => _language = lang),
                  label: Text(_languageLabel(lang)),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          PhraseCard(phrases: guide.phrasesFor(_language), language: _language),

          const SizedBox(height: AppSpacing.xxl),
          SectionHeader(
            title: guide.countryCode == null
                ? 'Emergency contacts'
                : 'Emergency contacts (${guide.countryCode})',
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
          ),
          _GuideContacts(
            countryCode: guide.countryCode,
            contacts: widget.contacts,
            fallback: widget.fallbackContacts,
          ),
        ],

        const SizedBox(height: AppSpacing.xl),
        if (guide.sourceOrg != null || guide.sourceUrl != null)
          SourceFooter(
            sourceOrg: guide.sourceOrg ?? 'Official guidance',
            sourceUrl: guide.sourceUrl ?? '',
            lastVerifiedAt: guide.lastVerifiedAt,
            reviewDueAt: guide.reviewDueAt,
          ),

        const SizedBox(height: AppSpacing.lg),
        const InlineBanner(
          message:
              'If you are in danger right now, contact local emergency services before '
              'reading further. TripSplit cannot contact anyone on your behalf.',
          tone: StatusTone.danger,
          icon: Icons.priority_high,
        ),
        const SizedBox(height: AppSpacing.huge),
      ],
    );
  }

  String _languageLabel(String code) => switch (code) {
    'zh-Hant' => '繁體中文',
    'zh-Hans' => '简体中文',
    'en' => 'English',
    'es' => 'Español',
    'fr' => 'Français',
    'de' => 'Deutsch',
    'ja' => '日本語',
    'pt' => 'Português',
    'ko' => '한국어',
    'ar' => 'العربية',
    'hi' => 'हिन्दी',
    _ => code,
  };
}

class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Step ${current + 1} of $total',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : (current + 1) / total,
            minHeight: 6,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.step, required this.index});

  final GuideStep step;
  final int index;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(step.heading, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          Text(step.body, style: theme.textTheme.bodyLarge),
          if (step.callouts.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            for (final String callout in step.callouts)
              Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.infoSoft,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: AppColors.info.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: AppColors.info,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        callout,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.info,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (step.actions.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            for (final GuideAction action in step.actions)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: SizedBox(
                  width: double.infinity,
                  child: _ActionButton(action: action),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action});

  final GuideAction action;

  @override
  Widget build(BuildContext context) {
    final IconData icon = switch (action.kind) {
      'call' => Icons.call,
      'map' => Icons.map_outlined,
      'sms' => Icons.sms_outlined,
      _ => Icons.open_in_new,
    };

    if (action.kind == 'call') {
      return FilledButton.icon(
        onPressed: () => launchUrl(
          Uri(scheme: 'tel', path: action.url.replaceFirst('tel:', '')),
        ),
        icon: Icon(icon),
        label: Text(action.label),
      );
    }

    final Uri uri = Uri.tryParse(action.url) ?? Uri.parse('about:blank');
    return OutlinedButton.icon(
      onPressed: () => launchUrl(uri, mode: LaunchMode.externalApplication),
      icon: Icon(icon),
      label: Text(action.label),
    );
  }
}

/// Phrases a traveller can show to someone who speaks the local language.
class PhraseCard extends StatelessWidget {
  const PhraseCard({super.key, required this.phrases, required this.language});

  final List<String> phrases;
  final String language;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (phrases.isEmpty) {
      return const AppCard(
        child: Text(
          'No phrases are available in this language. A translation app or a written note may '
          'help, but use official sources for anything critical.',
          style: TextStyle(fontSize: 13),
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Show this on your phone', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.md),
          for (int i = 0; i < phrases.length; i++) ...<Widget>[
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: SelectableText(
                      phrases[i],
                      style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: phrases[i]));
                      showFeedback(context, 'Phrase copied');
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    tooltip: 'Copy phrase',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            'These translations are provided as a starting point. For anything legally or '
            'medically important, use an official translation or an interpreter.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _GuideContacts extends StatelessWidget {
  const _GuideContacts({
    required this.countryCode,
    required this.contacts,
    required this.fallback,
  });

  final String? countryCode;
  final List<EmergencyResource> contacts;
  final List<EmergencyResource> fallback;

  @override
  Widget build(BuildContext context) {
    List<EmergencyResource> items = contacts;
    if (items.isEmpty && countryCode != null) {
      items = fallback
          .where((EmergencyResource r) => r.countryCode == countryCode)
          .toList();
    }
    if (items.isEmpty) {
      items = fallback.take(6).toList();
    }
    if (items.isEmpty) {
      return const AppCard(
        child: Text(
          'No contacts have been downloaded. Open the Travel Assistant while connected to '
          'download them.',
          style: TextStyle(fontSize: 13),
        ),
      );
    }
    return Column(
      children: <Widget>[
        for (final EmergencyResource r in items)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: EmergencyContactCard(resource: r),
          ),
      ],
    );
  }
}

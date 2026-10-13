import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/trip.dart';
import '../../router/providers.dart';
import '../../shared/widgets/avatars.dart';
import '../../shared/widgets/common.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Profile?> async = ref.watch(profileProvider);
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object err, StackTrace _) => ErrorStateView(message: '$err'),
        data: (Profile? profile) {
          if (profile == null) {
            return const EmptyState(
              icon: Icons.person_outline,
              title: 'No profile',
              message: 'Your profile could not be loaded.',
            );
          }

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: <Widget>[
              Center(
                child: Column(
                  children: <Widget>[
                    MemberAvatar(initials: profile.initials, size: 84),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      profile.displayName,
                      style: theme.textTheme.headlineSmall,
                    ),
                    if (profile.preferredCurrency.isNotEmpty)
                      Text(
                        'Prefers ${profile.preferredCurrency}',
                        style: theme.textTheme.bodyMedium,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),

              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('About you', style: theme.textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.md),
                    DetailRow(
                      label: 'Home country',
                      value: profile.homeCountry ?? 'Not set',
                      icon: Icons.home_outlined,
                    ),
                    DetailRow(
                      label: 'Residence',
                      value: profile.residenceCountry ?? 'Not set',
                      icon: Icons.location_city_outlined,
                    ),
                    DetailRow(
                      label: 'Passport country',
                      value: profile.passportCountry ?? 'Not set',
                      icon: Icons.no_accounts_outlined,
                    ),
                    DetailRow(
                      label: 'Time zone',
                      value: profile.timezone,
                      icon: Icons.schedule,
                    ),
                    DetailRow(
                      label: 'Travel style',
                      value: profile.travelStyle?.label ?? 'Not set',
                      icon: Icons.tune,
                    ),
                    if (profile.travelInterests.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.md),
                        child: Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: <Widget>[
                            for (final String i in profile.travelInterests)
                              Chip(label: Text(i)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),
              if (profile.passportExpiryDate != null)
                AppCard(
                  child: Row(
                    children: <Widget>[
                      Icon(
                        profile.passportNeedsAttention
                            ? Icons.warning_amber_rounded
                            : Icons.verified_user_outlined,
                        color: profile.passportNeedsAttention
                            ? AppColors.warning
                            : AppColors.positive,
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Passport expiry',
                              style: theme.textTheme.titleSmall,
                            ),
                            Text(
                              '${profile.passportExpiryDate!.toIso8601String().substring(0, 10)}'
                              '${profile.passportMonthsRemaining != null ? ' · ${profile.passportMonthsRemaining} months left' : ''}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              if (profile.emergencyContactName != null ||
                  profile.emergencyContactPhone != null) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Emergency contact',
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        profile.emergencyContactName ?? '',
                        style: theme.textTheme.bodyMedium,
                      ),
                      if (profile.emergencyContactPhone != null)
                        Text(
                          profile.emergencyContactPhone!,
                          style: theme.textTheme.bodyMedium,
                        ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Keep this written down somewhere physical as well — a locked '
                        'phone is no help if it is the thing you lost.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.xl),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Settings'),
                subtitle: const Text(
                  'Currency, language, notifications, privacy',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings'),
              ),
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: const Text('Travel documents'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/documents'),
              ),
              ListTile(
                leading: const Icon(Icons.currency_exchange),
                title: const Text('Currency converter'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/converter'),
              ),
              const SizedBox(height: AppSpacing.huge),
            ],
          );
        },
      ),
    );
  }
}

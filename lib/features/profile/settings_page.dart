import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/money/currency.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/misc.dart';
import '../../data/models/trip.dart';
import '../../data/supabase_service.dart';
import '../../router/providers.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/form_fields.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _emergencyName = TextEditingController();
  final TextEditingController _emergencyPhone = TextEditingController();
  DateTime? _passportExpiry;
  bool _loading = true;
  String _currency = Currencies.defaultCode;
  final bool _demoMode = AppConfig.demoMode;

  static const Map<String, ({String title, String body})> _notificationPrefs =
      <String, ({String title, String body})>{
        'departure_reminder': (
          title: 'Departure reminders',
          body: 'Nudge me before a trip starts',
        ),
        'budget_alert': (
          title: 'Budget alerts',
          body: 'Tell me when spending passes my threshold',
        ),
        'settlement': (
          title: 'Settlement reminders',
          body: 'Remind me when I owe someone money',
        ),
        'passport_reminder': (
          title: 'Passport expiry reminders',
          body: 'Warn me before my passport runs short',
        ),
        'visa_reminder': (
          title: 'Visa preparation reminders',
          body: 'Remind me to check entry requirements',
        ),
        'booking_reminder': (
          title: 'Booking reminders',
          body: 'Flag cancellation deadlines',
        ),
      };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _name.dispose();
    _emergencyName.dispose();
    _emergencyPhone.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final Profile? profile = await ref.read(profileProvider.future);
    if (profile == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() {
      _name.text = profile.fullName ?? '';
      _emergencyName.text = profile.emergencyContactName ?? '';
      _emergencyPhone.text = profile.emergencyContactPhone ?? '';
      _passportExpiry = profile.passportExpiryDate;
      _currency = profile.preferredCurrency;
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (AppConfig.demoMode) {
      showFeedback(
        context,
        'Settings are not saved in demo mode.',
        isError: true,
      );
      return;
    }
    try {
      await SupabaseService.instance.client
          .from('profiles')
          .update(<String, dynamic>{
            'full_name': _name.text.trim(),
            'preferred_currency': _currency,
            'emergency_contact_name': _emergencyName.text.trim(),
            'emergency_contact_phone': _emergencyPhone.text.trim(),
            'passport_expiry_date': _passportExpiry
                ?.toIso8601String()
                .substring(0, 10),
          })
          .eq('id', SupabaseService.instance.currentUserId ?? '');

      ref.invalidate(profileProvider);
      if (mounted) showFeedback(context, 'Settings saved.');
    } catch (err) {
      if (mounted) showFeedback(context, 'Could not save: $err', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Profile?> async = ref.watch(profileProvider);
    final Profile? profile = async.value;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: <Widget>[
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                DropdownButtonFormField<String>(
                  initialValue: _currency,
                  decoration: const InputDecoration(
                    labelText: 'Preferred currency',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                  items: <DropdownMenuItem<String>>[
                    for (final Currency c in Currencies.all)
                      DropdownMenuItem<String>(
                        value: c.code,
                        child: Text('${c.code} — ${c.name}'),
                      ),
                  ],
                  onChanged: (String? v) =>
                      setState(() => _currency = v ?? _currency),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'This only affects how amounts are displayed. Every trip keeps its own '
                  'currency, and stored expenses are never revalued.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),

                const SizedBox(height: AppSpacing.xxl),
                _Header(text: 'Notifications'),
                for (final MapEntry<String, ({String body, String title})> e
                    in _notificationPrefs.entries)
                  SwitchListTile(
                    value: profile?.isNotificationEnabled(e.key) ?? true,
                    onChanged: (bool v) => _toggle(e.key, v),
                    contentPadding: EdgeInsets.zero,
                    title: Text(e.value.title),
                    subtitle: Text(
                      e.value.body,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),

                const SizedBox(height: AppSpacing.xl),
                _Header(text: 'Passport reminder'),
                Text(
                  'TripSplit never asks for or stores your passport number. This date is '
                  'only used to warn you before common six-month validity rules bite.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: DateField(
                        label: _passportExpiry == null
                            ? 'Passport expiry'
                            : 'Expires ${_passportExpiry!.toIso8601String().substring(0, 10)}',
                        value:
                            _passportExpiry ??
                            DateTime.now().add(const Duration(days: 365 * 5)),
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 365 * 15),
                        ),
                        lastDate: DateTime.now().add(
                          const Duration(days: 365 * 15),
                        ),
                        onChanged: (DateTime d) =>
                            setState(() => _passportExpiry = d),
                      ),
                    ),
                    if (_passportExpiry != null)
                      IconButton(
                        onPressed: () => setState(() => _passportExpiry = null),
                        icon: const Icon(Icons.clear),
                        tooltip: 'Clear',
                      ),
                  ],
                ),

                const SizedBox(height: AppSpacing.xl),
                _Header(text: 'Emergency contact'),
                TextField(
                  controller: _emergencyName,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _emergencyPhone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),
                _Header(text: 'Offline'),
                const OfflineCard(),

                const SizedBox(height: AppSpacing.xl),
                _Header(text: 'Account'),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.logout),
                  title: const Text('Sign out'),
                  subtitle: Text(
                    _demoMode
                        ? 'Demo mode has no real session'
                        : 'Ends this session on this device',
                  ),
                  onTap: () => _signOut(context, ref),
                ),

                const SizedBox(height: AppSpacing.xl),
                _Header(text: 'Privacy'),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.file_download_outlined),
                  title: const Text('Export my data'),
                  subtitle: const Text(
                    'Everything TripSplit holds about you, as JSON',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _export(context, ref),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                    'Delete my account',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  subtitle: const Text(
                    'Removes your profile and the trips you own',
                  ),
                  onTap: () => _deleteAccount(context, ref),
                ),

                const SizedBox(height: AppSpacing.xl),
                FilledButton(
                  onPressed: _save,
                  child: const Text('Save settings'),
                ),
                if (_demoMode) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  const InlineBanner(
                    message:
                        'Demo mode is active. Nothing you change here is saved, and no '
                        'network requests are made.',
                    tone: StatusTone.warning,
                  ),
                ],
                const SizedBox(height: AppSpacing.huge),
              ],
            ),
    );
  }

  Future<void> _toggle(String key, bool value) async {
    if (AppConfig.demoMode) {
      showFeedback(
        context,
        'Notification preferences are not saved in demo mode.',
        isError: true,
      );
      return;
    }
    final Profile? profile = await ref.read(profileProvider.future);
    if (profile == null) return;
    final Map<String, dynamic> prefs = <String, dynamic>{
      ...profile.notificationPreferences,
      key: value,
    };
    await SupabaseService.instance.client
        .from('profiles')
        .update(<String, dynamic>{'notification_preferences': prefs})
        .eq('id', SupabaseService.instance.currentUserId ?? '');
    ref.invalidate(profileProvider);
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    try {
      final dynamic result = await SupabaseService.instance.client.rpc(
        'export_my_data',
      );
      final String text = const JsonEncoder.withIndent('  ').convert(result);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('Your data'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: SingleChildScrollView(child: SelectableText(text)),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (err) {
      if (context.mounted) {
        showFeedback(
          context,
          'Could not export your data: $err',
          isError: true,
        );
      }
    }
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    if (AppConfig.demoMode) {
      showFeedback(
        context,
        'Demo mode has no real session to sign out of.',
        isError: true,
      );
      return;
    }
    if (!SupabaseService.isInitialised) {
      showFeedback(
        context,
        'Supabase is not configured, so there is no session to end.',
        isError: true,
      );
      return;
    }

    final bool ok = await confirmDestructive(
      context,
      title: 'Sign out?',
      message:
          'You will need your email and password to sign back in. Trips and expenses '
          'stay on your account.',
      confirmLabel: 'Sign out',
    );
    if (!ok || !context.mounted) return;

    await ref.read(authControllerProvider.notifier).signOut();
    if (!context.mounted) return;
    // The router listens for the signed-out state and returns to /welcome, but
    // redirect explicitly so a sign-out from a deep link cannot leave the user
    // on a screen that needs a session.
    if (context.mounted) context.go('/welcome');
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final bool ok = await confirmDestructive(
      context,
      title: 'Delete your account?',
      message:
          'This removes your profile and every trip you own, along with their expenses, '
          'itineraries and documents. Trips you are a member of but do not own stay, and '
          'you lose access to them. This cannot be undone.',
      confirmLabel: 'Delete my account',
    );
    if (!ok || !context.mounted) return;
    if (AppConfig.demoMode) {
      showFeedback(
        context,
        'Account deletion is disabled in demo mode.',
        isError: true,
      );
      return;
    }
    showFeedback(
      context,
      'Account deletion is handled by Supabase Auth. Contact support if you need it '
      'completed on your behalf.',
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );
}

/// Explains and controls the offline cache.
class OfflineCard extends ConsumerStatefulWidget {
  const OfflineCard({super.key});

  @override
  ConsumerState<OfflineCard> createState() => _OfflineCardState();
}

class _OfflineCardState extends ConsumerState<OfflineCard> {
  bool _downloading = false;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<AppNotification>> _ = const AsyncValue.data(
      <AppNotification>[],
    );
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Emergency guides and destination information are saved on this device so they '
            'work without a connection.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: _downloading ? null : _download,
            icon: _downloading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_outlined, size: 18),
            label: const Text('Save for offline use'),
          ),
        ],
      ),
    );
  }

  Future<void> _download() async {
    setState(() => _downloading = true);
    try {
      final repo = ref.read(tripRepositoryProvider).emergency;
      await repo.resources();
      await repo.guides();
      if (!mounted) return;
      showFeedback(context, 'Saved for offline use.');
    } catch (err) {
      if (mounted) {
        showFeedback(context, 'Could not save: $err', isError: true);
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }
}

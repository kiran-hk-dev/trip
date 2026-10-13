import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/supabase_service.dart';
import '../../shared/widgets/common.dart';

/// Accepts a trip invitation from a shared link.
///
/// The token is exchanged server-side; the database checks that the signed-in
/// account matches the invited address and that the invitation has not expired.
class AcceptInvitePage extends ConsumerStatefulWidget {
  const AcceptInvitePage({super.key, required this.token});

  final String token;

  @override
  ConsumerState<AcceptInvitePage> createState() => _AcceptInvitePageState();
}

class _AcceptInvitePageState extends ConsumerState<AcceptInvitePage> {
  bool _busy = false;
  String? _error;
  String? _acceptedTripId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _accept());
  }

  Future<void> _accept() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final String tripId = await SupabaseService.instance.client.rpc(
        'accept_invitation',
        params: <String, dynamic>{'p_token': widget.token},
      ) as String;
      if (!mounted) return;
      setState(() => _acceptedTripId = tripId);
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = _friendly(err);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendly(Object err) {
    final String text = '$err';
    if (text.contains('expired')) {
      return 'This invitation has expired. Ask the trip owner to send a new one.';
    }
    if (text.contains('different email')) {
      return 'This invitation was sent to a different email address. Sign in with the '
          'address it was sent to.';
    }
    if (text.contains('invalid') || text.contains('already used')) {
      return 'This invitation link is not valid, or it has already been used.';
    }
    return 'Could not accept this invitation. Ask the trip owner to send a new link.';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Trip invitation')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (_acceptedTripId != null) ...<Widget>[
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'You have joined the trip',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const InlineBanner(
                    message:
                        'You will be able to see the itinerary, budget and expenses shared '
                        'with you, according to the role the owner assigned.',
                    tone: StatusTone.positive,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton(
                    onPressed: () => context.go('/trips/$_acceptedTripId'),
                    child: const Text('Open the trip'),
                  ),
                ] else if (_error != null) ...<Widget>[
                  Icon(
                    Icons.link_off,
                    size: 64,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Invitation not accepted',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton(
                    onPressed: () => context.go('/trips'),
                    child: const Text('Go to my trips'),
                  ),
                  TextButton(
                    onPressed: () => context.go('/home'),
                    child: const Text('Back to home'),
                  ),
                ] else ...<Widget>[
                  const CircularProgressIndicator(),
                  const SizedBox(height: AppSpacing.xl),
                  Text('Joining the trip…', style: theme.textTheme.bodyLarge),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'If you are not signed in with the invited email address, this will '
                    'not work.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

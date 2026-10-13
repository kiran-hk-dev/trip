import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/money/currency.dart';
import '../../core/theme/app_theme.dart';
import '../../data/supabase_service.dart';
import '../../router/providers.dart';
import '../../shared/widgets/common.dart';

/// Branded sign-in / sign-up container.
class AuthShell extends StatelessWidget {
  const AuthShell({super.key});

  @override
  Widget build(BuildContext context) {
    final String location = GoRouterState.of(context).matchedLocation;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxl,
              vertical: AppSpacing.xxl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const _Brand(),
                  const SizedBox(height: AppSpacing.huge),
                  if (AppConfig.demoMode) ...<Widget>[
                    const InlineBanner(
                      message: 'Demo mode is on. Nothing you type here is sent anywhere, and no account is created.',
                      icon: Icons.science_outlined,
                      tone: StatusTone.warning,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                  AnimatedSize(
                    duration: AppDurations.normal,
                    alignment: Alignment.topCenter,
                    child: switch (location) {
                      final String l when l.endsWith('sign-up') =>
                        const SignUpForm(),
                      final String l when l.endsWith('forgot-password') =>
                        const ForgotPasswordForm(),
                      _ => const SignInForm(),
                    },
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  if (AppConfig.demoMode)
                    FilledButton.icon(
                      onPressed: () => context.go('/home'),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Explore the demo'),
                    )
                  else
                    Text(
                      'TripSplit World never stores your passport number. Trip planning works without one.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      children: <Widget>[
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: const Icon(Icons.explore, color: Colors.white, size: 28),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('TripSplit World', style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Plan it, budget it, split it, and get home safely.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// Sign in
// ---------------------------------------------------------------------
class SignInPage extends StatelessWidget {
  const SignInPage({super.key});

  // These pages are pushed as child routes of /welcome, so go_router replaces
  // the AuthShell widget rather than nesting inside it. Without the Material
  // that Scaffold provides, every TextField in these forms throws
  // "No Material widget found". Keep this in step with AuthShell.
  @override
  Widget build(BuildContext context) => const _FormPage(child: SignInForm());
}

/// Wraps a bare form in the Material and scrolling that Scaffold provides.
class _FormPage extends StatelessWidget {
  const _FormPage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxl,
              vertical: AppSpacing.xl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class SignInForm extends ConsumerStatefulWidget {
  const SignInForm({super.key});

  @override
  ConsumerState<SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends ConsumerState<SignInForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final String? error = await ref
        .read(authControllerProvider.notifier)
        .signIn(email: _email.text.trim(), password: _password.text);

    if (!mounted) return;
    setState(() => _busy = false);

    if (error == null) {
      context.go('/home');
      return;
    }
    setState(() {
      _error = switch (error) {
        'invalid-credentials' =>
          'That email and password combination did not match.',
        'confirm-email' =>
          'Check your inbox and confirm your email address first.',
        _ => 'Could not sign in. Check your connection and try again.',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Welcome back', style: theme.textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Sign in to pick up where you left off.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xl),
          if (_error != null) ...<Widget>[
            InlineBanner(
              message: _error!,
              tone: StatusTone.danger,
              icon: Icons.error_outline,
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const <String>[AutofillHints.email],
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.mail_outline),
            ),
            validator: (String? v) {
              final String value = v?.trim() ?? '';
              if (value.isEmpty) return 'Enter your email address.';
              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
                return 'That does not look like an email address.';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            controller: _password,
            obscureText: _obscure,
            autofillHints: const <String>[AutofillHints.password],
            onFieldSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                tooltip: _obscure ? 'Show password' : 'Hide password',
              ),
            ),
            validator: (String? v) =>
                (v == null || v.isEmpty) ? 'Enter your password.' : null,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => context.push('/welcome/forgot-password'),
              child: const Text('Forgot password?'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Sign in'),
          ),
          const SizedBox(height: AppSpacing.xl),
          // Wrap, not Row: a Row of a label and a TextButton is wider than a
          // 390px phone minus padding, and overflows. Wrap drops the button to
          // its own line on a narrow screen instead of clipping it.
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.xs,
            children: <Widget>[
              Text('New here?', style: theme.textTheme.bodyMedium),
              TextButton(
                onPressed: () => context.go('/welcome/sign-up'),
                child: const Text('Create an account'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Sign up
// ---------------------------------------------------------------------
class SignUpPage extends StatelessWidget {
  const SignUpPage({super.key});

  @override
  Widget build(BuildContext context) => const _FormPage(child: SignUpForm());
}

class SignUpForm extends ConsumerStatefulWidget {
  const SignUpForm({super.key});

  @override
  ConsumerState<SignUpForm> createState() => _SignUpFormState();
}

class _SignUpFormState extends ConsumerState<SignUpForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  final TextEditingController _recoveryCode = TextEditingController();
  String _currency = Currencies.defaultCode;
  bool _obscure = true;
  bool _accepted = false;
  bool _busy = false;
  String? _error;

  static const List<String> _currencies = <String>[
    Currencies.defaultCode,
    'USD',
    'EUR',
    'GBP',
    'JPY',
    'HKD',
    'SGD',
    'AUD',
    'CAD',
    'AED',
    'THB',
  ];

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _recoveryCode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (!_accepted) {
      setState(() => _error = 'Please accept the terms to continue.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });

    final String? error = await ref
        .read(authControllerProvider.notifier)
        .signUp(
          email: _email.text.trim(),
          password: _password.text,
          fullName: _name.text.trim(),
          preferredCurrency: _currency,
        );

    if (!mounted) return;
    setState(() => _busy = false);

    if (error == null) {
      context.go('/onboarding');
      return;
    }
    if (error == 'email-confirmation-required') {
      // The Supabase project still has "Confirm email" switched on, so it
      // refuses to issue a session. Say so plainly, and say how to fix it,
      // rather than sending the user to an inbox.
      setState(() {
        _error =
            'Your Supabase project still requires email confirmation, so we '
            'cannot sign you in yet. Turn off Auth > Providers > Email > '
            '"Confirm email", then try again.';
      });
      return;
    }
    setState(() => _error = error);
  }

  String? _passwordStrengthError(String? value) {
    final String v = value ?? '';
    if (v.isEmpty) return 'Choose a password.';
    if (v.length < 8) return 'Use at least 8 characters.';
    if (!RegExp('[A-Za-z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)) {
      return 'Mix letters and numbers.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Create your account', style: theme.textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'You only need an email and a password to start.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xl),
          if (_error != null) ...<Widget>[
            InlineBanner(message: _error!, tone: StatusTone.danger),
            const SizedBox(height: AppSpacing.lg),
          ],
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            autofillHints: const <String>[AutofillHints.name],
            decoration: const InputDecoration(
              labelText: 'Full name',
              prefixIcon: Icon(Icons.person_outline),
              helperText: 'Shown to anyone you invite to a trip.',
            ),
            validator: (String? v) =>
                (v == null || v.trim().length < 2) ? 'Enter your name.' : null,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const <String>[AutofillHints.newUsername],
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.mail_outline),
            ),
            validator: (String? v) {
              final String value = v?.trim() ?? '';
              if (value.isEmpty) return 'Enter your email address.';
              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
                return 'That does not look like an email address.';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          DropdownButtonFormField<String>(
            initialValue: _currency,
            decoration: const InputDecoration(
              labelText: 'Preferred currency',
              prefixIcon: Icon(Icons.payments_outlined),
              helperText:
                  'Only affects display. Every trip keeps its own currency.',
            ),
            items: <DropdownMenuItem<String>>[
              for (final String code in _currencies)
                DropdownMenuItem<String>(value: code, child: Text(code)),
            ],
            onChanged: (String? v) =>
                setState(() => _currency = v ?? _currency),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            controller: _password,
            obscureText: _obscure,
            autofillHints: const <String>[AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              helperText: 'At least 8 characters, with a number.',
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                tooltip: _obscure ? 'Show password' : 'Hide password',
              ),
            ),
            validator: _passwordStrengthError,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            controller: _confirm,
            obscureText: _obscure,
            decoration: const InputDecoration(
              labelText: 'Confirm password',
              prefixIcon: Icon(Icons.lock_reset_outlined),
            ),
            validator: (String? v) =>
                v != _password.text ? 'The passwords do not match.' : null,
          ),
          const SizedBox(height: AppSpacing.xl),
          CheckboxListTile(
            value: _accepted,
            onChanged: (bool? v) => setState(() => _accepted = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'I understand that TripSplit is not a substitute for official authorities, consular services or professional medical care.',
              style: TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Create account'),
          ),
          const SizedBox(height: AppSpacing.xl),
          // Wrap, not Row: see the note on the sign-in form. This one overflows
          // by 122px on a 390px phone.
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.xs,
            children: <Widget>[
              Text(
                'Already have an account?',
                style: theme.textTheme.bodyMedium,
              ),
              TextButton(
                onPressed: () => context.go('/welcome/sign-in'),
                child: const Text('Sign in'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Forgot password
// ---------------------------------------------------------------------
class ForgotPasswordPage extends StatelessWidget {
  const ForgotPasswordPage({super.key});

  @override
  Widget build(BuildContext context) =>
      const _FormPage(child: ForgotPasswordForm());
}

class ForgotPasswordForm extends ConsumerStatefulWidget {
  const ForgotPasswordForm({super.key});

  @override
  ConsumerState<ForgotPasswordForm> createState() => _ForgotPasswordFormState();
}

class _ForgotPasswordFormState extends ConsumerState<ForgotPasswordForm> {
  final TextEditingController _email = TextEditingController();
  bool _busy = false;
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    await ref
        .read(authControllerProvider.notifier)
        .sendPasswordReset(_email.text.trim());
    if (!mounted) return;
    setState(() {
      _busy = false;
      _sent = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (_sent) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Check your inbox', style: theme.textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.md),
          Text(
            'If an account exists for ${_email.text.trim()}, a password reset link is on its way. '
            'The link expires after a short time.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: () => context.pop(),
            child: const Text('Back to sign in'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('Reset your password', style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'We will email you a link to choose a new password.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xl),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.mail_outline),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send reset link'),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextButton(
          onPressed: () => context.pop(),
          child: const Text('Back to sign in'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// Onboarding
// ---------------------------------------------------------------------
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final PageController _pager = PageController();
  int _page = 0;
  bool _saving = false;

  static const List<({String title, String body, IconData icon})> _slides =
      <({String title, String body, IconData icon})>[
        (
          title: 'Travel budget that adds up',
          body: 'Plan a budget, log what you actually spend, and see the difference in real time. Every calculation uses exact currency units, so a rounding difference never creeps in.',
          icon: Icons.account_balance_wallet_outlined,
        ),
        (
          title: 'Split bills without the awkward maths',
          body: 'Equal, custom, percentage or weighted splits — including expenses paid in a different currency. Balances recalculate whenever an expense changes.',
          icon: Icons.pie_chart_outline,
        ),
        (
          title: 'Know what to do if something goes wrong',
          body: 'Downloadable emergency guides, verified local contacts and a step-by-step lost-passport plan that works offline. Sources and verification dates are always shown.',
          icon: Icons.health_and_safety_outlined,
        ),
      ];

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  Future<void> _finish({bool minimal = false}) async {
    if (!minimal && SupabaseService.isInitialised) {
      setState(() => _saving = true);
      try {
        await SupabaseService.instance.client
            .from('profiles')
            .update(<String, dynamic>{'onboarding_completed': true})
            .eq('id', SupabaseService.instance.currentUserId ?? '');
      } catch (_) {
        // Onboarding can always be finished later from Settings.
      }
      if (!mounted) return;
      setState(() => _saving = false);
    }
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome'),
        actions: <Widget>[
          TextButton(
            onPressed: () => _finish(minimal: true),
            child: const Text('Skip'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: PageView.builder(
                controller: _pager,
                onPageChanged: (int i) => setState(() => _page = i),
                itemCount: _slides.length,
                itemBuilder: (BuildContext context, int i) {
                  final ({IconData icon, String body, String title}) slide =
                      _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xxl,
                      vertical: AppSpacing.xl,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.12,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            slide.icon,
                            size: 38,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          slide.body,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                for (int i = 0; i < _slides.length; i++)
                  AnimatedContainer(
                    duration: AppDurations.fast,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _page ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving
                      ? null
                      : () {
                          if (_page < _slides.length - 1) {
                            _pager.nextPage(
                              duration: AppDurations.normal,
                              curve: Curves.easeOut,
                            );
                          } else {
                            _finish();
                          }
                        },
                  child: Text(
                    _page < _slides.length - 1 ? 'Next' : 'Start planning',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

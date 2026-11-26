import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../../core/analytics/analytics.dart';
import '../../core/env/env.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import 'session.dart';

/// Plain wording for a failed sign-in step (never the raw exception).
String signInErrorText(Object e) {
  if (e is String) return e;
  if (e is AuthException) {
    final m = e.message.toLowerCase();
    if (m.contains('rate') || m.contains('seconds') || e.statusCode == '429') {
      return 'Too many tries. Wait a minute and ask for a new code.';
    }
    if (m.contains('expired') || m.contains('invalid')) {
      return 'That code did not work or has expired. Ask for a new one.';
    }
    return e.message;
  }
  return 'Could not reach the sign-in service. Check your connection and try again.';
}

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});
  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  void _done() {
    final a = ref.read(analyticsProvider);
    a.track(AnalyticsEvent.signupCompleted);
    a.track(AnalyticsEvent.onboardingStepCompleted('sign_in'));
    ref.read(sessionProvider).signIn();
  }

  Future<void> _submit() async {
    final s = ref.read(sessionProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!_codeSent) {
        if (!_email.text.contains('@')) throw 'Enter a valid email';
        await s.requestEmailOtp(_email.text.trim());
        setState(() => _codeSent = true);
      } else {
        final ok = await s.verifyEmailOtp(
          _email.text.trim(),
          _code.text.trim(),
        );
        if (!ok) throw 'That code did not work';
        _done();
      }
    } catch (e) {
      setState(() => _error = signInErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Space.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 56),
                  Text(
                    'Welcome to\n${Env.appName}',
                    style: context.tt.displayLarge,
                  ),
                  const SizedBox(height: Space.md),
                  Text(
                    'Sign in to see your money on autopilot.',
                    style: context.tt.bodyLarge!.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 48),
                  TextField(
                    controller: _email,
                    enabled: !_codeSent,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                    decoration: const InputDecoration(
                      hintText: 'Email address',
                      prefixIcon: Icon(Icons.mail_outline_rounded),
                    ),
                  ),
                  if (_codeSent) ...[
                    const SizedBox(height: Space.md),
                    TextField(
                      controller: _code,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: InputDecoration(
                        hintText: '6-digit code',
                        counterText: '',
                        prefixIcon: const Icon(Icons.password_rounded),
                        helperText: Env.hasSupabase
                            ? 'Check your inbox (and spam). It can take a minute.'
                            : 'Mock mode: any 6 digits work',
                      ),
                    ),
                  ],
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_error!, style: TextStyle(color: c.negative)),
                    ),
                  const SizedBox(height: Space.lg),
                  PrimaryButton(
                    label: _codeSent
                        ? 'Verify and continue'
                        : 'Email me a code',
                    loading: _busy,
                    onPressed: _submit,
                  ),
                  if (!Env.hasSupabase) ...[
                    const SizedBox(height: Space.xl),
                    Row(
                      children: [
                        Expanded(child: Divider(color: c.border)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('or', style: context.tt.bodySmall),
                        ),
                        Expanded(child: Divider(color: c.border)),
                      ],
                    ),
                    const SizedBox(height: Space.xl),
                    PrimaryButton(
                      label: 'Continue with Apple',
                      icon: Icons.apple,
                      secondary: true,
                      onPressed: _done,
                    ),
                    const SizedBox(height: Space.md),
                    PrimaryButton(
                      label: 'Continue with Google',
                      icon: Icons.g_mobiledata_rounded,
                      secondary: true,
                      onPressed: _done,
                    ),
                  ],
                  const SizedBox(height: Space.md),
                  Center(
                    child: TextButton(
                      key: const Key('sign_in_not_now'),
                      onPressed: () => ref.read(sessionProvider).skipSignIn(),
                      child: const Text('Not now'),
                    ),
                  ),
                  const SizedBox(height: Space.md),
                  Center(
                    child: Text(
                      'By continuing you agree to our Terms and Privacy Policy.',
                      style: context.tt.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

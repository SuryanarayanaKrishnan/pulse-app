import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/env/env.dart';

/// App session state used by router redirects. Mock-friendly: when Supabase is
/// not configured, sign-in succeeds locally.
class SessionController extends ChangeNotifier {
  SessionController({
    this.onboarded = Env.devSkipOnboarding,
    this.signedIn = Env.devSkipOnboarding,
    this.connected = Env.devSkipOnboarding,
  });
  bool onboarded;
  bool signedIn;
  bool connected;

  void finishOnboarding() {
    onboarded = true;
    notifyListeners();
  }

  void signIn() {
    signedIn = true;
    notifyListeners();
  }

  void finishConnect() {
    connected = true;
    notifyListeners();
  }

  Future<void> signOut() async {
    if (Env.hasSupabase) {
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {}
    }
    signedIn = false;
    connected = false;
    notifyListeners();
  }

  /// Sends an email OTP via Supabase, or no-ops in mock mode.
  Future<void> requestEmailOtp(String email) async {
    if (!Env.hasSupabase) return;
    await Supabase.instance.client.auth.signInWithOtp(email: email);
  }

  /// Verifies the OTP. Mock mode accepts any 6-digit code.
  Future<bool> verifyEmailOtp(String email, String code) async {
    if (!Env.hasSupabase) return code.length == 6;
    final res = await Supabase.instance.client.auth.verifyOTP(
      email: email,
      token: code,
      type: OtpType.email,
    );
    return res.session != null;
  }
}

final sessionProvider = Provider<SessionController>((ref) {
  final s = SessionController();
  ref.onDispose(s.dispose);
  return s;
});

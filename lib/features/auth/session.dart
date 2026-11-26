import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../capture/kv_store.dart';
import '../../core/env/env.dart';

/// App session state used by router redirects. Mock-friendly: when Supabase is
/// not configured, sign-in succeeds locally.
class SessionController extends ChangeNotifier {
  SessionController({
    this.onboarded = Env.devSkipOnboarding,
    this.signedIn = Env.devSkipOnboarding,
    this.connected = Env.devSkipOnboarding,
    bool? requireSignIn,
    KvStore? store,
  }) : requireSignIn = requireSignIn ?? Env.hasSupabase,
       // ignore: prefer_initializing_formals
       _store = store;

  bool onboarded;
  bool signedIn;
  bool connected;

  /// Sign-in only means something when there is a backend to sign in to. On
  /// device with no backend the app never asks for an account.
  final bool requireSignIn;

  /// A feature that needs an account asked for one while on device.
  bool _signInRequested = false;

  /// Sign-in blocks the app only when a backend needs it, or when a feature
  /// that needs an account asked for it.
  bool get mustSignIn => !signedIn && (requireSignIn || _signInRequested);

  /// Where the three steps are remembered, so a returning person is not taken
  /// through them again. Null in tests and previews.
  final KvStore? _store;

  static const _kOnboarded = 'session.onboarded';
  static const _kSignedIn = 'session.signed_in';
  static const _kConnected = 'session.connected';

  /// Reads the remembered steps. A storage failure leaves the defaults.
  static Future<SessionController> load(
    KvStore store, {
    bool? requireSignIn,
  }) async {
    var o = Env.devSkipOnboarding,
        s = Env.devSkipOnboarding,
        c = Env.devSkipOnboarding;
    try {
      o = o || await store.read(_kOnboarded) == '1';
      s = s || await store.read(_kSignedIn) == '1';
      c = c || await store.read(_kConnected) == '1';
    } catch (_) {}
    return SessionController(
      onboarded: o,
      signedIn: s,
      connected: c,
      requireSignIn: requireSignIn,
      store: store,
    );
  }

  void _remember(String key, bool on) {
    final st = _store;
    if (st == null) return;
    (on ? st.write(key, '1') : st.remove(key)).catchError((Object _) {});
  }

  void finishOnboarding() {
    onboarded = true;
    _remember(_kOnboarded, true);
    notifyListeners();
  }

  void signIn() {
    signedIn = true;
    _signInRequested = false;
    _remember(_kSignedIn, true);
    notifyListeners();
  }

  /// Opens the sign-in screen from inside the app (a feature that needs a
  /// Pulse account). Keeps the connect step done, so signing in returns home.
  void requestSignIn() {
    signedIn = false;
    _signInRequested = true;
    notifyListeners();
  }

  void finishConnect() {
    connected = true;
    _remember(_kConnected, true);
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
    _remember(_kSignedIn, false);
    _remember(_kConnected, false);
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

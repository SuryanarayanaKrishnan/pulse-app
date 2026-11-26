import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../env/env.dart';

/// What a feature that needs a Pulse account can do right now.
///
/// Everything that holds your own data runs on the phone. The few things that
/// need the server (splitting with other people, family sharing, Gmail,
/// encrypted cloud backup and sync) check this first and show one calm
/// "Available once you're signed in" state instead of an error.
enum CloudAccess {
  /// This build has no backend configured (local and dev builds).
  unavailable,

  /// A backend exists but nobody is signed in to it.
  signedOut,

  /// Signed in; shared features can reach the server.
  ready;

  bool get isReady => this == ready;

  /// A "Sign in" button makes sense only when signing in would unlock it.
  bool get canSignIn => this == signedOut;
}

/// The headline every gated state uses.
const needsSignInTitle = "Available once you're signed in";

CloudAccess currentCloudAccess() {
  if (!Env.useApi && !Env.hasSupabase) return CloudAccess.unavailable;
  if (Env.devAuthEnabled) return CloudAccess.ready;
  if (Env.hasSupabase) {
    try {
      if (Supabase.instance.client.auth.currentSession != null)
        return CloudAccess.ready;
    } catch (_) {
      // Supabase not initialised (tests, web preview): treat as signed out.
    }
    return CloudAccess.signedOut;
  }
  return CloudAccess.signedOut;
}

/// Overridden in tests.
final cloudAccessProvider = Provider<CloudAccess>(
  (ref) => currentCloudAccess(),
);

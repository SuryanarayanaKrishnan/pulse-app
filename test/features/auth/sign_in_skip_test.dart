import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/capture/kv_store.dart';
import 'package:pulse/features/auth/session.dart';

void main() {
  test('with a backend sign-in is asked for; Not now lets the app open and is remembered', () async {
    final store = MemoryKvStore();
    final s = SessionController(requireSignIn: true, store: store, onboarded: true, connected: true);
    expect(s.mustSignIn, isTrue);
    s.skipSignIn();
    expect(s.mustSignIn, isFalse);
    await Future<void>.delayed(Duration.zero);
    final again = await SessionController.load(store, requireSignIn: true);
    expect(again.mustSignIn, isFalse, reason: 'a friend who skipped is not nagged on every launch');
  });

  test('a feature that needs an account can still ask after Not now, and signing in clears the skip', () async {
    final store = MemoryKvStore();
    final s = SessionController(requireSignIn: true, store: store, onboarded: true, connected: true)..skipSignIn();
    s.requestSignIn();
    expect(s.mustSignIn, isTrue);
    s.skipSignIn(); // cancelling the request returns to the app
    expect(s.mustSignIn, isFalse);
    s.signIn();
    expect(s.signedIn, isTrue);
    expect(s.mustSignIn, isFalse);
  });
}

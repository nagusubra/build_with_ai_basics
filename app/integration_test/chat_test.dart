import 'package:bakeout/main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Run against the emulators with the dev seed and `functions/scripts/dev-replier.mjs`
/// playing Tester Two. See `functions/package.json > check:chat`.
Future<void> _pumpUntilFound(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 60)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for $finder');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Tester One logs in, sends a message, and sees Tester Two reply live', (tester) async {
    expect(useEmulators, isTrue, reason: 'Run with --dart-define=USE_EMULATORS=true');
    await initFirebase();
    await FirebaseAuth.instance.signOut();
    await tester.pumpWidget(const BakeOutApp());

    await _pumpUntilFound(tester, find.text('Already have an account? Log in'));
    await tester.tap(find.text('Already have an account? Log in'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('auth-email')), 'tester.one@bakeout.test');
    await tester.enterText(find.byKey(const Key('auth-password')), 'bakeout-dev');
    await tester.tap(find.byKey(const Key('auth-submit')));

    await _pumpUntilFound(tester, find.text('Tester Two'));
    await tester.tap(find.text('Tester Two'));
    await _pumpUntilFound(tester, find.byKey(const Key('chat-input')));

    final token = DateTime.now().millisecondsSinceEpoch.toString();
    await tester.enterText(find.byKey(const Key('chat-input')), 'ping $token');
    await tester.tap(find.byKey(const Key('chat-send')));

    await _pumpUntilFound(tester, find.text('ping $token'));
    await _pumpUntilFound(tester, find.text('pong $token'));
  });
}

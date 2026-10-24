import 'package:bakeout/main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Run with the emulators after `seed-testers.mjs`: log in (with a wrong password first and a
/// reset link), log out from Me, then sign up and log out halfway through onboarding.
Future<void> _until(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 30)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) return;
  }
  final onScreen = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).whereType<String>().join(' | ');
  throw TestFailure('Timed out waiting for $finder. On screen: $onScreen');
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _until(tester, finder);
  await tester.ensureVisible(finder.first);
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.tap(finder.first);
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('log in, log out, and log out mid-onboarding', (tester) async {
    expect(useEmulators, isTrue, reason: 'Run with --dart-define=USE_EMULATORS=true');
    await initFirebase();
    await FirebaseAuth.instance.signOut();
    await tester.pumpWidget(const BakeOutApp());

    // Log in, with a wrong password first.
    await _tap(tester, find.byKey(const Key('welcome-login')));
    await _until(tester, find.byKey(const Key('auth-forgot')));
    expect(find.text('Welcome back'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('auth-email')), 'tester.one@bakeout.test');
    await tester.enterText(find.byKey(const Key('auth-password')), 'not-the-password');
    await _tap(tester, find.byKey(const Key('auth-submit')));
    await _until(tester, find.byKey(const Key('auth-error')));
    expect(find.text("That email and password don't match."), findsOneWidget);

    // Show password, then the reset link.
    final field = find.descendant(of: find.byKey(const Key('auth-password')), matching: find.byType(EditableText));
    expect(tester.widget<EditableText>(field).obscureText, isTrue);
    await _tap(tester, find.byKey(const Key('auth-show-password')));
    expect(tester.widget<EditableText>(field).obscureText, isFalse);
    await _tap(tester, find.byKey(const Key('auth-forgot')));
    await _tap(tester, find.byKey(const Key('reset-send')));
    await _until(tester, find.textContaining('a reset link is on its way'));

    // The right password gets in.
    await tester.enterText(find.byKey(const Key('auth-password')), 'bakeout-dev');
    await _tap(tester, find.byKey(const Key('auth-submit')));
    await _until(tester, find.byKey(const Key('tab-me')));

    // Log out from Me.
    await _tap(tester, find.byKey(const Key('tab-me')));
    await _until(tester, find.text('How others see you'));
    await tester.scrollUntilVisible(find.byKey(const Key('logout')), 400, scrollable: find.descendant(of: find.byKey(const Key('my-profile-list')), matching: find.byType(Scrollable)));
    expect(find.text('tester.one@bakeout.test'), findsOneWidget);
    await _tap(tester, find.byKey(const Key('logout')));
    await _tap(tester, find.byKey(const Key('confirm-logout')));
    await _until(tester, find.byKey(const Key('welcome-start')));
    expect(FirebaseAuth.instance.currentUser, isNull);

    // Sign up, then log out on the first onboarding step.
    await _tap(tester, find.byKey(const Key('welcome-start')));
    await _until(tester, find.text('Create your account'));
    await tester.enterText(find.byKey(const Key('auth-email')), 'new.${DateTime.now().millisecondsSinceEpoch}@bakeout.test');
    await tester.enterText(find.byKey(const Key('auth-password')), 'bakeout-dev');
    await _tap(tester, find.byKey(const Key('auth-submit')));
    await _until(tester, find.byKey(const Key('basics-name')));
    await _tap(tester, find.byKey(const Key('onboarding-menu')));
    await _tap(tester, find.byKey(const Key('onboarding-logout')));
    await _until(tester, find.textContaining('pick up right where you left off'));
    await _tap(tester, find.byKey(const Key('confirm-logout')));
    await _until(tester, find.byKey(const Key('welcome-start')));
    expect(FirebaseAuth.instance.currentUser, isNull);
  });
}

import 'package:bakeout/main.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Run with the emulators after `seed-testers.mjs` (no match): Tester One edits a quiz answer,
/// sees it on her profile, then deletes her account and lands back on Welcome.
Future<void> _until(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 60)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) return;
  }
  final onScreen = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).whereType<String>().join(' | ');
  throw TestFailure('Timed out waiting for $finder. On screen: $onScreen');
}

final _list = find.descendant(of: find.byKey(const Key('my-profile-list')), matching: find.byType(Scrollable)).first;

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 250, scrollable: _list);
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('edit an answer, see it on the profile, then delete everything', (tester) async {
    expect(useEmulators, isTrue, reason: 'Run with --dart-define=USE_EMULATORS=true');
    await initFirebase();
    final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(email: 'tester.one@bakeout.test', password: 'bakeout-dev');
    final uid = cred.user!.uid;
    await tester.pumpWidget(const BakeOutApp());

    await _until(tester, find.byKey(const Key('tab-me')));
    await tester.tap(find.byKey(const Key('tab-me')));
    await _until(tester, find.text('How others see you'));

    await _tapVisible(tester, find.byKey(const Key('edit-signatureDish')));
    await _until(tester, find.byKey(const Key('quiz-text-signatureDish')));
    await tester.enterText(find.byKey(const Key('quiz-text-signatureDish')), 'Midnight masala omelette');
    await tester.tap(find.byKey(const Key('quiz-next')));
    await _until(tester, find.text('Midnight masala omelette')); // the edit list
    await tester.scrollUntilVisible(
      find.textContaining('Signature dish: Midnight masala omelette', findRichText: true),
      -250,
      scrollable: _list,
    ); // and the profile card above it

    final stored = (await FirebaseFirestore.instance.doc('users/$uid').get()).data()!;
    expect((stored['food'] as Map)['signatureDish'], 'Midnight masala omelette');

    await _tapVisible(tester, find.byKey(const Key('delete-account')));
    await _until(tester, find.byKey(const Key('confirm-delete')));
    await tester.tap(find.byKey(const Key('confirm-delete')));
    await _until(tester, find.byKey(const Key('welcome-start')));
    expect(FirebaseAuth.instance.currentUser, isNull);
  });
}

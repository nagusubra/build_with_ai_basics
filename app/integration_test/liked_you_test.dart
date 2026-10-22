import 'package:bakeout/main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Run with the emulators after `seed-testers.mjs --two-likes-one`: Tester Two has liked
/// Tester One, so the server has told Tester One who liked them.
Future<void> _until(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 30)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) return;
  }
  final onScreen = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).whereType<String>().join(' | ');
  throw TestFailure('Timed out waiting for $finder. On screen: $onScreen');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('"Tester Two liked you" appears, and liking back makes the match', (tester) async {
    expect(useEmulators, isTrue, reason: 'Run with --dart-define=USE_EMULATORS=true');
    await initFirebase();
    await FirebaseAuth.instance.signInWithEmailAndPassword(email: 'tester.one@bakeout.test', password: 'bakeout-dev');
    await tester.pumpWidget(const BakeOutApp());

    await _until(tester, find.byKey(const Key('like-banner')));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Tester Two liked you 💗'), findsOneWidget);
    expect(find.byKey(const Key('likes-pill')), findsOneWidget, reason: 'the pill stays after the banner goes');

    await tester.tap(find.byKey(const Key('like-banner')));
    await _until(tester, find.byKey(const Key('liked-like-back')));
    expect(find.text('Tester Two liked your profile. Like back and it’s a match!'), findsOneWidget);
    await tester.tap(find.byKey(const Key('liked-like-back')));

    // The real matching function makes the match; the match moment follows.
    await _until(tester, find.byKey(const Key('break-the-ice')));
    await tester.tap(find.byKey(const Key('break-the-ice')));
    await _until(tester, find.byKey(const Key('chat-input')));
    await tester.pageBack();
    await _until(tester, find.byKey(const Key('tab-discover')));
    final end = DateTime.now().add(const Duration(seconds: 15));
    while (DateTime.now().isBefore(end) && find.byKey(const Key('likes-pill')).evaluate().isNotEmpty) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(find.byKey(const Key('likes-pill')), findsNothing, reason: 'answered, so nobody is waiting any more');
  });
}

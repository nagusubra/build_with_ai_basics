import 'package:bakeout/main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Run with the emulators after `seed-testers.mjs --match`: the testers have matched each other,
/// so Discover is empty for Tester One and the Recipes page takes its place.
Future<void> _until(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 90)}) async {
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

  testWidgets('with nobody new in Discover, Recipes appear, open, and refresh', (tester) async {
    expect(useEmulators, isTrue, reason: 'Run with --dart-define=USE_EMULATORS=true');
    await initFirebase();
    await FirebaseAuth.instance.signInWithEmailAndPassword(email: 'tester.one@bakeout.test', password: 'bakeout-dev');
    await tester.pumpWidget(const BakeOutApp());

    // The new match is celebrated first; head into the chat and back out.
    await _until(tester, find.byKey(const Key('break-the-ice')), timeout: const Duration(seconds: 30));
    await tester.tap(find.byKey(const Key('break-the-ice')));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await tester.pageBack();
    await tester.pump(const Duration(seconds: 1));

    await _until(tester, find.text('No one new right now'));
    await _until(tester, find.textContaining('⏱'));
    List<String?> titles() =>
        tester.widgetList<Text>(find.descendant(of: find.byType(InkWell), matching: find.byType(Text))).map((t) => t.data).toList();
    final firstTitles = titles();
    expect(find.textContaining('⏱'), findsWidgets);

    await tester.tap(find.descendant(of: find.byType(InkWell), matching: find.byType(Text)).first);
    await _until(tester, find.text('Ingredients'));
    await tester.scrollUntilVisible(find.textContaining('⚠️'), 300, scrollable: find.byType(Scrollable).last);
    expect(find.text('Steps'), findsOneWidget);
    await tester.pageBack();
    await tester.pump(const Duration(seconds: 1));

    final newIdeas = find.byKey(const Key('recipes-new-ideas'));
    await tester.scrollUntilVisible(newIdeas, 300, scrollable: find.byType(Scrollable).last);
    await tester.tap(newIdeas);
    await tester.pump(const Duration(seconds: 2));
    await tester.dragUntilVisible(find.text('No one new right now'), find.byType(Scrollable).last, const Offset(0, 400));
    final end = DateTime.now().add(const Duration(seconds: 90));
    bool sameSet() => titles().take(3).join('|') == firstTitles.take(3).join('|');
    while (DateTime.now().isBefore(end) && sameSet()) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(sameSet(), isFalse, reason: '"New ideas" should bring a new set');
  });
}

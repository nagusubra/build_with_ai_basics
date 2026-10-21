import 'package:bakeout/main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Run with the emulators after `seed-testers.mjs` (no --match): both testers are vegetarian,
/// looking for a partner, in Edinburgh, so Tester One sees Tester Two in Discover.
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
  await tester.pump(const Duration(milliseconds: 200));
  await tester.tap(finder.first);
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('filters and the Partner/Friends switch change who Discover shows', (tester) async {
    expect(useEmulators, isTrue, reason: 'Run with --dart-define=USE_EMULATORS=true');
    await initFirebase();
    await FirebaseAuth.instance.signInWithEmailAndPassword(email: 'tester.one@bakeout.test', password: 'bakeout-dev');
    await tester.pumpWidget(const BakeOutApp());

    final card = find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('discover-card-'));
    await _until(tester, card);
    expect(find.byKey(const Key('daily-greeting')), findsOneWidget);
    expect(find.textContaining('Jack ·'), findsOneWidget, reason: 'Tester One has the boy cherry');
    await _until(tester, find.byKey(const Key('dish-of-the-day')));

    // Vegans only: Tester Two is vegetarian, so nobody is left and Recipes offers to change the filters.
    await _tap(tester, find.byKey(const Key('discover-filters')));
    await _tap(tester, find.byKey(const Key('filter-food-Vegan')));
    await _tap(tester, find.byKey(const Key('filters-apply')));
    await _until(tester, find.text('No one new right now'));
    expect(find.byKey(const Key('recipes-edit-filters')), findsOneWidget);
    await _until(tester, find.byKey(const Key('recipes-dish-of-the-day')));

    // A city from the list, and an age range that fits: still nobody (still vegans only).
    await _tap(tester, find.byKey(const Key('recipes-edit-filters')));
    await _tap(tester, find.byKey(const Key('filter-add-city')));
    await tester.enterText(find.byKey(const Key('city-search')), 'edin');
    await _tap(tester, find.byKey(const Key('city-Edinburgh, UK')));
    await _until(tester, find.byKey(const Key('filter-city-Edinburgh, UK')));

    // Reset clears food, age and cities; Tester Two is back.
    await _tap(tester, find.byKey(const Key('filters-reset')));
    expect(find.byKey(const Key('filter-city-Edinburgh, UK')), findsNothing);
    await _tap(tester, find.byKey(const Key('filters-apply')));
    await _until(tester, card);

    // Friends mode: Tester Two wants a partner, so they're hidden — and the pill says Friends.
    await _tap(tester, find.byKey(const Key('discover-mode')));
    await _tap(tester, find.byKey(const Key('mode-friends')));
    await _tap(tester, find.byKey(const Key('filters-apply')));
    await _until(tester, find.text('No one new right now'));
    expect(find.text('🤝 Friends'), findsOneWidget);

    // And back to Partner.
    await _tap(tester, find.byKey(const Key('discover-mode')));
    await _tap(tester, find.byKey(const Key('mode-partner')));
    await _tap(tester, find.byKey(const Key('filters-apply')));
    await _until(tester, card);
  });
}

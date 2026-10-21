import 'package:bakeout/main.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Signs up through the real screens against the emulators, answers the quiz (skipping the
/// optional cards), and checks what landed in Firestore. Photos and the selfie check need a
/// device and are checked by hand.
Future<void> _until(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 30)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for $finder');
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _until(tester, finder);
  await tester.ensureVisible(finder.first);
  await tester.pump();
  await tester.tap(finder.first);
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _next(WidgetTester tester) => _tap(tester, find.byKey(const Key('quiz-next')));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a new person signs up, fills in basics and the quiz, and lands on photos', (tester) async {
    expect(useEmulators, isTrue, reason: 'Run with --dart-define=USE_EMULATORS=true');
    await initFirebase();
    await FirebaseAuth.instance.signOut();
    await tester.pumpWidget(const BakeOutApp());

    await _tap(tester, find.byKey(const Key('welcome-start')));
    final email = 'new.${DateTime.now().millisecondsSinceEpoch}@bakeout.test';
    await _until(tester, find.byKey(const Key('auth-email')));
    await tester.enterText(find.byKey(const Key('auth-email')), email);
    await tester.enterText(find.byKey(const Key('auth-password')), 'bakeout-dev');
    await _tap(tester, find.byKey(const Key('auth-submit')));

    // Basics: an under-18 birthday is refused, then an adult one is accepted.
    await _until(tester, find.byKey(const Key('basics-name')));
    await tester.enterText(find.byKey(const Key('basics-name')), 'Priya');
    await _tap(tester, find.byKey(const Key('basics-city')));
    await _until(tester, find.byKey(const Key('city-search')));
    await tester.enterText(find.byKey(const Key('city-search')), 'glas');
    await _tap(tester, find.byKey(const Key('city-Glasgow, UK')));
    await _tap(tester, find.byKey(const Key('gender-Woman')));
    await _tap(tester, find.byKey(const Key('meet-Men')));
    await _tap(tester, find.byKey(const Key('looking-partner')));

    Future<void> pickDob(String typed) async {
      await _tap(tester, find.byKey(const Key('basics-dob')));
      await _tap(tester, find.byIcon(Icons.edit_outlined));
      await tester.enterText(find.byType(TextField).last, typed);
      await _tap(tester, find.text('OK'));
    }

    final teen = DateTime.now().subtract(const Duration(days: 365 * 17));
    await pickDob('${teen.month}/${teen.day}/${teen.year}');
    await _tap(tester, find.byKey(const Key('basics-continue')));
    await _until(tester, find.text('BakeOut is for people aged 18 and over.'));

    await pickDob('3/14/2000');
    await _tap(tester, find.byKey(const Key('basics-continue')));

    // Quiz.
    await _tap(tester, find.byKey(const Key('opt-I cook when I have time')));
    await _next(tester);
    await _tap(tester, find.byKey(const Key('opt-Vegetarian')));
    await _next(tester);
    await _tap(tester, find.byKey(const Key('opt-Nut allergy')));
    await _next(tester);
    await _tap(tester, find.byKey(const Key('opt-Italian')));
    await _tap(tester, find.byKey(const Key('opt-Thai')));
    await _next(tester);
    await _tap(tester, find.byKey(const Key('top-Italian')));
    await _next(tester);
    await _until(tester, find.byKey(const Key('quiz-text-signatureDish')));
    await tester.enterText(find.byKey(const Key('quiz-text-signatureDish')), 'Fresh pasta from scratch');
    await _next(tester);
    await _tap(tester, find.byKey(const Key('quiz-skip'))); // adventure
    await _tap(tester, find.byKey(const Key('opt-Baking something sweet')));
    await _next(tester);
    await _tap(tester, find.byKey(const Key('opt-The perfectionist')));
    await _next(tester);
    await _tap(tester, find.byKey(const Key('quiz-skip'))); // comfort food
    await _tap(tester, find.byKey(const Key('opt-Around an hour')));
    await _next(tester);
    await _tap(tester, find.byKey(const Key('quiz-skip'))); // music
    await _tap(tester, find.byKey(const Key('quiz-skip'))); // prompts

    await _until(tester, find.text('Add your photos'));

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final user = (await FirebaseFirestore.instance.doc('users/$uid').get()).data()!;
    final private = (await FirebaseFirestore.instance.doc('users/$uid/private/account').get()).data()!;
    expect(user['name'], 'Priya');
    expect(user['age'], greaterThanOrEqualTo(26));
    expect(user['lookingFor'], 'partner');
    expect(user['cherryAvatar'], 'girl');
    expect(user['quizDone'], isTrue);
    expect(user.containsKey('dateOfBirth'), isFalse, reason: 'birthday stays private');
    expect((private['dateOfBirth'] as Timestamp).toDate(), DateTime(2000, 3, 14));
    final food = (user['food'] as Map).cast<String, dynamic>();
    expect(food['foodType'], 'Vegetarian');
    expect(food['restrictions'], ['Nut allergy']);
    expect(food['topCuisines'], ['Italian']);
    expect(food['signatureDish'], 'Fresh pasta from scratch');
    expect(food['cookingPersonality'], ['The perfectionist']);
    expect(food.containsKey('comfortFood'), isFalse);
  });
}

import 'package:bakeout/models/chat_match.dart';
import 'package:bakeout/models/message.dart';
import 'package:bakeout/theme/theme.dart';
import 'package:bakeout/widgets/chat_cards.dart';
import 'package:bakeout/widgets/mascot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ChatMessage _card(int version) => ChatMessage(
      id: 'c$version',
      sender: cherrySender,
      type: 'dateCard',
      text: '',
      sentAt: DateTime(2026, 10, 21),
      payload: {'dish': 'Veggie enchiladas', 'dishWhy': 'Both vegetarian', 'day': 'Saturday', 'time': '7:00 pm', 'version': version},
    );

Future<List<int>> _pump(WidgetTester tester, ChatMessage card, DatePlan plan) async {
  final taps = <int>[];
  await tester.pumpWidget(MaterialApp(
    theme: buildBakeTheme(),
    home: Scaffold(
      body: SingleChildScrollView(
        child: DateCardView(
          message: card,
          plan: plan,
          myUid: 'me',
          otherUid: 'them',
          otherName: 'Sam',
          planningPose: MascotPose.boyPlanning,
          onConfirm: (v) async => taps.add(v),
        ),
      ),
    ),
  ));
  return taps;
}

void main() {
  testWidgets('the current card shows the plan and a Confirm button that confirms that version', (tester) async {
    final taps = await _pump(tester, _card(2), const DatePlan(status: 'proposed', version: 2));
    expect(find.text('Veggie enchiladas'), findsOneWidget);
    expect(find.textContaining('Saturday'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-date-2')));
    expect(taps, [2]);
  });

  testWidgets('after I confirm, I wait for the other person', (tester) async {
    await _pump(tester, _card(2), const DatePlan(status: 'proposed', version: 2, confirmedBy: {'me': true}));
    expect(find.byKey(const Key('confirm-date-2')), findsNothing);
    expect(find.text('Waiting for Sam to confirm…'), findsOneWidget);
  });

  testWidgets('an outdated card cannot be confirmed', (tester) async {
    await _pump(tester, _card(1), const DatePlan(status: 'proposed', version: 2));
    expect(find.byKey(const Key('confirm-date-1')), findsNothing);
    expect(find.textContaining('This plan was updated'), findsOneWidget);
  });

  testWidgets('a card both confirmed says it is a date', (tester) async {
    await _pump(tester, _card(2), const DatePlan(status: 'confirmed', version: 2, confirmedBy: {'me': true, 'them': true}));
    expect(find.text("It's a date! 🎉"), findsOneWidget);
  });
}

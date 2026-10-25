import 'package:bakeout/widgets/guided_tour.dart';
import 'package:bakeout/widgets/mascot.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(GlobalKey target, void Function(bool) onDone) => MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            Positioned(left: 20, top: 300, width: 200, height: 80, child: SizedBox(key: target)),
            Positioned.fill(
              child: GuidedTour(
                onDone: onDone,
                steps: [
                  const TourStep(title: 'Hi there', body: 'Welcome', pose: MascotPose.boyHello),
                  TourStep(title: 'Discover', body: 'Swipe', pose: MascotPose.boyCheer, target: target),
                  const TourStep(title: 'All set', body: 'Go', pose: MascotPose.duoMatch),
                ],
              ),
            ),
          ],
        ),
      ),
    );

void main() {
  testWidgets('walks through every step and finishes without skipping', (tester) async {
    bool? skipped;
    await tester.pumpWidget(_app(GlobalKey(), (s) => skipped = s));
    await tester.pumpAndSettle();
    expect(find.text('Hi there'), findsOneWidget);
    expect(find.text('Show me'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tour-next')));
    await tester.pumpAndSettle();
    expect(find.text('Discover'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tour-next')));
    await tester.pumpAndSettle();
    expect(find.text('All set'), findsOneWidget);
    expect(find.byKey(const Key('tour-skip')), findsNothing, reason: 'nothing to skip on the last step');
    expect(find.text('Start exploring'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tour-next')));
    expect(skipped, isFalse);
  });

  testWidgets('"Skip tour" ends it straight away', (tester) async {
    bool? skipped;
    await tester.pumpWidget(_app(GlobalKey(), (s) => skipped = s));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tour-skip')));
    expect(skipped, isTrue);
  });

  testWidgets('keyboard: Enter moves on, Esc skips', (tester) async {
    bool? skipped;
    await tester.pumpWidget(_app(GlobalKey(), (s) => skipped = s));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Discover'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(skipped, isTrue);
  });

  testWidgets('the card sits next to the highlighted area', (tester) async {
    final target = GlobalKey();
    await tester.pumpWidget(_app(target, (_) {}));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tour-next')));
    await tester.pumpAndSettle();
    final card = tester.getRect(find.ancestor(of: find.text('Discover'), matching: find.byType(Material)).first);
    final area = tester.getRect(find.byKey(target));
    expect(card.top >= area.bottom || card.bottom <= area.top, isTrue, reason: 'the card never covers the area it explains');
  });
}

import 'dart:async';

import 'package:bakeout/widgets/startup_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'keeps the same splash and mascot until the destination is ready',
    (tester) async {
      final initialization = Completer<void>();
      late VoidCallback destinationReady;
      var builds = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: StartupGate(
            initialize: () => initialization.future,
            buildDestination: (onReady) {
              destinationReady = onReady;
              builds++;
              return const Scaffold(body: Text('Destination'));
            },
          ),
        ),
      );
      final splash = tester.element(find.byKey(const Key('startup-splash')));
      final mascot = tester.element(find.byKey(const Key('startup-mascot')));
      final mascotRect = tester.getRect(
        find.byKey(const Key('startup-mascot')),
      );

      initialization.complete();
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));

      expect(
        tester.element(find.byKey(const Key('startup-splash'))),
        same(splash),
      );
      expect(
        tester.element(find.byKey(const Key('startup-mascot'))),
        same(mascot),
      );
      expect(
        tester.getRect(find.byKey(const Key('startup-mascot'))),
        mascotRect,
      );
      expect(builds, 1);

      destinationReady();
      await tester.pump();
      expect(find.byKey(const Key('startup-splash')), findsNothing);
      expect(find.text('Destination'), findsOneWidget);
      expect(builds, 1);
    },
  );

  testWidgets('startup failure is visible and retry keeps the mascot mounted', (
    tester,
  ) async {
    var attempts = 0;
    late VoidCallback destinationReady;
    await tester.pumpWidget(
      MaterialApp(
        home: StartupGate(
          initialize: () async {
            if (attempts++ == 0) throw StateError('Offline');
          },
          buildDestination: (onReady) {
            destinationReady = onReady;
            return const Scaffold(body: Text('Destination'));
          },
        ),
      ),
    );
    await tester.pump();
    final mascot = tester.element(find.byKey(const Key('startup-mascot')));
    expect(find.text('Try again'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(attempts, 2);
    expect(
      tester.element(find.byKey(const Key('startup-mascot'))),
      same(mascot),
    );
    destinationReady();
    await tester.pump();
    expect(find.byKey(const Key('startup-splash')), findsNothing);
  });
}

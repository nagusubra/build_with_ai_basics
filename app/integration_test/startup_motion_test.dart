import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bakeout/widgets/mascot_rive.dart';
import 'package:bakeout/widgets/startup_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rive/rive.dart' show RiveWidget;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'the real splash paints moving frames without a native texture or a loading-screen reset',
    (tester) async {
      await MascotMotion.init();
      expect(MascotMotion.available, isTrue);
      final initialization = Completer<void>();
      late VoidCallback destinationReady;
      await tester.pumpWidget(
        MaterialApp(
          home: StartupGate(
            initialize: () => initialization.future,
            buildDestination: (onReady) {
              destinationReady = onReady;
              return const Scaffold(body: Text('Ready'));
            },
          ),
        ),
      );
      final mascot = find.byKey(const Key('startup-mascot'));
      for (
        var i = 0;
        i < 100 && find.byType(RiveWidget).evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(RiveWidget), findsOneWidget);
      expect(
        find.descendant(of: mascot, matching: find.byType(Texture)),
        findsNothing,
      );
      final element = tester.element(mascot);
      final rect = tester.getRect(mascot);
      final boundaryFinder = find
          .descendant(of: mascot, matching: find.byType(RepaintBoundary))
          .first;

      Future<Uint8List> capture() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          boundaryFinder,
        );
        final image = await boundary.toImage(pixelRatio: 1);
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        image.dispose();
        return data!.buffer.asUint8List();
      }

      await tester.pump(const Duration(milliseconds: 100));
      final first = await capture();
      var opaquePixels = 0;
      for (var i = 3; i < first.length; i += 4) {
        if (first[i] > 200) opaquePixels++;
      }
      expect(
        opaquePixels,
        greaterThan(1000),
        reason: 'The mascot must not paint a blank frame.',
      );

      await tester.pump(const Duration(milliseconds: 800));
      final second = await capture();
      var movingPixels = 0;
      for (var i = 0; i < first.length; i += 4) {
        if ((first[i] - second[i]).abs() > 12 ||
            (first[i + 1] - second[i + 1]).abs() > 12 ||
            (first[i + 2] - second[i + 2]).abs() > 12) {
          movingPixels++;
        }
      }
      expect(
        movingPixels,
        greaterThan(100),
        reason: 'The actual Rive frames must animate, not just the loading spinner.',
      );

      initialization.complete();
      await tester.pump();
      expect(tester.element(mascot), same(element));
      expect(tester.getRect(mascot), rect);
      destinationReady();
      await tester.pump();
      expect(find.byKey(const Key('startup-splash')), findsNothing);
      expect(find.text('Ready'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

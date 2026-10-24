import 'package:bakeout/widgets/mascot.dart';
import 'package:bakeout/widgets/mascot_rive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only the seven hero poses have a Rive artboard', () {
    const heroes = {
      MascotPose.duoWelcome: 'DuoWelcome',
      MascotPose.duoMatch: 'DuoMatch',
      MascotPose.duoCooking: 'DuoCooking',
      MascotPose.boyHello: 'BoyHello',
      MascotPose.girlHello: 'GirlHello',
      MascotPose.boyCheer: 'BoyCheer',
      MascotPose.girlCheer: 'GirlCheer',
    };

    for (final pose in MascotPose.values) {
      expect(pose.riveArtboard, heroes[pose], reason: pose.name);
    }
  });

  testWidgets('falls back to the PNG when Rive is not available', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: AnimatedMascot(
            MascotPose.duoWelcome,
            size: 120,
            bob: false,
            animationAsset: MascotMotion.welcomeAsset,
            posterAsset: MascotMotion.welcomePosterAsset,
          ),
        ),
      ),
    );

    expect(find.byType(Image), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as AssetImage).assetName,
      MascotMotion.welcomePosterAsset,
    );
  });

  test('the new DuoWelcome animation is bundled', () async {
    final animation = await rootBundle.load(MascotMotion.welcomeAsset);
    expect(animation.lengthInBytes, greaterThan(0));
    final poster = await rootBundle.load(MascotMotion.welcomePosterAsset);
    expect(poster.lengthInBytes, greaterThan(0));
  });
}

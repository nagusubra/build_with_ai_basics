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

  test('each wingman rig maps to its Jack and Jill artboards and posters', () {
    const expectations = {
      'boy': {
        WingmanRig.hero: ['JackWingman', 'jack_smile.png'],
        WingmanRig.think: ['JackThink', 'jack_think.png'],
        WingmanRig.idea: ['JackIdea', 'jack_idea.png'],
        WingmanRig.write: ['JackWrite', 'jack_write.png'],
        WingmanRig.smile: ['JackSmile', 'jack_smile.png'],
      },
      'girl': {
        WingmanRig.hero: ['JillWingwoman', 'jill_smile.png'],
        WingmanRig.think: ['JillThink', 'jill_think.png'],
        WingmanRig.idea: ['JillIdea', 'jill_idea.png'],
        WingmanRig.write: ['JillWrite', 'jill_write.png'],
        WingmanRig.smile: ['JillSmile', 'jill_smile.png'],
      },
      null: {
        WingmanRig.hero: ['JackWingman', 'jack_smile.png'],
        WingmanRig.think: ['JackThink', 'jack_think.png'],
      },
    };
    expectations.forEach((cherry, poses) {
      final wingman = Wingman(cherry);
      expect(wingman.rig(WingmanRig.hero).animationAsset,
          'assets/mascots/rive/${cherry == 'girl' ? 'jill_wingwoman' : 'jack_wingman'}.riv');
      poses.forEach((rig, expected) {
        final pose = wingman.rig(rig);
        expect(pose.artboard, expected[0], reason: '${wingman.name}/${rig.name}');
        expect(pose.posterAsset, 'assets/mascots/${expected[1]}',
            reason: '${wingman.name}/${rig.name}');
      });
    });
  });

  test('the wingman rigs and their posters are bundled', () async {
    for (final asset in [
      MascotMotion.jackAsset,
      MascotMotion.jillAsset,
    ]) {
      final animation = await rootBundle.load(asset);
      expect(animation.lengthInBytes, greaterThan(0), reason: asset);
    }
    for (final cherry in ['jack', 'jill']) {
      for (final pose in ['think', 'idea', 'write', 'smile']) {
        final poster = 'assets/mascots/${cherry}_$pose.png';
        final bytes = await rootBundle.load(poster);
        expect(bytes.lengthInBytes, greaterThan(0), reason: poster);
      }
    }
  });

  testWidgets('AnimatedWingman falls back to the rest poster when Rive is off', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          // Not const: the rig pose is resolved from the wingman at runtime.
          child: AnimatedWingman(Wingman('girl').rig(WingmanRig.think), size: 120),
        ),
      ),
    );

    expect(find.byType(Image), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as AssetImage).assetName,
      Wingman('girl').rig(WingmanRig.think).posterAsset,
    );
  });
}

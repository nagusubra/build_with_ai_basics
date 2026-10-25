import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/colors.dart';

enum MascotPose {
  duoWelcome('cherry_duo_welcome', 'DuoWelcome'),
  duoMatch('cherry_duo_match', 'DuoMatch'),
  duoVerify('cherry_duo_verify'),
  duoCooking('cherry_duo_cooking', 'DuoCooking'),
  boyHello('cherry_boy_hello', 'BoyHello'),
  girlHello('cherry_girl_hello', 'GirlHello'),
  boyCheer('cherry_boy_cheer', 'BoyCheer'),
  girlCheer('cherry_girl_cheer', 'GirlCheer'),
  boyPlanning('cherry_boy_planning'),
  girlPlanning('cherry_girl_planning'),
  boyGoodbye('cherry_boy_goodbye'),
  girlGoodbye('cherry_girl_goodbye'),
  boyTryAgain('cherry_boy_tryagain'),
  girlTryAgain('cherry_girl_tryagain');

  const MascotPose(this.file, [this.riveArtboard]);
  final String file;

  /// The matching artboard in `cherry_mascots.riv`, or null for small/static poses.
  final String? riveArtboard;

  String get asset => 'assets/mascots/$file.png';
}

/// One clip from the personal wingman rigs: the Rive file, the artboard inside
/// it, and the static rest pose that shows on web / reduced motion / failure.
class WingmanPose {
  const WingmanPose(this.animationAsset, this.artboard, this.posterAsset);

  final String animationAsset;
  final String artboard;
  final String posterAsset;
}

/// Which clip to play from a person's wingman rig. `hero` is the full
/// think → idea → write → smile story; the rest loop a single emotion.
enum WingmanRig { hero, think, idea, write, smile }

/// Jack (the boy cherry) and Jill (the girl cherry): a person's own wingman, by name and pose.
class Wingman {
  const Wingman(this.cherry);

  /// "boy" or "girl"; anything else is Jack.
  final String? cherry;

  bool get isJill => cherry == 'girl';
  String get name => isJill ? 'Jill' : 'Jack';
  MascotPose get hello => isJill ? MascotPose.girlHello : MascotPose.boyHello;
  MascotPose get cheer => isJill ? MascotPose.girlCheer : MascotPose.boyCheer;
  MascotPose get planning => isJill ? MascotPose.girlPlanning : MascotPose.boyPlanning;
  MascotPose get goodbye => isJill ? MascotPose.girlGoodbye : MascotPose.boyGoodbye;
  MascotPose get tryAgain => isJill ? MascotPose.girlTryAgain : MascotPose.boyTryAgain;

  /// The Jack/Jill rig clip for [rig], personalized by this wingman's cherry
  /// (`app/tool/mascot_rive_jack`, `app/tool/mascot_rive_jill`).
  WingmanPose rig(WingmanRig rig) {
    final prefix = isJill ? 'jill' : 'jack';
    final character = isJill ? 'Jill' : 'Jack';
    final board = switch (rig) {
      WingmanRig.hero => character + (isJill ? 'Wingwoman' : 'Wingman'),
      WingmanRig.think => '${character}Think',
      WingmanRig.idea => '${character}Idea',
      WingmanRig.write => '${character}Write',
      WingmanRig.smile => '${character}Smile',
    };
    final poster = switch (rig) {
      WingmanRig.hero => 'assets/mascots/${prefix}_smile.png',
      _ => 'assets/mascots/${prefix}_${rig.name}.png',
    };
    return WingmanPose(
      'assets/mascots/rive/${prefix}_${isJill ? 'wingwoman' : 'wingman'}.riv',
      board,
      poster,
    );
  }
}

/// The cherries bobbing while something loads, instead of a bare spinner.
class CherryLoading extends StatelessWidget {
  const CherryLoading({super.key, this.caption = 'Just a moment…'});

  final String caption;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Mascot(MascotPose.duoCooking, size: 120),
            const SizedBox(height: 6),
            Text(caption, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: BakeColors.muted)),
          ],
        ),
      );
}

/// A mascot image with a gentle idle bob, so the cherries never sit perfectly still.
class Mascot extends StatelessWidget {
  const Mascot(this.pose, {super.key, this.size = 220, this.bob = true});

  final MascotPose pose;
  final double size;
  final bool bob;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(pose.asset, width: size, height: size, fit: BoxFit.contain);
    if (!bob) return image;
    return image
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .moveY(begin: 0, end: -8, duration: 1400.ms, curve: Curves.easeInOut);
  }
}

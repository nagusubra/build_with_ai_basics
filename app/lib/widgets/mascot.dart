import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

enum MascotPose {
  duoWelcome('cherry_duo_welcome'),
  duoMatch('cherry_duo_match'),
  duoVerify('cherry_duo_verify'),
  duoCooking('cherry_duo_cooking'),
  boyHello('cherry_boy_hello'),
  girlHello('cherry_girl_hello'),
  boyCheer('cherry_boy_cheer'),
  girlCheer('cherry_girl_cheer'),
  boyPlanning('cherry_boy_planning'),
  girlPlanning('cherry_girl_planning'),
  boyGoodbye('cherry_boy_goodbye'),
  girlGoodbye('cherry_girl_goodbye'),
  boyTryAgain('cherry_boy_tryagain'),
  girlTryAgain('cherry_girl_tryagain');

  const MascotPose(this.file);
  final String file;

  String get asset => 'assets/mascots/$file.png';
}

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

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/profile.dart';
import '../../services/profile_service.dart';
import '../../theme/colors.dart';
import '../../widgets/mascot.dart';
import '../../widgets/onboarding.dart';

/// "It's a BakeOut! 🍒❤️" (`prd.md > The Match Moment`).
class MatchMomentScreen extends StatelessWidget {
  const MatchMomentScreen({super.key, required this.me, required this.them, required this.profiles, required this.onBreakTheIce});

  final UserProfile me;
  final UserProfile them;
  final ProfileService profiles;
  final VoidCallback onBreakTheIce;

  Widget _avatar(UserProfile p, double turn) => Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)),
        child: ClipOval(
          child: p.photos.isEmpty
              ? const ColoredBox(color: BakeColors.softPink, child: Center(child: Text('🍒', style: TextStyle(fontSize: 40))))
              : StoragePhoto(path: p.photos.first, profiles: profiles),
        ),
      ).animate().rotate(begin: turn, end: 0, duration: 500.ms).fadeIn();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: BakeColors.softPink,
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(child: _HeartBurst()),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 20, 28, 20),
              child: Column(
                children: [
                  const Spacer(),
                  Text("It's a BakeOut! 🍒❤️", textAlign: TextAlign.center, style: text.displaySmall)
                      .animate()
                      .scale(begin: const Offset(0.6, 0.6), end: const Offset(1, 1), curve: Curves.elasticOut, duration: 900.ms),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [_avatar(me, -0.05), const SizedBox(width: 12), _avatar(them, 0.05)],
                  ),
                  const Mascot(MascotPose.duoMatch, size: 220)
                      .animate()
                      .slideY(begin: 0.4, end: 0, duration: 600.ms, curve: Curves.easeOutBack)
                      .fadeIn(),
                  Text(
                    'Looks like you’ve found your cooking partner!',
                    textAlign: TextAlign.center,
                    style: text.titleLarge?.copyWith(color: BakeColors.charcoal),
                  ).animate().fadeIn(delay: 400.ms),
                  const Spacer(),
                  FilledButton(key: const Key('break-the-ice'), onPressed: onBreakTheIce, child: const Text('Let’s Break the Ice!')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hearts and confetti drifting up, drawn as separate animated pieces.
class _HeartBurst extends StatelessWidget {
  const _HeartBurst();

  @override
  Widget build(BuildContext context) {
    final rnd = Random(7);
    const pieces = ['❤️', '💗', '🍒', '✨', '💖', '🎉'];
    return LayoutBuilder(
      builder: (context, box) => Stack(
        children: [
          for (var i = 0; i < 18; i++)
            Positioned(
              left: rnd.nextDouble() * box.maxWidth,
              top: box.maxHeight * (0.35 + rnd.nextDouble() * 0.6),
              child: Text(pieces[i % pieces.length], style: TextStyle(fontSize: 16 + rnd.nextDouble() * 18))
                  .animate(delay: (rnd.nextInt(600)).ms)
                  .fadeIn(duration: 300.ms)
                  .moveY(begin: 0, end: -box.maxHeight * 0.4, duration: (1600 + rnd.nextInt(900)).ms, curve: Curves.easeOut)
                  .fadeOut(delay: 1200.ms, duration: 600.ms),
            ),
        ],
      ),
    );
  }
}

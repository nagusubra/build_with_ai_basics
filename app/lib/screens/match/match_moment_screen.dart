import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/profile.dart';
import '../../services/profile_service.dart';
import '../../theme/colors.dart';
import '../../widgets/mascot.dart';
import '../../widgets/mascot_rive.dart';
import '../../widgets/onboarding.dart';

/// "It's a BakeOut! 🍒❤️" (`prd.md > The Match Moment`).
class MatchMomentScreen extends StatelessWidget {
  const MatchMomentScreen({
    super.key,
    required this.me,
    required this.them,
    required this.wingman,
    this.theirWingman,
    required this.profiles,
    required this.onBreakTheIce,
  });

  final UserProfile me;
  final Wingman wingman;

  /// The other person's own Jack or Jill, when the match says which.
  final Wingman? theirWingman;
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
                  _MatchThenNotes(mine: wingman, theirs: theirWingman)
                      .animate()
                      .slideY(begin: 0.4, end: 0, duration: 600.ms, curve: Curves.easeOutBack)
                      .fadeIn(),
                  Text(
                    'Looks like you’ve found your cooking partner!',
                    textAlign: TextAlign.center,
                    style: text.titleLarge?.copyWith(color: BakeColors.charcoal),
                  ).animate().fadeIn(delay: 400.ms),
                  const SizedBox(height: 6),
                  Text(
                    '${wingman.name} is waiting in the chat to help you two say hello.',
                    textAlign: TextAlign.center,
                    style: text.bodyLarge?.copyWith(color: BakeColors.muted),
                  ).animate().fadeIn(delay: 650.ms),
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

/// Jack and Jill come together for the match, then hand over to the two wingmen already
/// writing notes for the chat.
class _MatchThenNotes extends StatelessWidget {
  const _MatchThenNotes({required this.mine, this.theirs});

  final Wingman mine;
  final Wingman? theirs;

  static const _together = Duration(milliseconds: 2400);

  @override
  Widget build(BuildContext context) {
    final other = theirs;
    final writers = [mine, ?other];
    final caption = other == null
        ? '${mine.name} is already taking notes ✍️'
        : other.name == mine.name
            ? 'Both ${mine.name}s are already taking notes ✍️'
            : '${mine.name} and ${other.name} are already taking notes ✍️';
    return SizedBox(
      height: 236,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const AnimatedMascot(MascotPose.duoMatch, size: 220)
              .animate(delay: _together)
              .fadeOut(duration: 450.ms)
              .scale(end: const Offset(0.85, 0.85), duration: 450.ms),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final w in writers) AnimatedWingman(w.rig(WingmanRig.write), size: writers.length == 1 ? 190 : 150, bob: false),
                ],
              ),
              Text(
                caption,
                key: const Key('match-wingmen-notes'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: BakeColors.deepCherry, fontWeight: FontWeight.w800),
              ),
            ],
          )
              .animate(delay: _together + 300.ms)
              .fadeIn(duration: 500.ms)
              .scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack, duration: 500.ms),
        ],
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

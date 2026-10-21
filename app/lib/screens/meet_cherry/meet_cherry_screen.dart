import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/profile.dart';
import '../../services/profile_service.dart';
import '../../theme/colors.dart';
import '../../widgets/mascot.dart';

/// One short, animated introduction to the wingman (`prd.md > Meet Cherry`).
class MeetCherryScreen extends StatelessWidget {
  const MeetCherryScreen({super.key, required this.profile, required this.profiles});

  final UserProfile profile;
  final ProfileService profiles;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final wingman = Wingman(profile.cherryAvatar);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 20),
          child: Column(
            children: [
              const Spacer(),
              Mascot(wingman.hello, size: 240)
                  .animate()
                  .slideX(begin: -0.6, end: 0, duration: 600.ms, curve: Curves.easeOutBack)
                  .fadeIn(),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: BakeColors.softPink, borderRadius: BorderRadius.circular(22)),
                child: Text(
                  "Hey, I'm ${wingman.name}! 🍒 I'm your wingman, here to help you skip the awkward hellos. "
                  "When you find someone you like, I'll help you two break the ice and plan something delicious. "
                  "Once you're ready, I'll leave the rest to you.",
                  style: text.titleMedium,
                ),
              ).animate().fadeIn(delay: 450.ms, duration: 400.ms).moveY(begin: 12, end: 0),
              const Spacer(),
              FilledButton(
                key: const Key('meet-cherry-continue'),
                onPressed: () => profiles.completeOnboarding(profile.uid),
                child: Text("Let's go, ${wingman.name}! 🍒"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../models/profile.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../widgets/log_out_sheet.dart';
import '../widgets/onboarding.dart';
import 'auth/basics_screen.dart';
import 'meet_cherry/meet_cherry_screen.dart';
import 'photos/photos_screen.dart';
import 'photos/verify_screen.dart';
import 'profile/preview_screen.dart';
import 'quiz/questions.dart';
import 'quiz/quiz_screen.dart';

enum OnboardingStep { basics, quiz, photos, verify, preview, meetCherry, done }

/// The next unfinished step, so a returning person picks up exactly where they left off.
OnboardingStep nextStep(UserProfile p) {
  if (p.onboardingComplete) return OnboardingStep.done;
  if (!p.hasBasics) return OnboardingStep.basics;
  if (!p.quizDone || !quizComplete(p.food)) return OnboardingStep.quiz;
  if (p.photos.isEmpty) return OnboardingStep.photos;
  if (!p.verified) return OnboardingStep.verify;
  if (!p.previewSeen) return OnboardingStep.preview;
  if (!p.onboardingComplete) return OnboardingStep.meetCherry;
  return OnboardingStep.done;
}

/// Shows the step [nextStep] picks; each step's save moves the person on.
class OnboardingFlow extends StatelessWidget {
  const OnboardingFlow({super.key, required this.profile, required this.profiles, required this.auth});

  final UserProfile profile;
  final ProfileService profiles;
  final AuthService auth;

  @override
  Widget build(BuildContext context) {
    final step = nextStep(profile);
    final screen = switch (step) {
      OnboardingStep.basics => BasicsScreen(uid: profile.uid, profiles: profiles),
      OnboardingStep.quiz => QuizScreen(profile: profile, profiles: profiles, onDone: () {}),
      OnboardingStep.photos => PhotosScreen(profile: profile, profiles: profiles, onDone: () {}),
      OnboardingStep.verify => VerifyScreen(profile: profile, profiles: profiles),
      OnboardingStep.preview => PreviewScreen(profile: profile, profiles: profiles),
      OnboardingStep.meetCherry || OnboardingStep.done => MeetCherryScreen(profile: profile, profiles: profiles),
    };
    return OnboardingExit(
      onLogOut: () => confirmLogOut(context, auth: auth, cherry: profile.cherryAvatar, midOnboarding: true),
      child: KeyedSubtree(key: ValueKey(step), child: screen),
    );
  }
}

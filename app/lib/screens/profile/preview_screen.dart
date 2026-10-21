import 'package:flutter/material.dart';

import '../../models/profile.dart';
import '../../services/profile_service.dart';
import '../../widgets/onboarding.dart';
import 'profile_view.dart';

/// "Here's how others will see you" at the end of onboarding.
class PreviewScreen extends StatelessWidget {
  const PreviewScreen({super.key, required this.profile, required this.profiles});

  final UserProfile profile;
  final ProfileService profiles;

  @override
  Widget build(BuildContext context) {
    return OnboardingPage(
      title: 'Your BakeOut profile',
      subtitle: "Here's how others will see you.",
      progress: 0.95,
      action: FilledButton(
        key: const Key('preview-continue'),
        onPressed: () => profiles.markPreviewSeen(profile.uid),
        child: const Text("Looks Delicious! Let's Meet Someone"),
      ),
      child: ProfileView(profile: profile, profiles: profiles),
    );
  }
}

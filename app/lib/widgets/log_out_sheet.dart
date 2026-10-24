import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../theme/colors.dart';
import 'mascot.dart';

/// "Log out?" with the person's own Jack or Jill waving goodbye. Signing out takes them to Welcome.
Future<void> confirmLogOut(BuildContext context, {required AuthService auth, String? cherry, bool midOnboarding = false}) async {
  final wingman = Wingman(cherry);
  final sure = await showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    backgroundColor: BakeColors.warmCream,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (context) {
      final text = Theme.of(context).textTheme;
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Mascot(wingman.goodbye, size: 130)),
            Text('Log out of BakeOut?', textAlign: TextAlign.center, style: text.headlineSmall),
            const SizedBox(height: 6),
            Text(
              midOnboarding
                  ? 'Your answers are saved. Log back in with your email and you’ll pick up right where you left off.'
                  : 'Your profile, matches, and chats stay safe. ${wingman.name} will be here when you log back in.',
              textAlign: TextAlign.center,
              style: text.bodyLarge?.copyWith(color: BakeColors.muted),
            ),
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('confirm-logout'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Log out'),
            ),
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Stay logged in')),
          ],
        ),
      );
    },
  );
  if (sure != true) return;
  HapticFeedback.lightImpact();
  await auth.signOut();
}

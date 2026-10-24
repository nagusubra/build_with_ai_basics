import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../services/auth_service.dart';
import '../../theme/colors.dart';
import '../../widgets/mascot.dart';
import '../../widgets/mascot_rive.dart';
import '../auth/auth_screen.dart';

/// First screen: the cherries, one clear message, one button (`prd.md > Welcome Screen`).
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.auth});

  final AuthService auth;

  void _open(BuildContext context, {required bool logIn}) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => AuthScreen(auth: auth, startWithLogIn: logIn)),
      );

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 12, 28, 20),
          child: Column(
            children: [
              const Spacer(),
              const AnimatedMascot(
                MascotPose.duoWelcome,
                size: 290,
                animationAsset: MascotMotion.welcomeAsset,
                posterAsset: MascotMotion.welcomePosterAsset,
              )
                  .animate()
                  .fadeIn(duration: 500.ms)
                  .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1), curve: Curves.easeOutBack),
              const SizedBox(height: 18),
              Text('Love might just be one recipe away.', textAlign: TextAlign.center, style: text.displaySmall?.copyWith(fontSize: 32))
                  .animate()
                  .fadeIn(delay: 200.ms, duration: 400.ms)
                  .moveY(begin: 10, end: 0),
              const SizedBox(height: 12),
              Text(
                'Meet people who share your love for food, skip the awkward small talk, and cook up something special together.',
                textAlign: TextAlign.center,
                style: text.bodyLarge?.copyWith(color: BakeColors.muted),
              ).animate().fadeIn(delay: 350.ms, duration: 400.ms),
              const Spacer(),
              FilledButton(
                key: const Key('welcome-start'),
                onPressed: () => _open(context, logIn: false),
                child: const Text("Let's BakeOut"),
              ).animate().fadeIn(delay: 500.ms),
              TextButton(
                key: const Key('welcome-login'),
                onPressed: () => _open(context, logIn: true),
                child: const Text('Already have an account? Log in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

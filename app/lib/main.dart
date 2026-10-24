import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'models/profile.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding_flow.dart';
import 'screens/welcome/welcome_screen.dart';
import 'services/auth_service.dart';
import 'services/chat_service.dart';
import 'services/discover_service.dart';
import 'services/functions_service.dart';
import 'services/profile_service.dart';
import 'theme/colors.dart';
import 'theme/theme.dart';
import 'widgets/mascot.dart';
import 'widgets/mascot_rive.dart';
import 'widgets/startup_gate.dart';

/// `flutter run --dart-define=USE_EMULATORS=true` talks to the local Firebase emulators.
const useEmulators = bool.fromEnvironment('USE_EMULATORS');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BakeOutApp());
}

Future<void> initFirebase() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (useEmulators) {
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
    FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
    await FirebaseStorage.instance.useStorageEmulator('localhost', 9199);
  }
  await AuthService().dropStaleSession();
}

class BakeOutApp extends StatelessWidget {
  const BakeOutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BakeOut',
      debugShowCheckedModeBanner: false,
      theme: buildBakeTheme(),
      home: StartupGate(
        initialize: () async {
          await Future.wait([initFirebase(), MascotMotion.init()]);
        },
        buildDestination: (onReady) => AuthGate(
          auth: AuthService(),
          chat: ChatService(),
          functions: FunctionsService(),
          profiles: ProfileService(),
          discover: DiscoverService(),
          onReady: onReady,
        ),
      ),
    );
  }
}

class _ProfileLoadError extends StatelessWidget {
  const _ProfileLoadError({required this.auth, required this.onRetry});

  final AuthService auth;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Mascot(MascotPose.boyTryAgain, size: 170),
              Text(
                "We couldn't load your profile",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Check your connection, then try again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: BakeColors.muted),
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
              TextButton(
                key: const Key('profile-error-signout'),
                onPressed: auth.signOut,
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Signed out → Welcome. Signed in → the next unfinished onboarding step, then the app.
class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    required this.auth,
    required this.chat,
    required this.functions,
    required this.profiles,
    required this.discover,
    this.onReady,
  });

  final AuthService auth;
  final ChatService chat;
  final FunctionsService functions;
  final ProfileService profiles;
  final DiscoverService discover;
  final VoidCallback? onReady;

  static const _loading = Scaffold(body: CherryLoading());

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: auth.changes,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return _loading;
        final user = snap.data;
        if (user == null) {
          return _DestinationReady(
            onReady: onReady,
            child: WelcomeScreen(auth: auth),
          );
        }
        return _SignedIn(key: ValueKey(user.uid), uid: user.uid, gate: this);
      },
    );
  }
}

class _DestinationReady extends StatefulWidget {
  const _DestinationReady({required this.onReady, required this.child});

  final VoidCallback? onReady;
  final Widget child;

  @override
  State<_DestinationReady> createState() => _DestinationReadyState();
}

class _DestinationReadyState extends State<_DestinationReady> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onReady?.call();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _SignedIn extends StatefulWidget {
  const _SignedIn({super.key, required this.uid, required this.gate});

  final String uid;
  final AuthGate gate;

  @override
  State<_SignedIn> createState() => _SignedInState();
}

class _SignedInState extends State<_SignedIn> {
  late Stream<UserProfile> _profile = widget.gate.profiles.profile(widget.uid);

  @override
  Widget build(BuildContext context) {
    final g = widget.gate;
    return StreamBuilder<UserProfile>(
      stream: _profile,
      builder: (context, snap) {
        if (snap.hasError) {
          return _DestinationReady(
            onReady: g.onReady,
            child: _ProfileLoadError(
              auth: g.auth,
              onRetry: () =>
                  setState(() => _profile = g.profiles.profile(widget.uid)),
            ),
          );
        }
        final profile = snap.data;
        if (profile == null) return AuthGate._loading;
        if (nextStep(profile) != OnboardingStep.done) {
          return _DestinationReady(
            onReady: g.onReady,
            child: OnboardingFlow(profile: profile, profiles: g.profiles),
          );
        }
        return _DestinationReady(
          onReady: g.onReady,
          child: HomeShell(
            me: profile,
            auth: g.auth,
            chat: g.chat,
            functions: g.functions,
            profiles: g.profiles,
            discover: g.discover,
          ),
        );
      },
    );
  }
}

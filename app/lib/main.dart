import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'models/profile.dart';
import 'screens/chat/chat_list_screen.dart';
import 'screens/onboarding_flow.dart';
import 'screens/welcome/welcome_screen.dart';
import 'services/auth_service.dart';
import 'services/chat_service.dart';
import 'services/functions_service.dart';
import 'services/profile_service.dart';
import 'theme/colors.dart';
import 'theme/theme.dart';

/// `flutter run --dart-define=USE_EMULATORS=true` talks to the local Firebase emulators.
const useEmulators = bool.fromEnvironment('USE_EMULATORS');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initFirebase();
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
}

class BakeOutApp extends StatelessWidget {
  const BakeOutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BakeOut',
      debugShowCheckedModeBanner: false,
      theme: buildBakeTheme(),
      home: AuthGate(
        auth: AuthService(),
        chat: ChatService(),
        functions: FunctionsService(),
        profiles: ProfileService(),
      ),
    );
  }
}

/// Signed out → Welcome. Signed in → the next unfinished onboarding step, then the app.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.auth, required this.chat, required this.functions, required this.profiles});

  final AuthService auth;
  final ChatService chat;
  final FunctionsService functions;
  final ProfileService profiles;

  static const _loading = Scaffold(body: Center(child: CircularProgressIndicator(color: BakeColors.cherryRed)));

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: auth.changes,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return _loading;
        final user = snap.data;
        if (user == null) return WelcomeScreen(auth: auth);
        return StreamBuilder<UserProfile>(
          key: ValueKey(user.uid),
          stream: profiles.profile(user.uid),
          builder: (context, profileSnap) {
            final profile = profileSnap.data;
            if (profile == null) return _loading;
            if (nextStep(profile) != OnboardingStep.done) {
              return OnboardingFlow(profile: profile, profiles: profiles);
            }
            return ChatListScreen(auth: auth, chat: chat, functions: functions, myUid: user.uid);
          },
        );
      },
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/chat/chat_list_screen.dart';
import 'services/auth_service.dart';
import 'services/chat_service.dart';
import 'services/functions_service.dart';
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
      home: AuthGate(auth: AuthService(), chat: ChatService(), functions: FunctionsService()),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.auth, required this.chat, required this.functions});

  final AuthService auth;
  final ChatService chat;
  final FunctionsService functions;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: auth.changes,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator(color: BakeColors.cherryRed)));
        }
        final user = snap.data;
        if (user == null) return AuthScreen(auth: auth);
        return ChatListScreen(auth: auth, chat: chat, functions: functions, myUid: user.uid);
      },
    );
  }
}

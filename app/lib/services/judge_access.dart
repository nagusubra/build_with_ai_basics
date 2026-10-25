import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';

import 'auth_service.dart';

/// A ready-made demo profile a judge can log straight into (`functions/scripts/judge-demo.mjs`).
class JudgeAccount {
  const JudgeAccount({
    required this.email,
    required this.name,
    required this.cherry,
    required this.summary,
  });

  final String email;
  final String name;

  /// "boy" (Jack) or "girl" (Jill).
  final String cherry;

  /// What's waiting for the judge inside, in a few words.
  final String summary;
}

/// Hackathon shortcuts on the web, so judges never have to invent an email: log into a ready-made
/// profile, or start a brand-new one from scratch. Build with `--dart-define=JUDGE_ACCESS=false`
/// to hide them.
abstract final class JudgeAccess {
  static const enabled =
      kIsWeb && bool.fromEnvironment('JUDGE_ACCESS', defaultValue: true);

  /// Shared with the seed script; these accounts hold sample data only.
  static const _password = 'BakeOut-judge-2026';
  static const _freshDomain = 'judge.bakeout.demo';

  static const readyMade = [
    JudgeAccount(
      email: 'maya@bakeout.demo',
      name: 'Maya',
      cherry: 'girl',
      summary: 'Matched with Arjun, and Daniel liked her',
    ),
    JudgeAccount(
      email: 'arjun@bakeout.demo',
      name: 'Arjun',
      cherry: 'boy',
      summary: 'Matched with Maya, and Sofia liked him',
    ),
  ];

  /// The app's navigator, so the judge panel beside the phone can close open screens first.
  static final navigatorKey = GlobalKey<NavigatorState>();

  /// Firebase is ready; the panel's buttons wait for it.
  static final ready = ValueNotifier(false);

  static bool _tourRequested = false;

  /// Each judge who opens a ready-made profile gets the first-time tour, even if an earlier judge
  /// finished it. Read once by the home screen.
  static bool takeTourRequest() {
    final requested = _tourRequested;
    _tourRequested = false;
    return requested;
  }

  static JudgeAccount? readyMadeFor(String? email) {
    for (final a in readyMade) {
      if (a.email == email) return a;
    }
    return null;
  }

  static bool isFreshJudge(String? email) =>
      email?.endsWith('@$_freshDomain') ?? false;

  static bool get inFreshJudgeAccount =>
      enabled && isFreshJudge(FirebaseAuth.instance.currentUser?.email);

  static Future<void> logInAs(JudgeAccount account, AuthService auth) async {
    await _leaveCurrentAccount(auth);
    _tourRequested = true;
    try {
      await auth.logIn(email: account.email, password: _password);
    } catch (_) {
      _tourRequested = false;
      rethrow;
    }
  }

  /// A throwaway account, so the judge goes through sign-up from the very first question.
  static Future<void> startFresh(
    AuthService auth, {
    FirebaseFirestore? db,
  }) async {
    await _leaveCurrentAccount(auth);
    final random = Random.secure();
    String token(int length) => List.generate(
      length,
      (_) => 'abcdefghijkmnpqrstuvwxyz23456789'[random.nextInt(32)],
    ).join();
    await auth.signUp(
      email: 'judge-${token(8)}@$_freshDomain',
      password: token(20),
    );
    final uid = auth.currentUser?.uid;
    if (uid != null) {
      await (db ?? FirebaseFirestore.instance).doc('users/$uid').set({
        'judge': true,
      }, SetOptions(merge: true));
    }
  }

  static Future<void> signOut(AuthService auth) => _leaveCurrentAccount(auth);

  static Future<void> _leaveCurrentAccount(AuthService auth) async {
    navigatorKey.currentState?.popUntil((route) => route.isFirst);
    if (auth.currentUser != null) await auth.signOut();
  }
}

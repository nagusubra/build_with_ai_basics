import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? db})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  Stream<User?> get changes => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  /// Creates the account; the basics form fills in the profile next.
  Future<void> signUp({required String email, required String password}) async {
    final credential = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
    final uid = credential.user!.uid;
    await _db.doc('users/$uid').set({'createdAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    await _db.doc('users/$uid/private/account').set({'email': email.trim()}, SetOptions(merge: true));
  }

  Future<void> logIn({required String email, required String password}) =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password);

  Future<void> signOut() => _auth.signOut();

  /// Signs out a saved session whose account no longer exists (deleted, or from another
  /// backend). Network trouble is ignored — the session may be fine.
  Future<void> dropStaleSession() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await user.reload();
    } on FirebaseAuthException catch (e) {
      const stale = {'user-not-found', 'user-disabled', 'user-token-expired', 'invalid-user-token'};
      if (stale.contains(e.code)) await _auth.signOut();
    }
  }
}

/// Turns Firebase's error codes into something a person can act on.
String friendlyAuthError(Object error) {
  if (error is! FirebaseAuthException) return 'Something went wrong. Please try again.';
  return switch (error.code) {
    'invalid-email' => "That email address doesn't look right.",
    'email-already-in-use' => 'There is already an account with that email. Try logging in.',
    'weak-password' => 'Pick a password with at least 6 characters.',
    'invalid-credential' || 'wrong-password' || 'user-not-found' => "That email and password don't match.",
    'network-request-failed' => "You're offline. Check your connection and try again.",
    _ => 'Something went wrong (${error.code}). Please try again.',
  };
}

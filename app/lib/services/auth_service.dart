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

  Future<void> signUp({required String name, required String email, required String password}) async {
    final credential = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
    final uid = credential.user!.uid;
    await _db.doc('users/$uid').set({'name': name.trim(), 'createdAt': FieldValue.serverTimestamp()});
    await _db.doc('users/$uid/private/account').set({'email': email.trim()});
  }

  Future<void> logIn({required String email, required String password}) =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password);

  Future<void> signOut() => _auth.signOut();
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

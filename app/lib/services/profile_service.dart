import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/profile.dart';

/// Reads and writes `users/{uid}`, its private details, and profile photos.
class ProfileService {
  ProfileService({FirebaseFirestore? db, FirebaseStorage? storage})
      : _db = db ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;
  final _urls = <String, Future<String>>{};

  DocumentReference<Map<String, dynamic>> _user(String uid) => _db.doc('users/$uid');

  Stream<UserProfile> profile(String uid) => _user(uid).snapshots().map((d) => UserProfile.fromMap(uid, d.data()));

  Future<UserProfile> load(String uid) async => UserProfile.fromMap(uid, (await _user(uid).get()).data());

  /// Sign-up basics. The exact birthday stays private; others only ever see the age.
  Future<void> saveBasics({
    required String uid,
    required String name,
    required DateTime dateOfBirth,
    required String gender,
    required List<String> interestedIn,
    required String city,
    required String lookingFor,
    String? keepCherry,
  }) async {
    final age = ageOn(dateOfBirth, DateTime.now());
    if (age < minimumAge) throw ArgumentError('BakeOut is for people aged 18 and over.');
    await _user(uid).set({
      'name': name.trim(),
      'age': age,
      'gender': gender,
      'interestedIn': interestedIn,
      'city': city.trim(),
      'lookingFor': lookingFor,
      'cherryAvatar': keepCherry ?? cherryForGender(gender, coinFlip: Random().nextBool()),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _user(uid).collection('private').doc('account').set({
      'dateOfBirth': Timestamp.fromDate(DateTime(dateOfBirth.year, dateOfBirth.month, dateOfBirth.day)),
    }, SetOptions(merge: true));
  }

  Future<DateTime?> dateOfBirth(String uid) async {
    final v = (await _user(uid).collection('private').doc('account').get()).data()?['dateOfBirth'];
    return v is Timestamp ? v.toDate() : null;
  }

  /// Saves one quiz answer as soon as it's given, so nothing is lost if the app closes.
  Future<void> saveFoodAnswer(String uid, String field, Object? value) =>
      _user(uid).set({'food': {field: value ?? FieldValue.delete()}}, SetOptions(merge: true));

  Future<void> savePrompts(String uid, Map<String, String> prompts) {
    final kept = {for (final e in prompts.entries) if (e.value.trim().isNotEmpty) e.key: e.value.trim()};
    return _user(uid).update({'prompts': kept});
  }

  Future<void> markQuizDone(String uid) => _user(uid).update({'quizDone': true});

  /// Uploads profile photos in order (first = main) and replaces the list on the profile.
  Future<List<String>> uploadPhotos(String uid, List<File> files) async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final paths = <String>[];
    for (var i = 0; i < files.length; i++) {
      final path = 'users/$uid/photos/${stamp}_$i.jpg';
      await _storage.ref(path).putFile(files[i], SettableMetadata(contentType: 'image/jpeg'));
      paths.add(path);
    }
    final old = (await load(uid)).photos;
    await _user(uid).update({'photos': paths});
    for (final p in old.where((p) => !paths.contains(p))) {
      await _storage.ref(p).delete().catchError((_) {});
    }
    return paths;
  }

  Future<String> photoUrl(String path) => _urls[path] ??= _storage.ref(path).getDownloadURL();

  /// The main photo as a local file, for comparing with the selfie on the phone.
  Future<File> downloadPhoto(String path) async {
    final file = File('${Directory.systemTemp.path}/bakeout_main_${path.hashCode}.jpg');
    await _storage.ref(path).writeToFile(file);
    return file;
  }

  Future<void> markVerified(String uid) =>
      _user(uid).update({'verified': true, 'verifiedAt': FieldValue.serverTimestamp()});

  Future<void> markPreviewSeen(String uid) => _user(uid).update({'previewSeen': true});

  Future<void> completeOnboarding(String uid) => _user(uid).update({'onboardingComplete': true});
}

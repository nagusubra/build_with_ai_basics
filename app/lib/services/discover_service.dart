import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/profile.dart';

/// Whether [person] is someone [seeker] said they'd like to meet.
bool wantsToMeet(UserProfile seeker, UserProfile person) {
  final wants = seeker.interestedIn;
  if (wants.contains('Everyone')) return true;
  return (wants.contains('Men') && person.gender == 'Man') || (wants.contains('Women') && person.gender == 'Woman');
}

/// Two people can see each other in Discover: same goal, and each fits who the other wants to meet.
bool compatible(UserProfile me, UserProfile them) =>
    me.uid != them.uid && me.lookingFor != null && me.lookingFor == them.lookingFor && wantsToMeet(me, them) && wantsToMeet(them, me);

/// One real thing two food profiles share, for the Discover card (`prd.md > Discover`).
String? somethingInCommon(UserProfile me, UserProfile them) {
  Set<String> lower(List<String> xs) => xs.map((x) => x.toLowerCase()).toSet();
  String? firstShared(List<String> a, List<String> b) {
    final theirs = lower(b);
    for (final x in a) {
      if (theirs.contains(x.toLowerCase())) return x;
    }
    return null;
  }

  final top = firstShared(me.foodList('topCuisines'), them.foodList('topCuisines'));
  if (top != null) return 'You both love $top food!';
  final cuisine = firstShared(me.foodList('cuisines'), them.foodList('cuisines'));
  if (cuisine != null) return 'You both enjoy $cuisine food!';
  final diet = me.foodText('foodType');
  if (diet != null && diet != 'Other' && diet == them.foodText('foodType')) {
    return diet == 'I eat pretty much everything' ? 'You both eat pretty much everything!' : "You're both ${diet.toLowerCase()}!";
  }
  final date = me.foodText('idealDate');
  if (date != null && date == them.foodText('idealDate')) return 'Same ideal date: ${date.toLowerCase()}';
  final style = firstShared(me.foodList('cookingPersonality'), them.foodList('cookingPersonality'));
  if (style != null) return 'Two of a kind: ${style.toLowerCase()}s';
  final music = firstShared(me.foodList('musicGenres'), them.foodList('musicGenres'));
  if (music != null) return 'You both cook to $music';
  return null;
}

/// Someone liked me and is waiting for a like back (`users/{me}/likedBy/{from}`).
class LikeNotice {
  const LikeNotice({required this.from, required this.seen});

  final String from;

  /// The banner has already been shown for it.
  final bool seen;
}

/// A like is still worth answering: they're still around, verified, and looking for the same thing.
bool canLikeBack(UserProfile me, UserProfile them) => them.onboardingComplete && them.verified && compatible(me, them);

/// Discover: the people to show, and likes and passes.
class DiscoverService {
  DiscoverService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// Verified, onboarded people with the same goal whom I haven't liked, passed, or matched,
  /// and who get through my filters.
  Future<List<UserProfile>> candidates(UserProfile me) async {
    final results = await Future.wait([
      _db
          .collection('users')
          .where('lookingFor', isEqualTo: me.lookingFor)
          .where('onboardingComplete', isEqualTo: true)
          .where('verified', isEqualTo: true)
          .get(),
      _db.collection('likes').where('from', isEqualTo: me.uid).get(),
      _db.collection('users/${me.uid}/passes').get(),
      _db.collection('matches').where('users', arrayContains: me.uid).get(),
    ]);
    final seen = <String>{
      ...results[1].docs.map((d) => d.data()['to'] as String),
      ...results[2].docs.map((d) => d.id),
      for (final m in results[3].docs) ...List<String>.from(m.data()['users'] as List),
    };
    return results[0]
        .docs
        .map((d) => UserProfile.fromMap(d.id, d.data()))
        .where((p) => !seen.contains(p.uid) && compatible(me, p) && passesFilters(me.filters, p))
        .toList();
  }

  Future<void> like(String me, String them) => _db.doc('likes/${me}_$them').set({
        'from': me,
        'to': them,
        'createdAt': FieldValue.serverTimestamp(),
      });

  Future<void> pass(String me, String them) =>
      _db.doc('users/$me/passes/$them').set({'createdAt': FieldValue.serverTimestamp()});

  /// People who liked me and haven't been answered, newest first.
  Stream<List<LikeNotice>> likedMe(String me) => _db
      .collection('users/$me/likedBy')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => [for (final d in s.docs) LikeNotice(from: d.id, seen: d.data()['seenAt'] != null)]);

  Future<void> markLikeSeen(String me, String from) =>
      _db.doc('users/$me/likedBy/$from').update({'seenAt': FieldValue.serverTimestamp()});

  /// Passing on someone who liked me also clears their notice.
  Future<void> passOnLiker(String me, String them) async {
    await pass(me, them);
    await _db.doc('users/$me/likedBy/$them').delete();
  }
}

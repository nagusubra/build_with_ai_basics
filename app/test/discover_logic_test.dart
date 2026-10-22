import 'package:bakeout/models/profile.dart';
import 'package:bakeout/services/discover_service.dart';
import 'package:flutter_test/flutter_test.dart';

UserProfile _p(String uid, {String gender = 'Woman', List<String> meet = const ['Men'], String lookingFor = 'partner', Map<String, dynamic> food = const {}}) =>
    UserProfile.fromMap(uid, {'gender': gender, 'interestedIn': meet, 'lookingFor': lookingFor, 'food': food});

void _likeBackTests() {
  group('like back', () {
    UserProfile person(String uid, {bool verified = true, bool done = true, String goal = 'partner', String gender = 'Woman'}) =>
        UserProfile.fromMap(uid, {
          'gender': gender,
          'interestedIn': ['Everyone'],
          'lookingFor': goal,
          'verified': verified,
          'onboardingComplete': done,
        });
    final me = person('me', gender: 'Man');

    test('a verified, onboarded liker with the same goal can be liked back', () {
      expect(canLikeBack(me, person('a')), isTrue);
    });

    test('not if they switched goal, lost their verified badge, or never finished', () {
      expect(canLikeBack(me, person('a', goal: 'friends')), isFalse);
      expect(canLikeBack(me, person('a', verified: false)), isFalse);
      expect(canLikeBack(me, person('a', done: false)), isFalse);
    });
  });
}

void main() {
  _likeBackTests();
  group('who appears in Discover', () {
    final ana = _p('ana', gender: 'Woman', meet: ['Men']);
    final ben = _p('ben', gender: 'Man', meet: ['Women']);

    test('two people who want to meet each other, with the same goal', () {
      expect(compatible(ana, ben), isTrue);
      expect(compatible(ben, ana), isTrue);
    });

    test('a friend-seeker never sees a partner-seeker, and the reverse', () {
      final friendBen = _p('ben2', gender: 'Man', meet: ['Women'], lookingFor: 'friends');
      expect(compatible(ana, friendBen), isFalse);
      expect(compatible(friendBen, ana), isFalse);
    });

    test('both sides have to want to meet the other', () {
      final cal = _p('cal', gender: 'Man', meet: ['Men']);
      expect(compatible(ana, cal), isFalse, reason: 'Cal only wants to meet men');
    });

    test('"Everyone" includes non-binary people; "Men" or "Women" alone does not', () {
      final sky = _p('sky', gender: 'Non-binary', meet: ['Everyone']);
      final dee = _p('dee', gender: 'Woman', meet: ['Everyone']);
      expect(compatible(dee, sky), isTrue);
      expect(compatible(ana, sky), isFalse);
    });

    test('never yourself', () => expect(compatible(ana, ana), isFalse));
  });

  group('something in common', () {
    test('prefers a shared top cuisine, matched case-insensitively', () {
      final a = _p('a', food: {'topCuisines': ['Thai', 'Italian'], 'foodType': 'Vegan'});
      final b = _p('b', food: {'topCuisines': ['italian'], 'foodType': 'Vegan'});
      expect(somethingInCommon(a, b), 'You both love Italian food!');
    });

    test('falls back through diet, ideal date, style, and music', () {
      expect(somethingInCommon(_p('a', food: {'foodType': 'Vegetarian'}), _p('b', food: {'foodType': 'Vegetarian'})), "You're both vegetarian!");
      expect(
        somethingInCommon(_p('a', food: {'musicGenres': ['Jazz']}), _p('b', food: {'musicGenres': ['Rock', 'Jazz']})),
        'You both cook to Jazz',
      );
    });

    test('says nothing rather than inventing a connection', () {
      expect(somethingInCommon(_p('a', food: {'cuisines': ['Thai']}), _p('b', food: {'cuisines': ['French']})), isNull);
    });
  });
}

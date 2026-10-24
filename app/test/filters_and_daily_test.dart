import 'package:bakeout/data/cities.dart';
import 'package:bakeout/data/daily.dart';
import 'package:bakeout/models/profile.dart';
import 'package:bakeout/screens/quiz/questions.dart';
import 'package:bakeout/widgets/mascot.dart';
import 'package:flutter_test/flutter_test.dart';

UserProfile _person({int? age = 28, String? city = 'Edinburgh, UK', String? diet = 'Vegan'}) =>
    UserProfile.fromMap('x', {'age': age, 'city': city, 'food': {'foodType': diet}});

void main() {
  group('Discover filters', () {
    test('no filters lets everyone through', () {
      expect(passesFilters(const DiscoverFilters(), _person()), isTrue);
      expect(const DiscoverFilters().activeCount, 0);
    });

    test('food preference keeps only the chosen diets', () {
      const f = DiscoverFilters(foodTypes: ['Vegan', 'Vegetarian']);
      expect(passesFilters(f, _person(diet: 'Vegan')), isTrue);
      expect(passesFilters(f, _person(diet: 'Non-vegetarian')), isFalse);
      expect(passesFilters(f, _person(diet: null)), isFalse);
    });

    test('age range is inclusive, and the top of the slider means "and older"', () {
      const f = DiscoverFilters(minAge: 25, maxAge: 30);
      expect(passesFilters(f, _person(age: 25)), isTrue);
      expect(passesFilters(f, _person(age: 30)), isTrue);
      expect(passesFilters(f, _person(age: 24)), isFalse);
      expect(passesFilters(f, _person(age: 31)), isFalse);
      const open = DiscoverFilters(minAge: 40, maxAge: DiscoverFilters.ageCeiling);
      expect(passesFilters(open, _person(age: 88)), isTrue);
    });

    test('cities match exactly, so London UK and London Canada stay apart', () {
      const f = DiscoverFilters(cities: ['London, UK']);
      expect(passesFilters(f, _person(city: 'London, UK')), isTrue);
      expect(passesFilters(f, _person(city: 'London, Canada')), isFalse);
      expect(passesFilters(f, _person(city: null)), isFalse);
    });

    test('"verified only" hides people who skipped the selfie check', () {
      const f = DiscoverFilters(verifiedOnly: true);
      expect(passesFilters(f, UserProfile.fromMap('x', {'verified': true})), isTrue);
      expect(passesFilters(f, UserProfile.fromMap('x', {'verificationSkipped': true})), isFalse);
      expect(passesFilters(const DiscoverFilters(), UserProfile.fromMap('x', {'verificationSkipped': true})), isTrue);
    });

    test('saved filters round-trip and count what is on', () {
      const f = DiscoverFilters(foodTypes: ['Vegan'], minAge: 21, maxAge: 35, cities: ['Glasgow, UK'], verifiedOnly: true);
      final back = DiscoverFilters.fromMap(f.toMap());
      expect(back.signature, f.signature);
      expect(back.activeCount, 4);
      expect(UserProfile.fromMap('u', {'filters': f.toMap()}).filters.cities, ['Glasgow, UK']);
    });
  });

  group('cities', () {
    test('the list is unique and includes home turf', () {
      expect(cities.toSet().length, cities.length);
      expect(cities, containsAll(['Edinburgh, UK', 'Glasgow, UK', 'Calgary, Canada', 'Edmonton, Canada']));
    });

    test('search finds by name or country, name matches first', () {
      expect(searchCities('glas').first, 'Glasgow, UK');
      expect(searchCities('canada'), contains('Calgary, Canada'));
      expect(searchCities('lon').take(2), containsAll(['London, UK', 'London, Canada']));
      expect(searchCities(''), cities);
    });
  });

  group('daily touches', () {
    test('greeting fits the time of day and keeps one line all day', () {
      final morning = dailyGreeting('Priya', DateTime(2026, 10, 22, 8));
      final evening = dailyGreeting('Priya', DateTime(2026, 10, 22, 19));
      expect(morning.hello, 'Good morning, Priya!');
      expect(evening.hello, 'Good evening, Priya!');
      expect(morning.line, evening.line);
      expect(dailyGreeting('Priya', DateTime(2026, 10, 23, 8)).line, isNot(morning.line));
      expect(dailyGreeting(null, DateTime(2026, 10, 22, 2)).hello, 'Up late!');
    });

    test('Jack is the boy cherry and Jill the girl', () {
      expect(const Wingman('boy').name, 'Jack');
      expect(const Wingman('girl').name, 'Jill');
      expect(const Wingman(null).name, 'Jack');
      expect(const Wingman('girl').goodbye, MascotPose.girlGoodbye);
    });

    test('cards show the quiz emoji for diets and cuisines', () {
      expect(emojiFor('Vegan'), '🌿');
      expect(emojiFor('italian'), '🍝');
      expect(emojiFor('Not a cuisine'), isNull);
    });
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:bakeout/models/profile.dart';
import 'package:bakeout/models/recipe.dart';
import 'package:bakeout/services/recipe_library.dart';
import 'package:flutter_test/flutter_test.dart';

UserProfile _p(Map<String, dynamic> food) => UserProfile.fromMap('u1', {'food': food});

Recipe _r(String id, {String diet = 'vegan', List<String> allergens = const [], String cuisine = 'Thai', int minutes = 20}) =>
    Recipe(id: id, title: id, cuisine: cuisine, minutes: minutes, blurb: '', ingredients: const [], steps: const [], diet: diet, allergens: allergens);

void main() {
  group('who can eat what', () {
    test('diets nest: vegans get vegan, vegetarians add vegetarian, pescatarians add fish', () {
      final vegan = _p({'foodType': 'Vegan'});
      final veggie = _p({'foodType': 'Vegetarian'});
      final pesc = _p({'foodType': 'Pescatarian'});
      final omni = _p({'foodType': 'I eat pretty much everything'});
      expect(canEat(vegan, _r('a', diet: 'vegetarian')), isFalse);
      expect(canEat(veggie, _r('a', diet: 'vegetarian')), isTrue);
      expect(canEat(veggie, _r('a', diet: 'pescatarian')), isFalse);
      expect(canEat(pesc, _r('a', diet: 'pescatarian')), isTrue);
      expect(canEat(pesc, _r('a', diet: 'meat')), isFalse);
      expect(canEat(omni, _r('a', diet: 'meat')), isTrue);
    });

    test('unclear diets stay vegetarian-safe', () {
      expect(canEat(_p({'foodType': 'Other', 'foodTypeOther': 'Jain'}), _r('a', diet: 'pescatarian')), isFalse);
      expect(canEat(_p(const {}), _r('a', diet: 'meat')), isFalse);
    });

    test('restrictions rule out their allergens; halal rules out pork and alcohol', () {
      final nutFree = _p({'foodType': 'Vegan', 'restrictions': ['Nut allergy']});
      expect(canEat(nutFree, _r('a', allergens: ['nuts'])), isFalse);
      expect(canEat(nutFree, _r('a', allergens: ['soy'])), isTrue);
      final halal = _p({'foodType': 'Non-vegetarian', 'restrictions': ['Halal']});
      expect(canEat(halal, _r('a', diet: 'meat', allergens: ['alcohol'])), isFalse);
      expect(canEat(halal, _r('a', diet: 'meat', allergens: ['pork'])), isFalse);
    });
  });

  group('picking', () {
    final lib = RecipeLibrary([
      _r('thai-quick', cuisine: 'Thai', minutes: 15),
      _r('thai-slow', cuisine: 'Thai', minutes: 80),
      _r('italian', cuisine: 'Italian', minutes: 20),
      _r('french', cuisine: 'French', minutes: 20),
      _r('nutty', cuisine: 'Thai', allergens: ['nuts']),
    ]);
    final me = _p({'foodType': 'Vegan', 'restrictions': ['Nut allergy'], 'topCuisines': ['Thai'], 'cuisines': ['Thai', 'Italian'], 'cookingTime': 'Around 30 minutes'});

    test('top cuisines first, quick ones before slow, never something they can’t eat', () {
      final ids = lib.suitableFor(me, day: DateTime(2026, 10, 22)).map((r) => r.id).toList();
      expect(ids.first, 'thai-quick');
      expect(ids.indexOf('thai-slow'), lessThan(ids.indexOf('italian')));
      expect(ids.indexOf('italian'), lessThan(ids.indexOf('french')));
      expect(ids, isNot(contains('nutty')));
    });

    test('"New ideas" pages through the set', () {
      final first = lib.selection(me, size: 2, day: DateTime(2026, 10, 22)).map((r) => r.id).toList();
      final second = lib.selection(me, page: 1, size: 2, day: DateTime(2026, 10, 22)).map((r) => r.id).toList();
      expect(first, isNot(equals(second)));
    });

    test('Dish of the Day is stable within a day and something they can eat', () {
      final a = lib.dishOfTheDay(me, day: DateTime(2026, 10, 22, 8));
      final b = lib.dishOfTheDay(me, day: DateTime(2026, 10, 22, 21));
      expect(a!.id, b!.id);
      expect(canEat(me, a), isTrue);
    });
  });

  test('the bundled library is well-formed and serves every diet with a nut allergy', () {
    final raw = jsonDecode(File('assets/recipes/library.json').readAsStringSync()) as Map<String, dynamic>;
    final lib = RecipeLibrary([for (final r in raw['recipes'] as List) Recipe.fromMap((r as Map).cast<String, dynamic>())]);
    expect(lib.recipes.length, greaterThanOrEqualTo(40));
    expect(lib.recipes.map((r) => r.id).toSet().length, lib.recipes.length, reason: 'ids are unique');
    for (final r in lib.recipes) {
      expect(r.ingredients, isNotEmpty, reason: r.title);
      expect(r.steps, isNotEmpty, reason: r.title);
      expect(['vegan', 'vegetarian', 'pescatarian', 'meat'], contains(r.diet), reason: r.title);
    }
    for (final diet in ['Vegan', 'Vegetarian', 'Pescatarian', 'Non-vegetarian']) {
      final someone = _p({'foodType': diet, 'restrictions': ['Nut allergy']});
      expect(lib.suitableFor(someone).length, greaterThanOrEqualTo(6), reason: '$diet with a nut allergy');
    }
  });
}

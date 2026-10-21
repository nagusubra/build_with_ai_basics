import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/profile.dart';
import '../models/recipe.dart';

const _dietRank = {'vegan': 0, 'vegetarian': 1, 'pescatarian': 2, 'meat': 3};

/// The most permissive recipe diet a person eats, from their quiz answer.
/// Anything unclear ("Other", unanswered) stays vegetarian-safe.
int _maxDietFor(String? foodType) => switch (foodType) {
      'Vegan' => 0,
      'Vegetarian' => 1,
      'Pescatarian' => 2,
      'Non-vegetarian' || 'I eat pretty much everything' => 3,
      _ => 1,
    };

/// Allergen tags each quiz restriction rules out.
const _blockedBy = {
  'Nut allergy': ['nuts'],
  'Gluten-free': ['gluten'],
  'Dairy-free': ['dairy'],
  'Egg allergy': ['egg'],
  'Shellfish allergy': ['shellfish'],
  'Soy allergy': ['soy'],
  'Halal': ['pork', 'alcohol'],
  'Kosher': ['pork', 'shellfish'],
  'No onion or garlic': ['onion_garlic'],
};

/// Whether this person can eat this recipe as written.
bool canEat(UserProfile p, Recipe r) {
  if ((_dietRank[r.diet] ?? 3) > _maxDietFor(p.foodText('foodType'))) return false;
  final blocked = p.foodList('restrictions').expand((x) => _blockedBy[x] ?? const <String>[]).toSet();
  return !r.allergens.any(blocked.contains);
}

int _maxMinutesFor(String? cookingTime) => switch (cookingTime) {
      '15 minutes or less' => 20,
      'Around 30 minutes' => 35,
      'Around an hour' => 70,
      _ => 1 << 20,
    };

/// Higher is better: their top cuisines, then other cuisines they like, then fitting their time.
int _score(UserProfile p, Recipe r) {
  final top = p.foodList('topCuisines');
  final liked = p.foodList('cuisines');
  return (top.contains(r.cuisine) ? 4 : 0) +
      (liked.contains(r.cuisine) ? 2 : 0) +
      (r.minutes <= _maxMinutesFor(p.foodText('cookingTime')) ? 1 : 0);
}

int _stableHash(String s) => s.codeUnits.fold(17, (h, c) => (h * 31 + c) & 0x7fffffff);

/// BakeOut's bundled recipes (`assets/recipes/library.json`), picked per person without the AI.
class RecipeLibrary {
  RecipeLibrary(this.recipes);

  static Future<RecipeLibrary>? _loading;

  static Future<RecipeLibrary> load([AssetBundle? bundle]) => _loading ??= (bundle ?? rootBundle)
      .loadString('assets/recipes/library.json')
      .then((raw) => RecipeLibrary([
            for (final r in (jsonDecode(raw) as Map<String, dynamic>)['recipes'] as List)
              Recipe.fromMap((r as Map).cast<String, dynamic>()),
          ]));

  final List<Recipe> recipes;

  /// Everything this person can eat, best fits first; ties broken by a daily shuffle
  /// so the order feels fresh without changing every minute.
  List<Recipe> suitableFor(UserProfile p, {DateTime? day}) {
    final d = day ?? DateTime.now();
    final seed = '${p.uid}-${d.year}-${d.month}-${d.day}';
    final ok = recipes.where((r) => canEat(p, r)).toList();
    ok.sort((a, b) {
      final byScore = _score(p, b).compareTo(_score(p, a));
      return byScore != 0 ? byScore : _stableHash('$seed${a.id}').compareTo(_stableHash('$seed${b.id}'));
    });
    return ok;
  }

  /// One set of [size] recipes; "New ideas" asks for the next [page].
  List<Recipe> selection(UserProfile p, {int page = 0, int size = 6, DateTime? day}) {
    final all = suitableFor(p, day: day);
    if (all.length <= size) return all;
    final start = (page * size) % all.length;
    return [for (var i = 0; i < size; i++) all[(start + i) % all.length]];
  }

  /// Today's pick from their best fits; the same all day, different tomorrow.
  Recipe? dishOfTheDay(UserProfile p, {DateTime? day}) {
    final d = day ?? DateTime.now();
    final best = suitableFor(p, day: d).take(12).toList();
    if (best.isEmpty) return null;
    return best[_stableHash('${p.uid}-${d.year}-${d.month}-${d.day}') % best.length];
  }
}

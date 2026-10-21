const _allergenNames = {
  'nuts': 'nuts',
  'gluten': 'gluten',
  'dairy': 'dairy',
  'egg': 'egg',
  'shellfish': 'shellfish',
  'fish': 'fish',
  'soy': 'soy',
  'pork': 'pork',
  'alcohol': 'alcohol',
  'onion_garlic': 'onion or garlic',
};

class Recipe {
  const Recipe({
    required this.id,
    required this.title,
    required this.cuisine,
    required this.minutes,
    required this.blurb,
    required this.ingredients,
    required this.steps,
    this.emoji = '🍽️',
    this.diet = 'meat',
    this.allergens = const [],
  });

  factory Recipe.fromMap(Map<String, dynamic> m) => Recipe(
        id: m['id'] as String? ?? '',
        title: m['title'] as String? ?? '',
        cuisine: m['cuisine'] as String? ?? '',
        minutes: (m['minutes'] as num?)?.toInt() ?? 0,
        blurb: m['blurb'] as String? ?? '',
        ingredients: List<String>.from(m['ingredients'] as List? ?? const []),
        steps: List<String>.from(m['steps'] as List? ?? const []),
        emoji: m['emoji'] as String? ?? '🍽️',
        diet: m['diet'] as String? ?? 'meat',
        allergens: List<String>.from(m['allergens'] as List? ?? const []),
      );

  final String id;
  final String title;
  final String cuisine;
  final int minutes;
  final String blurb;
  final List<String> ingredients;
  final List<String> steps;
  final String emoji;

  /// The most permissive diet that can eat it: vegan, vegetarian, pescatarian, or meat.
  final String diet;
  final List<String> allergens;

  String get allergyNote {
    final contains = allergens.map((a) => _allergenNames[a] ?? a).join(', ');
    return '${contains.isEmpty ? '' : 'Contains $contains. '}Always double-check packaged ingredients against your own allergies.';
  }
}

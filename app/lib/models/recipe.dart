class Recipe {
  const Recipe({
    required this.id,
    required this.title,
    required this.cuisine,
    required this.minutes,
    required this.blurb,
    required this.ingredients,
    required this.steps,
    required this.allergyNote,
  });

  factory Recipe.fromMap(Map<String, dynamic> m) => Recipe(
        id: m['id'] as String? ?? '',
        title: m['title'] as String? ?? '',
        cuisine: m['cuisine'] as String? ?? '',
        minutes: (m['minutes'] as num?)?.toInt() ?? 0,
        blurb: m['blurb'] as String? ?? '',
        ingredients: List<String>.from(m['ingredients'] as List? ?? const []),
        steps: List<String>.from(m['steps'] as List? ?? const []),
        allergyNote: m['allergyNote'] as String? ?? '',
      );

  final String id;
  final String title;
  final String cuisine;
  final int minutes;
  final String blurb;
  final List<String> ingredients;
  final List<String> steps;
  final String allergyNote;
}

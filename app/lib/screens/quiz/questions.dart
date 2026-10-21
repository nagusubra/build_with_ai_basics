/// The food quiz, from `prd.md > Food Profile Quiz`. Each card saves to `users/{uid}.food.<field>`.
enum QuizKind { single, multi, text, slider, topPicks, prompts }

class QuizOption {
  const QuizOption(this.label, this.emoji);
  final String label;
  final String emoji;
}

class QuizQuestion {
  const QuizQuestion({
    required this.field,
    required this.title,
    required this.kind,
    this.subtitle,
    this.options = const [],
    this.required = true,
    this.maxPicks,
    this.hint,
    this.otherField,
    this.extraTextField,
    this.extraTextHint,
  });

  final String field;
  final String title;
  final String? subtitle;
  final QuizKind kind;
  final List<QuizOption> options;
  final bool required;
  final int? maxPicks;
  final String? hint;

  /// For "Other": the field holding what they typed.
  final String? otherField;

  /// A free-text companion on the same card (e.g. a favourite song).
  final String? extraTextField;
  final String? extraTextHint;
}

const quizQuestions = <QuizQuestion>[
  QuizQuestion(
    field: 'cookingRelationship',
    title: "What's your relationship with cooking?",
    kind: QuizKind.single,
    options: [
      QuizOption('I love cooking and do it almost every day', '👩‍🍳'),
      QuizOption('I cook when I have time', '🍳'),
      QuizOption('I can manage a few basic dishes', '🥪'),
      QuizOption('I mostly survive on takeaways', '🥡'),
      QuizOption("I don't know how to cook, but I'd love to learn", '🌱'),
    ],
  ),
  QuizQuestion(
    field: 'foodType',
    title: 'What kind of food person are you?',
    kind: QuizKind.single,
    otherField: 'foodTypeOther',
    options: [
      QuizOption('Vegetarian', '🥦'),
      QuizOption('Vegan', '🌿'),
      QuizOption('Non-vegetarian', '🍗'),
      QuizOption('Pescatarian', '🐟'),
      QuizOption('I eat pretty much everything', '🍽️'),
      QuizOption('Other', '✨'),
    ],
  ),
  QuizQuestion(
    field: 'restrictions',
    title: 'Any dietary restrictions or allergies?',
    subtitle: 'Cherry will never suggest a dish that clashes with these.',
    kind: QuizKind.multi,
    required: false,
    options: [
      QuizOption('Nut allergy', '🥜'),
      QuizOption('Gluten-free', '🌾'),
      QuizOption('Dairy-free', '🥛'),
      QuizOption('Egg allergy', '🥚'),
      QuizOption('Shellfish allergy', '🦐'),
      QuizOption('Soy allergy', '🫘'),
      QuizOption('Halal', '☪️'),
      QuizOption('Kosher', '✡️'),
      QuizOption('No onion or garlic', '🧄'),
    ],
  ),
  QuizQuestion(
    field: 'cuisines',
    title: 'What cuisines make you happy?',
    subtitle: 'Pick as many as you like.',
    kind: QuizKind.multi,
    options: [
      QuizOption('Indian', '🍛'),
      QuizOption('Italian', '🍝'),
      QuizOption('Chinese', '🥟'),
      QuizOption('Japanese', '🍣'),
      QuizOption('Mexican', '🌮'),
      QuizOption('Thai', '🍜'),
      QuizOption('Mediterranean', '🫒'),
      QuizOption('Korean', '🥘'),
      QuizOption('French', '🥐'),
      QuizOption('Middle Eastern', '🧆'),
      QuizOption('American', '🍔'),
      QuizOption('British', '🥧'),
    ],
  ),
  QuizQuestion(
    field: 'topCuisines',
    title: 'Now your top three',
    subtitle: 'Ten cuisines don’t tell us much. Which three do you really love?',
    kind: QuizKind.topPicks,
    maxPicks: 3,
  ),
  QuizQuestion(
    field: 'signatureDish',
    title: "What's your signature dish?",
    subtitle: 'It goes right at the top of your profile.',
    kind: QuizKind.text,
    hint: 'e.g. "My pasta is better than most restaurants" or "Maggi at 2 AM counts, right?"',
  ),
  QuizQuestion(
    field: 'adventure',
    title: 'How adventurous are you with food?',
    kind: QuizKind.slider,
    required: false,
  ),
  QuizQuestion(
    field: 'idealDate',
    title: "What's your ideal cooking date?",
    kind: QuizKind.single,
    options: [
      QuizOption('Cooking something simple together', '🥗'),
      QuizOption('Trying a completely new recipe', '📖'),
      QuizOption('A friendly cooking competition', '🏆'),
      QuizOption('Baking something sweet', '🧁'),
      QuizOption('One person cooks, the other helps', '🤝'),
      QuizOption("Honestly, I'd rather eat than cook", '😋'),
    ],
  ),
  QuizQuestion(
    field: 'cookingPersonality',
    title: "What's your cooking personality?",
    subtitle: 'Pick one or two.',
    kind: QuizKind.multi,
    maxPicks: 2,
    options: [
      QuizOption('The organised chef', '📋'),
      QuizOption('The experimental chef', '🧪'),
      QuizOption('The chaotic chef', '🌪️'),
      QuizOption('The perfectionist', '✨'),
      QuizOption('The lazy chef', '🛋️'),
      QuizOption('The food critic', '🧐'),
    ],
  ),
  QuizQuestion(
    field: 'comfortFood',
    title: "What's your comfort food?",
    kind: QuizKind.text,
    required: false,
    hint: 'e.g. homemade dal and rice, ramen, a childhood favourite…',
  ),
  QuizQuestion(
    field: 'cookingTime',
    title: 'How much time would you happily spend cooking?',
    kind: QuizKind.single,
    options: [
      QuizOption('15 minutes or less', '⚡'),
      QuizOption('Around 30 minutes', '⏱️'),
      QuizOption('Around an hour', '🕐'),
      QuizOption('I could spend the whole evening cooking', '🌙'),
    ],
  ),
  QuizQuestion(
    field: 'musicGenres',
    title: 'What music would you cook to?',
    kind: QuizKind.multi,
    required: false,
    extraTextField: 'favouriteSong',
    extraTextHint: 'One favourite song (optional)',
    options: [
      QuizOption('Bollywood', '💃'),
      QuizOption('Pop', '🎤'),
      QuizOption('Indie', '🎸'),
      QuizOption('Jazz', '🎷'),
      QuizOption('Lo-fi', '🎧'),
      QuizOption('Rock', '🤘'),
      QuizOption('Hip-hop', '🎶'),
      QuizOption('Classical', '🎻'),
    ],
  ),
  QuizQuestion(
    field: 'prompts',
    title: 'Want to add a little extra?',
    subtitle: 'Totally optional — no pressure to be funny.',
    kind: QuizKind.prompts,
    required: false,
  ),
];

/// Optional fun prompts (`prd.md > Food Profile Quiz`), saved to `users/{uid}.prompts`.
const profilePrompts = {
  'winMeOverWith': 'Win me over with…',
  'dishEveryDay': 'The dish I could eat every day is…',
  'cookingDisaster': 'My most embarrassing cooking disaster…',
};

/// A short summary of a card's current answer for the edit list, or null if unanswered.
String? answerSummary(QuizQuestion q, Map<String, dynamic> food, Map<String, String> prompts) {
  if (q.kind == QuizKind.prompts) {
    final n = profilePrompts.keys.where((k) => (prompts[k] ?? '').isNotEmpty).length;
    return n == 0 ? null : '$n of ${profilePrompts.length} answered';
  }
  final v = food[q.field];
  final summary = switch (v) {
    String s when s.trim().isNotEmpty => s == 'Other' && _filled(food[q.otherField]) ? food[q.otherField] as String : s,
    List l when l.isNotEmpty => l.join(', '),
    num n => '$n/10',
    _ => null,
  };
  final extra = q.extraTextField == null ? null : food[q.extraTextField];
  if (summary != null && _filled(extra)) return '$summary · “$extra”';
  return summary ?? (_filled(extra) ? '“$extra”' : null);
}

/// Whether this card's answer is enough to move on.
bool isAnswered(QuizQuestion q, Map<String, dynamic> food) {
  if (!q.required) return true;
  final v = food[q.field];
  return switch (q.kind) {
    QuizKind.single => v is String && v.isNotEmpty && (v != 'Other' || _filled(food[q.otherField])),
    QuizKind.multi || QuizKind.topPicks => v is List && v.isNotEmpty && (q.maxPicks == null || v.length <= q.maxPicks!),
    QuizKind.text => _filled(v),
    QuizKind.slider => v is num,
    QuizKind.prompts => true,
  };
}

bool _filled(Object? v) => v is String && v.trim().isNotEmpty;

/// Every required card answered — the quiz is complete.
bool quizComplete(Map<String, dynamic> food) => quizQuestions.every((q) => isAnswered(q, food));

/// The first card still needing an answer, so a returning person resumes there.
int firstUnansweredIndex(Map<String, dynamic> food) {
  final i = quizQuestions.indexWhere((q) => q.required && !isAnswered(q, food));
  return i == -1 ? quizQuestions.length : i;
}

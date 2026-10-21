/// A person's BakeOut profile (`spec.md > Data Model > users/{uid}`).
class UserProfile {
  const UserProfile({
    required this.uid,
    this.name,
    this.age,
    this.gender,
    this.interestedIn = const [],
    this.city,
    this.lookingFor,
    this.photos = const [],
    this.verified = false,
    this.cherryAvatar,
    this.food = const {},
    this.prompts = const {},
    this.quizDone = false,
    this.previewSeen = false,
    this.onboardingComplete = false,
  });

  factory UserProfile.fromMap(String uid, Map<String, dynamic>? d) => UserProfile(
        uid: uid,
        name: d?['name'] as String?,
        age: (d?['age'] as num?)?.toInt(),
        gender: d?['gender'] as String?,
        interestedIn: List<String>.from(d?['interestedIn'] as List? ?? const []),
        city: d?['city'] as String?,
        lookingFor: d?['lookingFor'] as String?,
        photos: List<String>.from(d?['photos'] as List? ?? const []),
        verified: d?['verified'] as bool? ?? false,
        cherryAvatar: d?['cherryAvatar'] as String?,
        food: (d?['food'] as Map?)?.cast<String, dynamic>() ?? const {},
        prompts: (d?['prompts'] as Map?)?.cast<String, String>() ?? const {},
        quizDone: d?['quizDone'] as bool? ?? false,
        previewSeen: d?['previewSeen'] as bool? ?? false,
        onboardingComplete: d?['onboardingComplete'] as bool? ?? false,
      );

  final String uid;
  final String? name;
  final int? age;
  final String? gender;
  final List<String> interestedIn;
  final String? city;

  /// "friends" or "partner".
  final String? lookingFor;

  /// Storage paths; the first is the main photo.
  final List<String> photos;
  final bool verified;

  /// "boy" or "girl" — which cherry this person sees as their wingman.
  final String? cherryAvatar;
  final Map<String, dynamic> food;
  final Map<String, String> prompts;

  /// The person reached the end of the quiz (optional cards included or skipped).
  final bool quizDone;
  final bool previewSeen;
  final bool onboardingComplete;

  bool get hasBasics => name != null && age != null && gender != null && lookingFor != null;

  List<String> foodList(String key) => List<String>.from(food[key] as List? ?? const []);
  String? foodText(String key) {
    final v = food[key];
    return v is String && v.trim().isNotEmpty ? v : null;
  }
}

/// Full years between [dateOfBirth] and [today].
int ageOn(DateTime dateOfBirth, DateTime today) {
  var years = today.year - dateOfBirth.year;
  final hadBirthday = today.month > dateOfBirth.month || (today.month == dateOfBirth.month && today.day >= dateOfBirth.day);
  if (!hadBirthday) years--;
  return years;
}

const minimumAge = 18;

bool isAdult(DateTime dateOfBirth, DateTime today) => ageOn(dateOfBirth, today) >= minimumAge;

/// Boy cherry for men, girl cherry for women, either at random for everyone else
/// (`prd.md > Look and Feel`).
String cherryForGender(String gender, {required bool coinFlip}) => switch (gender) {
      'Man' => 'boy',
      'Woman' => 'girl',
      _ => coinFlip ? 'boy' : 'girl',
    };

const _personalityTaglines = {
  'The organised chef': 'who follows every recipe to the letter',
  'The experimental chef': 'who measures everything with their heart',
  'The chaotic chef': 'who somehow makes a mess of everything — deliciously',
  'The perfectionist': 'for whom presentation matters',
  'The lazy chef': 'living by minimum effort, maximum taste',
  'The food critic': 'mostly here to taste and judge',
};

/// The profile's one-line headline from its food personality (`prd.md > Profile Preview`).
String profileHeadline(UserProfile p) {
  final styles = p.foodList('cookingPersonality');
  if (styles.isEmpty) return 'Food lover looking for someone to cook with';
  final style = styles.first;
  final tagline = _personalityTaglines[style];
  return tagline == null ? style : '$style $tagline';
}

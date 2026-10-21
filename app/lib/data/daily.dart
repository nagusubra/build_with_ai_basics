/// What a person's Jack or Jill says on Discover; one line per day (`prd.md > Added at Final Review`).
const _lines = [
  'Someone out there makes a mean curry. Let’s go find them.',
  'Today feels like a cooking-for-two kind of day.',
  'Look for someone who’d share the last bite with you.',
  'Good dates start with good recipes, and I’ve got both covered.',
  'Your kitchen’s ready. Is your heart?',
  'The best conversations happen over a hot pan.',
  'Find someone who laughs when the soufflé falls.',
  'One like could turn into dinner for two.',
  'Somebody nearby is hoping to meet a cook like you.',
  'Be brave today. I’ll handle the awkward hellos.',
];

String _partOfDay(int hour) => switch (hour) {
      >= 5 && < 12 => 'Good morning',
      >= 12 && < 17 => 'Good afternoon',
      >= 17 && < 22 => 'Good evening',
      _ => 'Up late',
    };

/// "Good evening, Priya!" plus a line that stays the same all day.
({String hello, String line}) dailyGreeting(String? name, DateTime now) {
  final first = (name ?? '').trim();
  final dayNumber = DateTime.utc(now.year, now.month, now.day).millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
  return (
    hello: first.isEmpty ? '${_partOfDay(now.hour)}!' : '${_partOfDay(now.hour)}, $first!',
    line: _lines[dayNumber % _lines.length],
  );
}

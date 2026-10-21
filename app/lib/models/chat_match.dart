class ChatMatch {
  const ChatMatch({
    required this.id,
    required this.users,
    required this.cherryState,
    this.cherryFor = const {},
    this.seenBy = const [],
  });

  factory ChatMatch.fromMap(String id, Map<String, dynamic> data) => ChatMatch(
        id: id,
        users: List<String>.from(data['users'] as List? ?? const []),
        cherryState: data['cherryState'] as String? ?? 'active',
        cherryFor: (data['cherryFor'] as Map?)?.cast<String, String>() ?? const {},
        seenBy: List<String>.from(data['seenBy'] as List? ?? const []),
      );

  final String id;
  final List<String> users;
  final String cherryState;

  /// Which cherry ("boy" or "girl") each person sees as their wingman.
  final Map<String, String> cherryFor;
  final List<String> seenBy;

  bool get cherryPresent => cherryState != 'left';

  String otherUser(String me) => users.firstWhere((u) => u != me, orElse: () => me);
}

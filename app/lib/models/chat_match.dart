/// The cooking-date card's live state (`spec.md > Data Model > matches.datePlan`).
class DatePlan {
  const DatePlan({required this.status, required this.version, this.confirmedBy = const {}});

  factory DatePlan.fromMap(Map<String, dynamic>? data) => DatePlan(
        status: data?['status'] as String? ?? 'none',
        version: (data?['version'] as num?)?.toInt() ?? 0,
        confirmedBy: (data?['confirmedBy'] as Map?)?.cast<String, bool>() ?? const {},
      );

  final String status;
  final int version;
  final Map<String, bool> confirmedBy;

  bool get confirmed => status == 'confirmed';
  bool confirmedByUser(String uid) => confirmedBy[uid] ?? false;
}

class ChatMatch {
  const ChatMatch({
    required this.id,
    required this.users,
    required this.cherryState,
    this.cherryFor = const {},
    this.seenBy = const [],
    this.datePlan = const DatePlan(status: 'none', version: 0),
  });

  factory ChatMatch.fromMap(String id, Map<String, dynamic> data) => ChatMatch(
        id: id,
        users: List<String>.from(data['users'] as List? ?? const []),
        cherryState: data['cherryState'] as String? ?? 'active',
        cherryFor: (data['cherryFor'] as Map?)?.cast<String, String>() ?? const {},
        seenBy: List<String>.from(data['seenBy'] as List? ?? const []),
        datePlan: DatePlan.fromMap((data['datePlan'] as Map?)?.cast<String, dynamic>()),
      );

  final String id;
  final List<String> users;
  final String cherryState;

  /// Which cherry ("boy" or "girl") each person sees as their wingman.
  final Map<String, String> cherryFor;
  final List<String> seenBy;
  final DatePlan datePlan;

  bool get cherryPresent => cherryState != 'left';

  String otherUser(String me) => users.firstWhere((u) => u != me, orElse: () => me);
}

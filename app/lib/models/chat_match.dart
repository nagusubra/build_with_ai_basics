import 'package:cloud_firestore/cloud_firestore.dart';

import 'message.dart';

/// The cooking-date card's live state (`spec.md > Data Model > matches.datePlan`).
class DatePlan {
  const DatePlan({required this.status, required this.version, this.confirmedBy = const {}, this.dish, this.day, this.time});

  factory DatePlan.fromMap(Map<String, dynamic>? data) => DatePlan(
        status: data?['status'] as String? ?? 'none',
        version: (data?['version'] as num?)?.toInt() ?? 0,
        confirmedBy: (data?['confirmedBy'] as Map?)?.cast<String, bool>() ?? const {},
        dish: data?['dish'] as String?,
        day: data?['day'] as String?,
        time: data?['time'] as String?,
      );

  final String status;
  final int version;
  final Map<String, bool> confirmedBy;
  final String? dish;
  final String? day;
  final String? time;

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
    this.readAt = const {},
  });

  factory ChatMatch.fromMap(String id, Map<String, dynamic> data) => ChatMatch(
        id: id,
        users: List<String>.from(data['users'] as List? ?? const []),
        cherryState: data['cherryState'] as String? ?? 'active',
        cherryFor: (data['cherryFor'] as Map?)?.cast<String, String>() ?? const {},
        seenBy: List<String>.from(data['seenBy'] as List? ?? const []),
        datePlan: DatePlan.fromMap((data['datePlan'] as Map?)?.cast<String, dynamic>()),
        readAt: {
          for (final e in ((data['readAt'] as Map?) ?? const {}).entries)
            if (e.value is Timestamp) e.key as String: (e.value as Timestamp).toDate(),
        },
      );

  final String id;
  final List<String> users;
  final String cherryState;

  /// Which cherry ("boy" or "girl") each person sees as their wingman.
  final Map<String, String> cherryFor;
  final List<String> seenBy;
  final DatePlan datePlan;

  /// When each person last had the chat open.
  final Map<String, DateTime> readAt;

  bool get cherryPresent => cherryState != 'left';

  String otherUser(String me) => users.firstWhere((u) => u != me, orElse: () => me);
}

/// Someone else wrote after I last had the chat open.
bool isUnread(ChatMatch m, ChatMessage? last, String me) {
  if (last == null || last.sender == me) return false;
  final read = m.readAt[me];
  return read == null || last.sentAt.isAfter(read);
}

/// The one line under a name in the Chats list.
String chatPreview(ChatMessage last, {required String me, required String wingmanName}) {
  final who = last.sender == me ? 'You: ' : (last.fromCherry ? '$wingmanName: ' : '');
  return switch (last.type) {
    'dateCard' => '📅 $wingmanName shared a cooking-date plan',
    'recipe' => '👩‍🍳 Recipe: ${last.payload['title'] ?? 'for your date'}',
    'song' => '🎵 ${last.payload['title'] ?? 'A song for your date'}',
    'cherryGoodbye' => '🍒 $wingmanName said goodbye',
    _ => '$who${last.text}',
  };
}

/// Where things stand: the date, or whether the wingman is still around.
String chatStatus(ChatMatch m, {required String wingmanName}) {
  final p = m.datePlan;
  if (p.confirmed) {
    final when = [p.day, p.time].whereType<String>().where((s) => s.trim().isNotEmpty).join(' · ');
    return when.isEmpty ? 'It’s a date 🎉' : 'It’s a date 🎉 $when';
  }
  return m.cherryPresent ? '🍒 $wingmanName is here' : 'Just the two of you 💛';
}

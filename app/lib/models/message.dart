import 'package:cloud_firestore/cloud_firestore.dart';

const cherrySender = 'cherry';

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.sender,
    required this.type,
    required this.text,
    required this.sentAt,
    this.payload = const {},
  });

  factory ChatMessage.fromMap(String id, Map<String, dynamic> data) {
    final created = data['createdAt'];
    return ChatMessage(
      id: id,
      sender: data['sender'] as String? ?? '',
      type: data['type'] as String? ?? 'text',
      text: data['text'] as String? ?? '',
      // A message we just sent has no server time yet; it belongs at the end.
      sentAt: created is Timestamp ? created.toDate() : DateTime.now(),
      payload: (data['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  final String id;
  final String sender;
  final String type;
  final String text;
  final DateTime sentAt;
  final Map<String, dynamic> payload;

  bool get fromCherry => sender == cherrySender;
}

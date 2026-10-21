import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/chat_match.dart';
import '../models/message.dart';

class ChatService {
  ChatService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Stream<List<ChatMatch>> matchesFor(String uid) => _db
      .collection('matches')
      .where('users', arrayContains: uid)
      .snapshots()
      .map((s) => s.docs.map((d) => ChatMatch.fromMap(d.id, d.data())).toList());

  Stream<ChatMatch?> match(String matchId) => _db
      .doc('matches/$matchId')
      .snapshots()
      .map((d) => d.exists ? ChatMatch.fromMap(d.id, d.data()!) : null);

  Stream<List<ChatMessage>> messages(String matchId) => _db
      .collection('matches/$matchId/messages')
      .orderBy('createdAt')
      .snapshots()
      .map((s) => s.docs.map((d) => ChatMessage.fromMap(d.id, d.data())).toList());

  Future<String> displayName(String uid) async {
    final doc = await _db.doc('users/$uid').get();
    return doc.data()?['name'] as String? ?? 'Someone';
  }

  Future<void> send(String matchId, String senderUid, String text) {
    final body = text.trim();
    if (body.isEmpty) return Future.value();
    return _db.collection('matches/$matchId/messages').add({
      'sender': senderUid,
      'type': 'text',
      'text': body,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

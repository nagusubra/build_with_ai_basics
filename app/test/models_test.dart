import 'package:bakeout/models/chat_match.dart';
import 'package:bakeout/models/message.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatMatch', () {
    test('reads users, Cherry state, and cherry assignments', () {
      final m = ChatMatch.fromMap('a_b', {
        'users': ['a', 'b'],
        'cherryState': 'left',
        'cherryFor': {'a': 'boy', 'b': 'girl'},
      });
      expect(m.otherUser('a'), 'b');
      expect(m.otherUser('b'), 'a');
      expect(m.cherryPresent, isFalse);
      expect(m.cherryFor['b'], 'girl');
    });

    test('Cherry is present by default', () {
      expect(ChatMatch.fromMap('x', {'users': ['a', 'b']}).cherryPresent, isTrue);
    });
  });

  group('ChatMessage', () {
    test('reads a server-timestamped text message', () {
      final sent = DateTime(2026, 10, 21, 9, 30);
      final m = ChatMessage.fromMap('m1', {
        'sender': 'a',
        'type': 'text',
        'text': 'hi',
        'createdAt': Timestamp.fromDate(sent),
      });
      expect(m.text, 'hi');
      expect(m.sentAt, sent);
      expect(m.fromCherry, isFalse);
    });

    test('a just-sent message without server time sorts as now', () {
      final before = DateTime.now();
      final m = ChatMessage.fromMap('m2', {'sender': 'cherry', 'text': 'Hello!'});
      expect(m.fromCherry, isTrue);
      expect(m.sentAt.isBefore(before), isFalse);
      expect(m.type, 'text');
    });
  });
}

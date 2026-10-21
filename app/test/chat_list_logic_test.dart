import 'package:bakeout/models/chat_match.dart';
import 'package:bakeout/models/message.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

ChatMessage _msg(String sender, {String type = 'text', String text = 'hi', DateTime? at, Map<String, dynamic>? payload}) =>
    ChatMessage(id: 'm', sender: sender, type: type, text: text, sentAt: at ?? DateTime(2026, 10, 22, 12), payload: payload ?? const {});

ChatMatch _match({Map<String, dynamic> extra = const {}}) =>
    ChatMatch.fromMap('a_b', {'users': ['a', 'b'], 'cherryState': 'active', ...extra});

void main() {
  group('unread', () {
    test('a message from someone else after I last read is unread', () {
      final m = _match(extra: {'readAt': {'a': Timestamp.fromDate(DateTime(2026, 10, 22, 11))}});
      expect(isUnread(m, _msg('b'), 'a'), isTrue);
      expect(isUnread(m, _msg(cherrySender), 'a'), isTrue);
    });

    test('my own messages, older messages, and empty chats are not', () {
      final m = _match(extra: {'readAt': {'a': Timestamp.fromDate(DateTime(2026, 10, 22, 13))}});
      expect(isUnread(m, _msg('a', at: DateTime(2026, 10, 22, 14)), 'a'), isFalse);
      expect(isUnread(m, _msg('b'), 'a'), isFalse);
      expect(isUnread(m, null, 'a'), isFalse);
    });

    test('never opened means unread', () {
      expect(isUnread(_match(), _msg('b'), 'a'), isTrue);
    });
  });

  group('preview and status', () {
    test('previews say who wrote it and what the cards are', () {
      expect(chatPreview(_msg('a', text: 'See you then!'), me: 'a', wingmanName: 'Jill'), 'You: See you then!');
      expect(chatPreview(_msg('b', text: 'Yes!'), me: 'a', wingmanName: 'Jill'), 'Yes!');
      expect(chatPreview(_msg(cherrySender, text: 'Hello you two'), me: 'a', wingmanName: 'Jill'), 'Jill: Hello you two');
      expect(chatPreview(_msg(cherrySender, type: 'recipe', payload: {'title': 'Pad Thai'}), me: 'a', wingmanName: 'Jack'),
          '👩‍🍳 Recipe: Pad Thai');
      expect(chatPreview(_msg(cherrySender, type: 'cherryGoodbye'), me: 'a', wingmanName: 'Jack'), '🍒 Jack said goodbye');
    });

    test('status shows the date once confirmed, otherwise whether the wingman is here', () {
      expect(chatStatus(_match(), wingmanName: 'Jill'), '🍒 Jill is here');
      expect(chatStatus(_match(extra: {'cherryState': 'left'}), wingmanName: 'Jill'), 'Just the two of you 💛');
      final date = _match(extra: {
        'cherryState': 'left',
        'datePlan': {'status': 'confirmed', 'version': 2, 'day': 'Saturday', 'time': '7pm', 'dish': 'Pad Thai'},
      });
      expect(chatStatus(date, wingmanName: 'Jill'), 'It’s a date 🎉 Saturday · 7pm');
    });
  });
}

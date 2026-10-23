import 'package:flutter_test/flutter_test.dart';
import 'package:medbridge/backend/chat_service.dart';
import 'package:medbridge/constants.dart';
import 'package:medbridge/models.dart';

void main() {
  group('ChatService.chatId', () {
    test('patient->doctor and doctor->patient give the same id', () {
      expect(ChatService.chatId('patientUid', 'doctorUid'),
          ChatService.chatId('doctorUid', 'patientUid'));
    });

    test('sorts deterministically', () {
      expect(ChatService.chatId('b', 'a'), 'a_b');
      expect(ChatService.chatId('a', 'b'), 'a_b');
    });

    test('rejects empty and identical ids', () {
      expect(() => ChatService.chatId('', 'a'), throwsA(isA<ChatException>()));
      expect(() => ChatService.chatId('a', '  '), throwsA(isA<ChatException>()));
      expect(() => ChatService.chatId('a', 'a'), throwsA(isA<ChatException>()));
    });
  });

  group('ChatService.validateMessage', () {
    test('trims text', () {
      expect(ChatService.validateMessage('  hi  '), 'hi');
    });

    test('rejects empty text without image', () {
      expect(() => ChatService.validateMessage('   '),
          throwsA(isA<ChatException>()));
    });

    test('allows empty text with image', () {
      expect(ChatService.validateMessage('', imageBase64: 'abc'), '');
    });

    test('rejects over-long text', () {
      expect(() => ChatService.validateMessage('x' * 2001),
          throwsA(isA<ChatException>()));
    });
  });

  group('ChatThread unread counts', () {
    test('unreadCountFor defaults to 0 and is per user', () {
      final t = ChatThread(
        id: 'a_b',
        lastMessage: 'hi',
        lastTimestamp: DateTime(2026),
        participants: const ['a', 'b'],
        participantNames: const {},
        unreadCounts: const {'b': 3},
      );
      expect(t.unreadCountFor('a'), 0);
      expect(t.unreadCountFor('b'), 3);
    });
  });

  group('availability', () {
    test('editor-style workDays hide non-working days', () {
      final av = {'workDays': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri']};
      expect(isWorkingDay(1, av), isTrue);
      expect(isWorkingDay(6, av), isFalse);
      expect(isWorkingDay(7, av), isFalse);
    });

    test('registration-style workingDays still work', () {
      expect(isWorkingDay(6, {'workingDays': [1, 2, 3, 4, 5, 6]}), isTrue);
      expect(isWorkingDay(7, {'workingDays': [1, 2, 3, 4, 5, 6]}), isFalse);
    });

    test('slots follow hours, duration and lunch', () {
      final slots = buildSlotsFromAvailability({
        'startHour': 9, 'endHour': 17, 'slotMinutes': 30,
        'lunchStart': 13, 'lunchEnd': 14,
      });
      expect(slots.length, 14); // matches the editor preview
      expect(slots.first, Slot(9, 0));
      expect(slots.contains(Slot(13, 0)), isFalse);
      expect(slots.contains(Slot(13, 30)), isFalse);
      expect(slots.contains(Slot(14, 0)), isTrue);
      expect(slots.last, Slot(16, 30));
    });
  });
}

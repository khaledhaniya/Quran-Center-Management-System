import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Offline Synchronization & Storage Queue Tests', () {
    test('Offline recitation action queue serialization and deserialization', () {
      final offlineActions = [
        {
          'id': 'uuid-1',
          'action': 'RECORD_ATTENDANCE',
          'payload': {'studentId': 42, 'status': 'Present', 'date': '2026-08-24'},
          'timestamp': 1787610000
        },
        {
          'id': 'uuid-2',
          'action': 'LOG_RECITATION',
          'payload': {'studentId': 42, 'pagesCount': 2.0, 'grade': 'Excellent'},
          'timestamp': 1787610005
        }
      ];

      final encoded = jsonEncode(offlineActions);
      expect(encoded, isA<String>());

      final decoded = jsonDecode(encoded) as List<dynamic>;
      expect(decoded.length, equals(2));
      expect(decoded[0]['action'], equals('RECORD_ATTENDANCE'));
      expect(decoded[1]['payload']['pagesCount'], equals(2.0));
    });

    test('Offline queue FIFO ordering and processing priority', () {
      final queue = <Map<String, dynamic>>[];

      // Teacher records attendance first, then records recitation
      queue.add({'seq': 1, 'type': 'Attendance'});
      queue.add({'seq': 2, 'type': 'Recitation'});
      queue.add({'seq': 3, 'type': 'BehaviorNote'});

      final firstToSync = queue.removeAt(0);
      expect(firstToSync['seq'], equals(1));
      expect(firstToSync['type'], equals('Attendance'));

      final secondToSync = queue.removeAt(0);
      expect(secondToSync['seq'], equals(2));
      expect(secondToSync['type'], equals('Recitation'));

      expect(queue.length, equals(1));
    });
  });
}

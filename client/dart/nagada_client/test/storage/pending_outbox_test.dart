  
import '../../lib/nagada.dart';
import 'package:test/test.dart';

void main() {
  group('PendingOutbox', () {
    late PendingOutbox pendingOutbox;

    setUp(() {
      pendingOutbox = InMemoryAdapter();
    });

    ClientEvent _createEvent(String id, {int? timestamp}) {
      return ClientEvent(
        clientEventId: id,
        type: 'test-event',
        payload: {'data': 'test'},payloadManifest: [],
        createdAt: timestamp??0,
      );
    }

    test('Add event is stored successfully', () async {
      final event = _createEvent('id-1');
      await pendingOutbox.add(event);
      final pendingEvents = await pendingOutbox.pending();
      expect(pendingEvents, hasLength(1));
      expect(pendingEvents.first.clientEventId, 'id-1');
    });

    test('Load pending events returns FIFO (ordered by timestamp)', () async {
      final event1 = _createEvent('id-1', timestamp: 1000);
      final event2 = _createEvent('id-2', timestamp: 500); // Earlier timestamp
      final event3 = _createEvent('id-3', timestamp: 1500);

      await pendingOutbox.add(event1);
      await pendingOutbox.add(event2);
      await pendingOutbox.add(event3);

      final pendingEvents = await pendingOutbox.pending();

      expect(pendingEvents, hasLength(3));
      expect(pendingEvents[0].clientEventId, 'id-2');
      expect(pendingEvents[1].clientEventId, 'id-1');
      expect(pendingEvents[2].clientEventId, 'id-3');
    });

    test('Mark as synced removes processed event', () async {
      final event1 = _createEvent('id-1');
      final event2 = _createEvent('id-2');
      await pendingOutbox.add(event1);
      await pendingOutbox.add(event2);

      await pendingOutbox.markAsSynced([event1.clientEventId]);

      final pendingEvents = await pendingOutbox.pending();
      expect(pendingEvents, hasLength(1));
      expect(pendingEvents.first.clientEventId, 'id-2');
    });

    test('Mark as synced handles multiple events', () async {
      final event1 = _createEvent('id-1');
      final event2 = _createEvent('id-2');
      final event3 = _createEvent('id-3');
      await pendingOutbox.add(event1);
      await pendingOutbox.add(event2);
      await pendingOutbox.add(event3);

      await pendingOutbox.markAsSynced([event1.clientEventId]);
      await pendingOutbox.markAsSynced( [event3.clientEventId]);

      final pendingEvents = await pendingOutbox.pending();
      expect(pendingEvents, hasLength(1));
      expect(pendingEvents.first.clientEventId, 'id-2');
    });

    test('Idempotent behavior for markAsSynced', () async {
      final event = _createEvent('id-1');
      await pendingOutbox.add(event);

      // First time
      await pendingOutbox.markAsSynced([event.clientEventId]);
      var pendingEvents = await pendingOutbox.pending();
      expect(pendingEvents, isEmpty);

      // Second time, should not throw an error
      await pendingOutbox.markAsSynced([event.clientEventId]);
      pendingEvents = await pendingOutbox.pending();
      expect(pendingEvents, isEmpty);
    });

    test('Mark as synced on empty outbox does not error', () async {
      final event = _createEvent('id-1');
      await expectLater(pendingOutbox.markAsSynced([event.clientEventId]), completes);
    });
  });
}

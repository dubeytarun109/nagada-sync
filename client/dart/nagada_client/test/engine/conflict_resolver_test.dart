import '../../lib/engine/conflict_resolver.dart';
import '../../lib/core/models/server_event.dart';
import 'package:test/test.dart';

void main() {
  group('ConflictResolver', () {
    final event1 = ServerEvent(serverEventId: 1, originClientEventId: 'a', originClientDeviceId: 'd1',  payload: {'v': 1},payloadManifest: [],createdAt: 0);
    final event2 = ServerEvent(serverEventId: 2, originClientEventId: 'b', originClientDeviceId: 'd1',  payload: {'v': 2},payloadManifest: [],createdAt: 0);
    final event3Conflict = ServerEvent(serverEventId: 3, originClientEventId: 'a', originClientDeviceId: 'd2',  payload: {'v': 3},payloadManifest: [],createdAt: 0);
    final event4 = ServerEvent(serverEventId: 4, originClientEventId: 'c', originClientDeviceId: 'd1',  payload: {'v': 4},payloadManifest: [],createdAt: 0);

    test('Last-write-wins logic', () {
      final resolver = ConflictResolver();
      final events = [event1, event2, event3Conflict, event4];
      final resolved = resolver.resolve(events);
      expect(resolved, hasLength(3));
      expect(resolved.map((e) => e.serverEventId), containsAllInOrder([2, 3, 4]));
      expect(resolved.firstWhere((e) => e.originClientEventId == 'a').serverEventId, 3);
    });

    test('Custom resolver hook invoked', () {
      ServerEvent customResolver(List<ServerEvent> conflicts) {
        // Simple custom logic: choose the one with the lowest serverEventId
        conflicts.sort((a, b) => a.serverEventId.compareTo(b.serverEventId));
        return conflicts.first;
      }

      final resolver = ConflictResolver(customResolver: customResolver);
      final events = [event1, event2, event3Conflict, event4];
      final resolved = resolver.resolve(events);
      expect(resolved, hasLength(3));
      expect(resolved.map((e) => e.serverEventId), containsAllInOrder([1, 2, 4]));
      expect(resolved.firstWhere((e) => e.originClientEventId == 'a').serverEventId, 1);
    });

    test('Deterministic repeat result', () {
      final resolver = ConflictResolver();
      final events = [event1, event2, event3Conflict, event4];
      
      final resolved1 = resolver.resolve(events);
      final resolved2 = resolver.resolve(List.from(resolved1)); // Apply again to the result

      expect(resolved1.map((e) => e.toJson()), equals(resolved2.map((e) => e.toJson())));

      // Also test with a shuffled list
      final shuffledEvents = List<ServerEvent>.from(events)..shuffle();
      final resolved3 = resolver.resolve(shuffledEvents);
      expect(resolved1.map((e) => e.toJson()), equals(resolved3.map((e) => e.toJson())));
    });

    test('Handles empty list', () {
      final resolver = ConflictResolver();
      final resolved = resolver.resolve([]);
      expect(resolved, isEmpty);
    });

    test('No conflicts', () {
      final resolver = ConflictResolver();
      final events = [event1, event2, event4];
      final resolved = resolver.resolve(events);
      expect(resolved.map((e) => e.toJson()), equals(events.map((e) => e.toJson())));
    });
  });
}

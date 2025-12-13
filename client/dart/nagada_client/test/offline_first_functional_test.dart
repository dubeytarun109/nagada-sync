import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import '../lib/core/models/sync_request.dart';
import '../lib/core/models/sync_response.dart';
import '../lib/engine/conflict_resolver.dart';
import '../lib/engine/sync_engine.dart';
import '../lib/nagada.dart';

// Mocks and helper classes (copied from basic_pull_cycle_test.dart)
class MockHttpSyncTransport extends Mock implements HttpSyncTransport {
  @override
  Future<SyncResponse> sync(SyncRequest? request) {
    return super.noSuchMethod(
      Invocation.method(#sync, [request]),
      returnValue: Future.value(
        SyncResponse(successClientEventIds: [], newServerEvents: [], nextHeartbeatMs: -1, errorClientEventIds: {}),
      ),
    );
  }
}

// Custom ConflictResolvers for testing
class TestConflictResolver extends ConflictResolver {
  TestConflictResolver() : super(customResolver: (conflicts) {
    // For testing purposes, remote (last in sorted list) always wins.
    conflicts.sort((a, b) => a.serverEventId.compareTo(b.serverEventId));
    return conflicts.last;
  });
}

class TestConflictResolverWithLog extends ConflictResolver {
  final List<Map<String, dynamic>> log;

  TestConflictResolverWithLog(this.log) : super(customResolver: (conflicts) {
    // For testing purposes, remote (last in sorted list) always wins.
    conflicts.sort((a, b) => a.serverEventId.compareTo(b.serverEventId));
    final resolved = conflicts.last;
    log.add({'local': conflicts.first.payload, 'remote': resolved.payload}); // Log the first (local) and last (remote/resolved)
    return resolved;
  });
}


void main() {
  group('Offline-First Functional Tests', () {
    late MockHttpSyncTransport transport;
    late InMemoryAdapter storage;
    late InMemoryAdapter offsetStore;
    late InMemoryAdapter outbox;
    late Map<String, dynamic> projection;

    setUp(() {
      transport = MockHttpSyncTransport();
      storage = InMemoryAdapter();
      offsetStore = storage; // InMemoryAdapter serves as both
      outbox = storage;     // InMemoryAdapter serves as both
      projection = <String, dynamic>{};
    });

    SyncEngine createEngine({
      String deviceId = 'test-device',
      ConflictResolver? conflictResolver,
      ApplyEventsCallback? onApplyEvents, // Use the typedef
    }) {
      return SyncEngine(
        deviceId: deviceId,
        transport: transport,
        offsetStore: offsetStore,
        outbox: outbox,
        conflictResolver: conflictResolver ?? TestConflictResolver(),
        onApplyEvents: onApplyEvents ??
            (events) async {
              for (final event in events) {
                final decodedPayload = event.payload;
                if (decodedPayload?['id'] != null) {
                  projection[decodedPayload?['id'] as String] = decodedPayload;
                }
              }
            },
      );
    }

    // 14. Use App Completely Offline
    test('Use App Completely Offline', () async {
      // Simulate client going offline initially
      when(transport.sync(any)).thenThrow(Exception('No network connection'));

      final List<String> eventIds = [];
      final engine = createEngine(onApplyEvents: (events) async {
        eventIds.addAll(events.map((e) => e.payload?['id'] as String));
        for (final event in events) {
          final decodedPayload = event.payload;
          if (decodedPayload?['id'] != null) {
            projection[decodedPayload?['id'] as String] = decodedPayload;
          }
        }
      });

      // 1. Insert records offline
      await outbox.add(ClientEvent(clientEventId: 'off-1', type: 'add', payload: {'id': 'offline-1', 'data': 'first'},payloadManifest: [],createdAt: 0));
      await outbox.add(ClientEvent(clientEventId: 'off-2', type: 'add', payload: {'id': 'offline-2', 'data': 'second'},payloadManifest: [],createdAt: 0));

      // Try to sync - should fail due to network
      await expectLater(engine.runCycle(), throwsException);
      expect(await outbox.pending(), hasLength(2));
      expect(await offsetStore.get()??0, 0);
      expect(eventIds, isEmpty); // No events applied as sync failed

      // 2. Simulate app restart - new engine instance, same storage
      // The outbox and offset should persist
      final List<String> eventIds2 = [];
      final engine2 = createEngine(onApplyEvents: (events) async {
        eventIds2.addAll(events.map((e) => e.payload?['id'] as String));
        // Also update projection
        for (final event in events) {
          final decodedPayload = event.payload;
          if (decodedPayload?['id'] != null) {
            projection[decodedPayload?['id'] as String] = decodedPayload;
          }
        }
      });

      await expectLater(engine2.runCycle(), throwsException); // Still offline
      expect(await outbox.pending(), hasLength(2));
      expect(await offsetStore.get()??0, 0);
      expect(eventIds2, isEmpty);

      // 3. Go online, sync restores consistency
      when(transport.sync(any)).thenAnswer((invocation) async {
        final SyncRequest request = invocation.positionalArguments.first;
        expect(request.pendingEvents, hasLength(2)); // Both pending events sent
        expect(request.pendingEvents.map((e) => e.clientEventId), containsAll(['off-1', 'off-2']));

        return SyncResponse(
          successClientEventIds: ['off-1', 'off-2'],
          newServerEvents: [
            ServerEvent(serverEventId: 1, originClientEventId: 'off-1', originClientDeviceId: 'test-device', payload: {"id": "offline-1", "data": "first"},payloadManifest: [], createdAt: 0),
            ServerEvent(serverEventId: 2, originClientEventId: 'off-2', originClientDeviceId: 'test-device', payload: {"id": "offline-2", "data": "second"},payloadManifest: [], createdAt: 0),
          ], nextHeartbeatMs: -1, errorClientEventIds: {},
        );
      });

      await engine2.runCycle();

      expect(await outbox.pending(), isEmpty);
      expect(await offsetStore.get()??0, 2);
      expect(eventIds2.length, 2);
      expect(eventIds2, containsAll(['offline-1', 'offline-2']));
      expect(projection['offline-1']?['data']??'none', 'first');
      expect(projection['offline-2']?['data']??'none', 'second');
    });

    // 15. Offline Mutation Ordering Preserved
    test('Offline Mutation Ordering Preserved', () async {
      // Client goes offline
      when(transport.sync(any)).thenThrow(Exception('No network connection'));

      final engine = createEngine();

      // Create events in a specific order
      final clientEvent1 = ClientEvent(clientEventId: 'event-1', type: 't', payload: {'id': 'item-A', 'value': 1},payloadManifest: [],createdAt: 0);
      final clientEvent2 = ClientEvent(clientEventId: 'event-2', type: 't', payload: {'id': 'item-A', 'value': 2},payloadManifest: [],createdAt: 0);
      final clientEvent3 = ClientEvent(clientEventId: 'event-3', type: 't', payload: {'id': 'item-A', 'value': 3},payloadManifest: [],createdAt: 0);

      await outbox.add(ClientEvent(clientEventId: 'event-1', type: 't', payload: {'id': 'item-A', 'value': 1},payloadManifest: [],createdAt: 0));
      await outbox.add(ClientEvent(clientEventId: 'event-2', type: 't', payload: {'id': 'item-A', 'value': 2},payloadManifest: [],createdAt: 0));
      await outbox.add(ClientEvent(clientEventId: 'event-3', type: 't', payload: {'id': 'item-A', 'value': 3},payloadManifest: [],createdAt: 0));


      // Attempt sync while offline
      await expectLater(engine.runCycle(), throwsException);
      expect(await outbox.pending(), hasLength(3));

      // Go online - server will receive events in order they were added to outbox
      when(transport.sync(any)).thenAnswer((invocation) async {
        final SyncRequest request = invocation.positionalArguments.first;
        expect(request.pendingEvents.map((e) => e.clientEventId), orderedEquals(['event-1', 'event-2', 'event-3']));

        return SyncResponse(
          successClientEventIds: ['event-1', 'event-2', 'event-3'],
          newServerEvents: [
            ServerEvent(serverEventId: 1, originClientEventId: 'event-1', originClientDeviceId: 'test-device', payload: clientEvent1.payload,payloadManifest: [], createdAt: 0),
            ServerEvent(serverEventId: 2, originClientEventId: 'event-2', originClientDeviceId: 'test-device', payload: clientEvent2.payload,payloadManifest: [], createdAt: 0),
            ServerEvent(serverEventId: 3, originClientEventId: 'event-3', originClientDeviceId: 'test-device', payload: clientEvent3.payload,payloadManifest: [], createdAt: 0),
          ], nextHeartbeatMs: -1, errorClientEventIds: {},
        );
      });

      final List<ServerEvent> appliedEvents = [];
      final engineOnline = createEngine(onApplyEvents: (events) async {
        appliedEvents.addAll(events);
        // Also update projection
        for (final event in events) {
          final decodedPayload = event.payload;
          if (decodedPayload?['id'] != null) {
            projection[decodedPayload?['id'] as String] = decodedPayload;
          }
        }
      });

      await engineOnline.runCycle();

      // Verify events are applied in correct server order (which should match client order)
      expect(appliedEvents.map((e) => e.originClientEventId), orderedEquals(['event-1', 'event-2', 'event-3']));
      expect(projection['item-A']['value'], 3); // Final state should be from event 3
      expect(await offsetStore.get()??0, 3);
      expect(await outbox.pending(), isEmpty);
    });
  });
}

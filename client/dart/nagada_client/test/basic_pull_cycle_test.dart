import 'package:mockito/mockito.dart';
import '../lib/core/models/sync_request.dart';
import '../lib/core/models/sync_response.dart';
import '../lib/engine/sync_engine.dart';
import '../lib/nagada.dart';
import 'package:test/test.dart';

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

void main() {
  group('Integration Tests', () {
    test('Basic Pull Cycle', () async {
      // Arrange
      final transport = MockHttpSyncTransport();
      final storage = InMemoryAdapter();
      final offsetStore = storage;
      final pendingOutbox = storage;
      final projection = <String, dynamic>{};

      final engine = SyncEngine(
        deviceId: 'test-device',
        transport: transport,
        offsetStore: offsetStore,
        outbox: pendingOutbox,
        onApplyEvents: (events) async {
          for (final event in events) {
            projection[event.payload?['id'] as String] = event.payload;
          }
        },
      );

      final serverEvents = [
        ServerEvent(serverEventId: 1, originClientEventId: 'c1', originClientDeviceId: 'd1', payload: {"id": "1", "data": "a"},payloadManifest: [], createdAt: 0),
        ServerEvent(serverEventId: 2, originClientEventId: 'c2', originClientDeviceId: 'd1', payload: {"id": "2", "data": "b"},payloadManifest: [], createdAt: 0),
        ServerEvent(serverEventId: 3, originClientEventId: 'c3', originClientDeviceId: 'd1', payload: {"id": "3", "data": "c"},payloadManifest: [], createdAt: 0),
      ];

      when(transport.sync(any)).thenAnswer(
        (_) async => SyncResponse(
          successClientEventIds: [],
          newServerEvents: serverEvents, nextHeartbeatMs: -1, errorClientEventIds: {}
        ),
      );

      // Act
      await engine.runCycle();

      // Assert
      expect(projection.length, 3);
      expect(projection['1']?['data'], 'a');
      expect(projection['2']?['data'], 'b');
      expect(projection['3']?['data'], 'c');

      final newOffset = await offsetStore.get();
      expect(newOffset, 3);
    });

    test('Push + Pull Cycle', () async {
      // Arrange
      final transport = MockHttpSyncTransport();
      final storage = InMemoryAdapter();
      final offsetStore = storage;
      final pendingOutbox = storage;
      final projection = <String, dynamic>{};

      final engine = SyncEngine(
        deviceId: 'test-device',
        transport: transport,
        offsetStore: offsetStore,
        outbox: pendingOutbox,
        onApplyEvents: (events) async {
          for (final event in events) {
            projection[event.payload?['id'] as String] = event.payload;
          }
        },
      );

      // 1. Client creates an event offline
      final clientEvent = ClientEvent(
        clientEventId: 'event-123',
        type: 'item-created',
        payload: {'id': '4', 'data': 'd'},payloadManifest: ['1','2'],createdAt: 0,
      );
      await pendingOutbox.add(clientEvent);

      // 2. Configure mock server response
      final serverEvents = [
        // Server echoes back the client's event, now enriched with a server ID
        ServerEvent(serverEventId: 4, originClientEventId: 'event-123', originClientDeviceId: 'test-device', payload: {"id": "4", "data": "d"},payloadManifest: [],createdAt: 0),
        // Another event from a different client
        ServerEvent(serverEventId: 5, originClientEventId: 'c5', originClientDeviceId: 'other-device', payload: {"id": "5", "data": "e"},payloadManifest: [], createdAt: 0),
      ];

      when(transport.sync(any)).thenAnswer((invocation) async {
        final SyncRequest request = invocation.positionalArguments.first;
        expect(request.pendingEvents, hasLength(1));
        expect(request.pendingEvents.first.clientEventId, 'event-123');
        
        return SyncResponse(
          successClientEventIds: ['event-123'],
          newServerEvents: serverEvents, nextHeartbeatMs: -1, errorClientEventIds: {}
        );
      });

      // Act
      await engine.runCycle();

      // Assert
      // Outbox should be empty
      final pending = await pendingOutbox.pending();
      expect(pending, isEmpty);

      // Offset should be updated
      final newOffset = await offsetStore.get();
      expect(newOffset, 5);

      // Projection should contain both events
      expect(projection.length, 2);
      expect(projection['4']?['data'], 'd');
      expect(projection['5']?['data'], 'e');
    });

    test('Idempotency / Duplicate Pull', () async {
      // Arrange
      final transport = MockHttpSyncTransport();
      final storage = InMemoryAdapter();
      final offsetStore = storage;
      final pendingOutbox = storage;
      final projection = <String, dynamic>{};
      var applyCount = 0;

      final engine = SyncEngine(
        deviceId: 'test-device',
        transport: transport,
        offsetStore: offsetStore,
        outbox: pendingOutbox,
        onApplyEvents: (events) async {
          applyCount++;
          for (final event in events) {
            projection[event.payload?['id'] as String] = event.payload;
          }
        },
      );

      final serverEvents = [
        ServerEvent(serverEventId: 1, originClientEventId: 'c1', originClientDeviceId: 'd1', payload: {"id": "1", "data": "a"},payloadManifest: [], createdAt: 0),
        ServerEvent(serverEventId: 2, originClientEventId: 'c2', originClientDeviceId: 'd1', payload: {"id": "2", "data": "b"},payloadManifest: [], createdAt: 0),
      ];

      when(transport.sync(any)).thenAnswer(
        (_) async => SyncResponse(
          successClientEventIds: [],
          newServerEvents: serverEvents, nextHeartbeatMs: -1, errorClientEventIds: {},
        ),
      );

      // Act
      // First cycle
      await engine.runCycle();

      // Assert first cycle
      expect(projection.length, 2);
      final offsetAfterFirstRun = await offsetStore.get();
      expect(offsetAfterFirstRun, 2);
      expect(applyCount, 1);

      // Second cycle
      await engine.runCycle();

      // Assert second cycle
      expect(projection.length, 2, reason: "Projection store should not change.");
      final offsetAfterSecondRun = await offsetStore.get();
      expect(offsetAfterSecondRun, 2, reason: "Offset should not change.");
      expect(applyCount, 1, reason: "onApplyEvents should not be called again for the same events.");
      verify(transport.sync(any)).called(2);
    });

    test('Outbox Replay After Crash', () async {
      // Arrange
      final storage = InMemoryAdapter();
      final offsetStore = storage;
      final pendingOutbox = storage;
      final transport = MockHttpSyncTransport();
      final projection = <String, dynamic>{};
      var applyCount = 0;

      // 1. Client creates an event offline
      final clientEvent = ClientEvent(
        clientEventId: 'crash-event-456',
        type: 'item-added',
        payload: {'id': '10', 'value': 'x'},payloadManifest: [],createdAt: 0
      );
      await pendingOutbox.add(clientEvent);

      // 2. Configure mock to crash on first attempt, succeed on second
      var callCounter = 0;
      when(transport.sync(any)).thenAnswer((invocation) async {
        callCounter++;
        final SyncRequest request = invocation.positionalArguments.first;
        expect(request.pendingEvents, hasLength(1));
        expect(request.pendingEvents.first.clientEventId, 'crash-event-456');

        if (callCounter == 1) {
          // Simulate crash after server receives event, but before client gets ack
          throw Exception('Simulated network crash');
        } else {
          // On second attempt, server acks and returns the event
          final serverEvent = ServerEvent(
            serverEventId: 10,
            originClientEventId: 'crash-event-456',
            originClientDeviceId: 'test-device',
            payload: {"id": "10", "value": "x"},payloadManifest: [],
            createdAt: 0,
          );
          return SyncResponse(
            successClientEventIds: ['crash-event-456'],
            newServerEvents: [serverEvent], nextHeartbeatMs: -1, errorClientEventIds: {},
          );
        }
      });

      // 3. First engine instance (before crash)
      var engine = SyncEngine(
        deviceId: 'test-device',
        transport: transport,
        offsetStore: offsetStore,
        outbox: pendingOutbox,
        onApplyEvents: (events) async {
          applyCount++;
          for (final event in events) {
            projection[event.payload?['id'] as String] = event.payload;
          }
        },
      );

      // Act (First Attempt)
      await expectLater(engine.runCycle(), throwsException);

      // Assert (State after crash)
      expect(callCounter, 1);
      final pending = await pendingOutbox.pending();
      expect(pending, hasLength(1), reason: "Outbox item should persist after crash");
      expect(projection, isEmpty, reason: "onApplyEvents should not have been called");

      // 4. "Restart" app - create new engine with same storage
      engine = SyncEngine(
        deviceId: 'test-device',
        transport: transport,
        offsetStore: offsetStore,
        outbox: pendingOutbox,
        onApplyEvents: (events) async {
          applyCount++;
          for (final event in events) {
            projection[event.payload?['id'] as String] = event.payload;
          }
        },
      );
      
      // Act (Second Attempt)
      await engine.runCycle();

      // Assert (Final state)
      expect(callCounter, 2);
      final finalPending = await pendingOutbox.pending();
      expect(finalPending, isEmpty, reason: "Outbox should be empty after successful sync");
      expect(projection.length, 1, reason: "Projection should have one item");
      expect(projection['10']?['value'], 'x');
      expect(applyCount, 1, reason: "Event should only be applied once");
      final finalOffset = await offsetStore.get();
      expect(finalOffset, 10);
    });
  });
}
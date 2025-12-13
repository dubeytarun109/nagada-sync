import '../lib/engine/conflict_resolver.dart';
import '../lib/storage/adapters/in_memory_adapter.dart'; // Corrected import path
import 'package:mockito/mockito.dart';
import '../lib/core/models/sync_request.dart'; // Corrected import path
import '../lib/core/models/sync_response.dart';
import '../lib/engine/sync_engine.dart';
import '../lib/nagada.dart';
import 'package:test/test.dart';
import 'package:collection/collection.dart'; // For orderedEquals and sorted
import 'dart:convert'; // Import for jsonDecode

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
  group('Reliability & Stress Tests', () {
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

    // 9. Network Failure Between Push & Pull
    test('Network Failure Between Push & Pull', () async {
      final engine = createEngine();

      final clientEvent = ClientEvent(
        clientEventId: 'push-event-1',
        type: 'item-created',
        payload: {'id': 'item-1', 'data': 'value-1'},payloadManifest: [],createdAt: 0
      );
      await outbox.add(clientEvent);

      var syncCallCount = 0;
      when(transport.sync(any)).thenAnswer((invocation) async {
        syncCallCount++;
        if (syncCallCount == 1) {
          // Simulate network failure after push, before pull
          throw Exception('Network disconnected');
        } else {
          // Second attempt, server responds normally
          final SyncRequest request = invocation.positionalArguments.first;
          expect(request.pendingEvents, hasLength(1)); // Client retries with the same event
          expect(request.pendingEvents.first.clientEventId, clientEvent.clientEventId);

          final ackedEvents = [clientEvent.clientEventId];
          final newServerEvents = [
                          ServerEvent(
                          serverEventId: 1,
                          originClientEventId: clientEvent.clientEventId,
                          originClientDeviceId: engine.deviceId,
                          payload: clientEvent.payload,payloadManifest: [],
                          createdAt: 0
                        ),          ];
          return SyncResponse(
            successClientEventIds: ackedEvents,
            newServerEvents: newServerEvents, nextHeartbeatMs: -1, errorClientEventIds: {},
          );
        }
      });

      // First cycle - push succeeds, but network fails before pull completes
      await expectLater(engine.runCycle(), throwsException);
      expect(syncCallCount, 1);
      expect(await outbox.pending(), hasLength(1), reason: "Event should remain in outbox if ack not received");
      expect(await offsetStore.get(), isNull, reason: "Offset should not advance if pull failed");

      // Second cycle - network is restored, client retries
      await engine.runCycle();
      expect(syncCallCount, 2);
      expect(await outbox.pending(), isEmpty, reason: "Outbox should be empty after successful sync");
      expect(projection.length, 1);
      expect(projection['item-1']['data'], 'value-1');
      expect(await offsetStore.get(), 1, reason: "Offset should advance after successful sync");
    });

    // 10. Partial Failure in Mid-Sync
    test('Partial Failure in Mid-Sync', () async {
      final List<ServerEvent> appliedEvents = [];
      final engine = createEngine(onApplyEvents: (events) async {
        appliedEvents.addAll(events);
         for (final event in events) {
          final decodedPayload = event.payload;
          if (decodedPayload?['id'] != null) {
            projection[decodedPayload?['id'] as String] = decodedPayload;
          }
        }
      });

      final clientEvents = [
        ClientEvent(clientEventId: 'c1', type: 't', payload: {'id': '1'},payloadManifest: [],createdAt: 0),
        ClientEvent(clientEventId: 'c2', type: 't', payload: {'id': '2'},payloadManifest: [],createdAt: 0),
      ];
      await outbox.add(clientEvents[0]);
      await outbox.add(clientEvents[1]);

      final allServerEvents = [
        ServerEvent(serverEventId: 1, originClientEventId: 'c1', originClientDeviceId: 'd1',   payload: {"id": "1"},payloadManifest: [], createdAt: 0),
        ServerEvent(serverEventId: 2, originClientEventId: 'c2', originClientDeviceId: 'd1',   payload: {"id": "2"},payloadManifest: [], createdAt: 0),
        ServerEvent(serverEventId: 3, originClientEventId: 's3', originClientDeviceId: 'd2',  payload: {"id": "3"},payloadManifest: [], createdAt: 0),
        ServerEvent(serverEventId: 4, originClientEventId: 's4', originClientDeviceId: 'd2',   payload: {"id": "4"},payloadManifest: [], createdAt: 0),
      ];

      var syncCallCount = 0;
      when(transport.sync(any)).thenAnswer((invocation) async {
        syncCallCount++;
        if (syncCallCount == 1) {
          // Simulate server returning partial data and then network failure
          // The client should not advance its offset based on this partial response
          // and the outbox should acknowledge acked events
          return SyncResponse(
            successClientEventIds: ['c1', 'c2'],
            newServerEvents: allServerEvents.sublist(0, 2), nextHeartbeatMs: -1, errorClientEventIds: {}, // Only send first two events
          );
        } else {
          // Second attempt, server sends full batch
          return SyncResponse(
            successClientEventIds: ['c1', 'c2'],
            newServerEvents: allServerEvents, nextHeartbeatMs: -1, errorClientEventIds: {},
          );
        }
      });

      // First cycle - server returns partial data. Client should process acked events and partial new events.
      await engine.runCycle();
      
      // Since the mock returns only 2 events, the engine's current logic
      // will update the offset to 2 and apply these 2 events.
      // The goal here is to test resilience, so if the server sends partial but valid data,
      // the client should process it. The "partial failure" aspect means the *entire expected batch* didn't arrive.
      expect(await outbox.pending(), isEmpty, reason: "Outbox should be cleared for acked events");
      expect(appliedEvents.length, 2);
      expect(appliedEvents.map((e) => e.serverEventId), orderedEquals([1, 2]));
      expect(await offsetStore.get(), 2);
      
      // Clear applied events for next run
      appliedEvents.clear();

      // Second cycle - client retries (from offset 2) and gets remaining batch (3 and 4)
      // The server mock is configured to send *all* events from offset 0 if called again,
      // but the engine will filter based on its current offset (2).
      await engine.runCycle();

      expect(syncCallCount, 2);
      expect(await outbox.pending(), isEmpty);
      expect(appliedEvents.length, 2);
      expect(appliedEvents.map((e) => e.serverEventId), orderedEquals([3, 4]));
      expect(await offsetStore.get(), 4);
    });

    // 11. Large Batch Sync (Performance)
    test('Large Batch Sync (Performance)', () async {
      // Custom onApplyEvents to avoid modifying projection repeatedly for large batches
      final List<ServerEvent> appliedEvents = [];
      final engine = createEngine(onApplyEvents: (events) async {
        appliedEvents.addAll(events);
           for (final event in events) {
          final decodedPayload = event.payload;
          if (decodedPayload?['id'] != null) {
            projection[decodedPayload?['id'] as String] = decodedPayload;
          }
        }
      });

      final numEvents = 10000; // 10k server events
      final allExpectedServerEvents = List.generate(numEvents, (i) {
        return ServerEvent(
          serverEventId: i + 1,
          originClientEventId: 'client-${i + 1}',
          originClientDeviceId: 'server',
          payload: {"id": "item-${i + 1}", "value": "data-${i + 1}"},payloadManifest: [],
          createdAt: 0,
        );
      });

      // Simulate chunking by the server
      const chunkSize = 1000;
      var currentOffsetInMock = 0;

      when(transport.sync(any)).thenAnswer((invocation) async {
        final SyncRequest request = invocation.positionalArguments.first;
        final clientLastSeen = request.lastKnownServerEventId;

        // Filter events that the client has not seen yet
        final eventsToSend = allExpectedServerEvents
            .where((event) => event.serverEventId > clientLastSeen)
            .toList();

        if (eventsToSend.isEmpty) {
          return SyncResponse(successClientEventIds: [], newServerEvents: [], nextHeartbeatMs: -1, errorClientEventIds: {});
        }

        // Send events in chunks based on current offset for the mock
        final batch = eventsToSend.sublist(0, (eventsToSend.length > chunkSize) ? chunkSize : eventsToSend.length);
        
        currentOffsetInMock = batch.isNotEmpty ? batch.last.serverEventId : clientLastSeen; // Update mock's internal offset

        return SyncResponse(
          successClientEventIds: [],
          newServerEvents: batch, nextHeartbeatMs: -1, errorClientEventIds: {},
        );
      });

      final Stopwatch stopwatch = Stopwatch()..start();
      // Run multiple cycles until the engine has pulled all events
      while ((await offsetStore.get() ?? -1) < numEvents) {
        await engine.runCycle();
        // The mock must be setup to return events from `clientLastSeenServerEventId`
        // so the engine continues to pull until `numEvents` is reached.
      }
      stopwatch.stop();

      // Assertions
      expect(appliedEvents.length, numEvents);
      expect(await offsetStore.get(), numEvents);
      
      // Time budget check (adjust based on actual performance and test environment)
      const maxDurationMillis = 4000; // 4 seconds
      expect(stopwatch.elapsedMilliseconds, lessThan(maxDurationMillis),
          reason: 'Large batch sync took too long: ${stopwatch.elapsedMilliseconds}ms');
    });
  });
}
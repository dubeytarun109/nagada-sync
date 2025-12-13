import '../lib/engine/conflict_resolver.dart';
import '../lib/storage/adapters/in_memory_adapter.dart'; // Corrected import path
import 'package:mockito/mockito.dart';
import '../lib/core/models/client_event.dart'; // Keep if ClientEvent is used directly
import '../lib/core/models/sync_request.dart';
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
  group('Multi-device / Ordering Behavior Tests', () {
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
                if (event.payload?['id'] != null) {
                  projection[event.payload?['id'] as String] = event.payload;
                }
              }
            },
      );
    }

    // 12. Server Replay Order Test
    test('Server Replay Order Test', () async {
      final engine = createEngine();
      final List<ServerEvent> appliedEventsOrder = [];

      // Pass onApplyEvents in createEngine as it's final
      final customApplyEvents = (events) async {
        final sortedEvents = List<ServerEvent>.from(events)..sort((a, b) => a.serverEventId.compareTo(b.serverEventId));
        appliedEventsOrder.addAll(sortedEvents);
        // Also update projection
        for (final event in events) {
          if (jsonDecode(event.payload)['id'] != null) {
            projection[jsonDecode(event.payload)['id'] as String] = jsonDecode(event.payload);
          }
        }
      };
      
      final engineWithCustomApply = createEngine(onApplyEvents: customApplyEvents);

      // Server returns events out of order
      final serverEvents = [
        ServerEvent(serverEventId: 3, originClientEventId: 'c3', originClientDeviceId: 'd1', payload: {"id": "item-1", "data": "e3"},payloadManifest: [], createdAt: 0),
        ServerEvent(serverEventId: 1, originClientEventId: 'c1', originClientDeviceId: 'd1', payload: {"id": "item-1", "data": "e1"},payloadManifest: [], createdAt: 0),
        ServerEvent(serverEventId: 2, originClientEventId: 'c2', originClientDeviceId: 'd1', payload: {"id": "item-1", "data": "e2"},payloadManifest: [], createdAt: 0),
      ];

      when(transport.sync(any)).thenAnswer(
        (_) async => SyncResponse(
          successClientEventIds: [],
          newServerEvents: serverEvents, nextHeartbeatMs: -1, errorClientEventIds: {},
        ),
      );

      await engineWithCustomApply.runCycle();

      // Events should be applied in serverEventId order
      expect(appliedEventsOrder.map((e) => e.serverEventId), orderedEquals([1, 2, 3]));
      // The projection should reflect the state after the last applied event (event 3)
      expect(projection['item-1']['data'], 'e3');
      expect(await offsetStore.get(), 3);
    });

    // 13. Conflicting Edits From Two Devices
    test('Conflicting Edits From Two Devices', () async {
      // Custom conflict resolver that keeps a log of resolutions
      final List<Map<String, dynamic>> resolutionLog = [];
      final engine = createEngine(
        conflictResolver: TestConflictResolverWithLog(resolutionLog),
      );

      // Initial state: Item exists
      projection['item-X'] = {'id': 'item-X', 'value': 'initial'};

      // Device A updates 'item-X'
      await outbox.add(ClientEvent(clientEventId: 'clientA-1', type: 'update', payload: {'id': 'item-X', 'value': 'fromA'},payloadManifest: [],createdAt: 0));

      // Device B updates 'item-X' (happens concurrently, server sees it as 'remote')
      // Server response includes both Device A's acked event and Device B's change
      when(transport.sync(any)).thenAnswer((invocation) async {
        final SyncRequest request = invocation.positionalArguments.first;
        expect(request.pendingEvents, hasLength(1)); // Device A's event

        final serverEvents = [
          // Device B's update, which happened on the server (serverEventId 10)
          ServerEvent(serverEventId: 10, originClientEventId: 'conflicting-event', originClientDeviceId: 'deviceB', payload: {"id": "item-X", "value": "fromB"},payloadManifest: [], createdAt: 0),
          // Device A's update, which happened on the server (serverEventId 11), conflicts with B's on the same clientEventId
          ServerEvent(serverEventId: 11, originClientEventId: 'conflicting-event', originClientDeviceId: 'test-device', payload: {"id": "item-X", "value": "fromA"},payloadManifest: [], createdAt: 0),
        ];

        return SyncResponse(
          successClientEventIds: ['clientA-1'],
          newServerEvents: serverEvents, nextHeartbeatMs: -1, errorClientEventIds: {},
        );
      });

      await engine.runCycle();

      // Assertions
      expect(await outbox.pending(), isEmpty);
      expect(await offsetStore.get(), 11);
      
      // The projection should reflect the outcome of the conflict resolution.
      // Our TestConflictResolverWithLog ensures the 'remote' (last event in serverEvents list) wins for the projection.
      // In this case, 'fromA' is the last event, even though 'fromB' might have been the original 'remote' if it were applied first.
      expect(projection['item-X']['value'], 'fromA'); 
      expect(resolutionLog, hasLength(1));
      // Log will show the value of 'fromB' as local (because event 10 is considered local when event 11 comes)
      // and 'fromA' as remote (because event 11 is resolved against 10).
      expect(resolutionLog.first['local']['value'], 'fromB'); 
      expect(resolutionLog.first['remote']['value'], 'fromA'); 
    });
  });
}

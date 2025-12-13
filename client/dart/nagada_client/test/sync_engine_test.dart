import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nagada_client/core/models/client_event.dart';
import 'package:nagada_client/core/models/server_event.dart';
import 'package:nagada_client/core/models/sync_response.dart';
import 'package:nagada_client/engine/sync_engine.dart';
import 'package:nagada_client/protocol/http_sync_transport.dart';
import 'package:nagada_client/storage/offset_store.dart';
import 'package:nagada_client/storage/pending_outbox.dart';
import 'package:test/test.dart';

import 'sync_engine_test.mocks.dart';

@GenerateMocks([HttpSyncTransport, OffsetStore, PendingOutbox])
void main() {
  group('SyncEngine', () {
    late MockHttpSyncTransport mockTransport;
    late MockOffsetStore mockOffsetStore;
    late MockPendingOutbox mockPendingOutbox;
    late SyncEngine syncEngine;
    late List<ServerEvent> appliedEvents;

    setUp(() {
      mockTransport = MockHttpSyncTransport();
      mockOffsetStore = MockOffsetStore();
      mockPendingOutbox = MockPendingOutbox();
      appliedEvents = [];

      syncEngine = SyncEngine(
        deviceId: 'test-device',
        transport: mockTransport,
        offsetStore: mockOffsetStore,
        outbox: mockPendingOutbox,
        onApplyEvents: (events) async {
          appliedEvents.addAll(events);
        },
      );

      // Default stubs for a successful, empty sync cycle
      when(mockOffsetStore.get()).thenAnswer((_) async => 0);
      when(mockPendingOutbox.pending()).thenAnswer((_) async => []);
      when(mockTransport.sync(any)).thenAnswer(
          (_) async => SyncResponse(successClientEventIds: [], newServerEvents: [], nextHeartbeatMs: -1, errorClientEventIds: {}));
      when(mockOffsetStore.save(any)).thenAnswer((_) async {});
      when(mockPendingOutbox.markAsSynced(any)).thenAnswer((_) async {});
    });

    test('runCycle completes a basic sync flow', () async {
      // Arrange
      final pendingEvents = [
        ClientEvent(
            clientEventId: 'c1',
            type: 'test',
            payload: {'data': 'test'},payloadManifest: [],createdAt: 0),
      ];
      final serverEvents = [
        ServerEvent(
            serverEventId: 1,
            originClientEventId: 'c1',
            originClientDeviceId: 'test-device',
            payload: {"data": "test"},payloadManifest: [],
            createdAt: 0)
      ];
      final response = SyncResponse(
          successClientEventIds: ['c1'], newServerEvents: serverEvents, nextHeartbeatMs: -1, errorClientEventIds: {});

      when(mockOffsetStore.get()).thenAnswer((_) async => 0);
      when(mockPendingOutbox.pending()).thenAnswer((_) async => pendingEvents);
      when(mockTransport.sync(any)).thenAnswer((_) async => response);

      // Act
      await syncEngine.runCycle();

      // Assert
      verify(mockPendingOutbox.pending()).called(1);
      verify(mockOffsetStore.get()).called(1);
      verify(mockTransport.sync(any)).called(1);
      verify(mockPendingOutbox.markAsSynced(['c1'])).called(1);
      expect(appliedEvents, serverEvents);
      verify(mockOffsetStore.save(1)).called(1);
    });

    test('onApplyEvents is called with server events', () async {
      // Arrange
      final serverEvents = [
        ServerEvent(
          serverEventId: 1,
          originClientEventId: 'client-event-1',
          originClientDeviceId: 'server-device',
          payload: {"data": "from-server"},payloadManifest: [],
          createdAt: 0,
        ),
      ];
      final response =
          SyncResponse(successClientEventIds: [], newServerEvents: serverEvents, nextHeartbeatMs: -1, errorClientEventIds: {});
      when(mockTransport.sync(any)).thenAnswer((_) async => response);

      // Act
      await syncEngine.runCycle();

      // Assert
      expect(appliedEvents, serverEvents);
    });

    test('runCycle handles errorClientEventIds by marking them as synced', () async {
      // Arrange
      final pendingEvents = [
        ClientEvent(
            clientEventId: 'c1',
            type: 'test',
            payload: {'data': 'success'},createdAt: 0,
            payloadManifest: []),
        ClientEvent(
            clientEventId: 'c2',
            type: 'test',
            payload: {'data': 'error'},
            payloadManifest: [],createdAt: 0),
      ];

      final response = SyncResponse(
          successClientEventIds: ['c1'],
          newServerEvents: [],
          nextHeartbeatMs: -1,
          errorClientEventIds: {'c2': 'Conflict detected'});

      when(mockOffsetStore.get()).thenAnswer((_) async => 0);
      when(mockPendingOutbox.pending()).thenAnswer((_) async => pendingEvents);
      when(mockTransport.sync(any)).thenAnswer((_) async => response);

      // Act
      await syncEngine.runCycle();

      // Assert
      final verification = verify(mockPendingOutbox.markAsSynced(captureAny));
      final allMarkedIds = verification.captured.expand((e) => e as List<String>).toList();
      expect(allMarkedIds, containsAll(['c1', 'c2']));
    });
  });
}
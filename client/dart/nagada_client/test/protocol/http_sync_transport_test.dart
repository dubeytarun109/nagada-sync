import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import '../../lib/core/models/sync_request.dart';
import '../../lib/core/models/sync_response.dart';
import '../../lib/protocol/http_sync_transport.dart';
import '../../lib/core/models/server_event.dart';
 import 'package:test/test.dart';

import 'http_sync_transport_test.mocks.dart';

@GenerateMocks([http.Client])
void main() {
  group('HttpSyncTransport', () {
    late MockClient mockClient;
    late HttpSyncTransport transport;
    final uri = Uri.parse('https://example.com/sync');

    setUp(() {
      mockClient = MockClient();
      transport =
          HttpSyncTransport(serverUrl: uri.toString(), client: mockClient);
    });

    final syncRequest = SyncRequest(lastKnownServerEventId: 0, pendingEvents: [], deviceId: 'device-123');

    test('Sends correct payload format', () async {
      final request = SyncRequest(
        lastKnownServerEventId: 10,
       deviceId: 'device-123', pendingEvents: [
          // For this test, we assume an empty list, but a real scenario
          // would need a valid ClientEvent with toJson implemented.
        ],
      );

      final responseBody =
          jsonEncode(SyncResponse(newServerEvents: [], successClientEventIds: [], nextHeartbeatMs: -1, errorClientEventIds: {}).toJson());

      when(mockClient.post(
        uri,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => http.Response(responseBody, 200));

      await transport.sync(request);

      verify(mockClient.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(request.toJson()),
      )).called(1);
    });

    test('Handles empty response body safely', () async {
      when(mockClient.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => http.Response('', 200));

      final response = await transport.sync(syncRequest);

      expect(response.successClientEventIds, isEmpty);
      expect(response.newServerEvents, isEmpty);
    });

    test('Parses server events correctly', () async {
      final serverEvents = [
        ServerEvent(
          serverEventId: 1,
          originClientDeviceId: 'device-id-1',
          originClientEventId: 'client-id-1',
          payload: {'key': 'value'},payloadManifest: [],
          createdAt: 0,
        ),
      ];
      final syncResponse =
          SyncResponse(newServerEvents: serverEvents, successClientEventIds: [], nextHeartbeatMs: -1, errorClientEventIds: {});
      final responseBody = jsonEncode(syncResponse.toJson());

      when(mockClient.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => http.Response(responseBody, 200));

      final response = await transport.sync(syncRequest);

      expect(response.newServerEvents, hasLength(1));
      expect(response.newServerEvents.first.serverEventId, 1);
      expect(response.newServerEvents.first.payload, {'key': 'value'});
    });

    test('Throws exception on non-200 status code', () {
      when(mockClient.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => http.Response('Server Error', 500));

      expect(
        () => transport.sync(syncRequest),
        throwsA(isA<SyncTransportException>().having(
          (e) => e.toString(),
          'message',
          'SyncTransportException: Failed to sync with server (Status: 500, Error: Server Error)',
        )),
      );
    });
  });
}
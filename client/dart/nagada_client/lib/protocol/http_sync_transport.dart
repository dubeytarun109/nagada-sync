import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import '../core/models/sync_request.dart';
import '../core/models/sync_response.dart';


/// An exception thrown when a sync operation fails at the transport level.
class SyncTransportException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic error;

  SyncTransportException(this.message, {this.statusCode, this.error});

  @override
  String toString() =>
      'SyncTransportException: $message (Status: $statusCode, Error: $error)';
}

/// Defines the interface for a transport layer for the sync protocol.
abstract class SyncTransport {
  Future<SyncResponse> sync(SyncRequest request);
}


/// Implements the Nagada sync protocol over HTTP.
class HttpSyncTransport implements SyncTransport {
  final _log = Logger('HttpSyncTransport');
  final Uri _serverUrl;
  final http.Client _client;

  HttpSyncTransport({required String serverUrl, http.Client? client})
      : _serverUrl = Uri.parse(serverUrl),
        _client = client ?? http.Client();

  /// Sends a [SyncRequest] to the server and returns a [SyncResponse].
  @override
  Future<SyncResponse> sync(SyncRequest request) async {
    _log.fine('Sending SyncRequest: ${request.toJson()}');
    http.Response response;
    try {
      response = await _client.post(
        _serverUrl,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(request.toJson()),
      );
    } catch (e) {
      _log.severe('Failed to connect to server', e);
      throw SyncTransportException('Failed to connect to server', error: e);
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        _log.warning('Received empty response from server.');
        return SyncResponse(successClientEventIds: [], newServerEvents: [], nextHeartbeatMs: -1, errorClientEventIds: {});
      }
      try {
        final syncResponse = SyncResponse.fromJson(json.decode(response.body));
        _log.fine('Received SyncResponse: ${syncResponse.toJson()}');
        return syncResponse;
      } catch (e) {
        _log.severe('Failed to decode server response: ${response.body}', e);
        throw SyncTransportException('Failed to decode server response', error: e, statusCode: response.statusCode);
      }
    } else {
      _log.severe('Failed to sync with server. Status: ${response.statusCode}, Body: ${response.body}');
      throw SyncTransportException('Failed to sync with server',
          statusCode: response.statusCode, error: response.body);
    }
  }
}

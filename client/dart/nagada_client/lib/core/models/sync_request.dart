import 'package:json_annotation/json_annotation.dart';
import 'client_event.dart';

part 'sync_request.g.dart';

/// Data Transfer Object for a sync request sent to the server.
@JsonSerializable(explicitToJson: true)
class SyncRequest {
  final String deviceId;
  final int lastKnownServerEventId;
  final List<ClientEvent> pendingEvents;
  // Optional fields from the spec, can be added as needed.
  // final String? protocolVersion;
  // final String? userId;

  SyncRequest({
    required this.deviceId,
    required this.lastKnownServerEventId,
    required this.pendingEvents,
  });

  /// Creates a new `SyncRequest` from a JSON map.
  factory SyncRequest.fromJson(Map<String, dynamic> json) =>
      _$SyncRequestFromJson(json);

  /// Converts this `SyncRequest` to a JSON map.
  Map<String, dynamic> toJson() => _$SyncRequestToJson(this);
}
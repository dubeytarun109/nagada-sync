import 'package:json_annotation/json_annotation.dart';

part 'server_event.g.dart';

/// Represents a globally ordered event that has been committed by the server.
@JsonSerializable()
class ServerEvent {
  /// Server-generated, globally unique, and monotonically increasing event ID.
  final int serverEventId;
  final String originClientEventId;
  /// The ID of the device that originated the event.
  final String originClientDeviceId;
  final Map<String, dynamic> ? payload;
  final List<String> ? payloadManifest; 
  final int createdAt;

  ServerEvent({
    required this.serverEventId,
    required this.originClientEventId,
    required this.originClientDeviceId,
    this.payload,
    this.payloadManifest,
    required this.createdAt,
  });

  /// Creates a new `ServerEvent` from a JSON map.
  factory ServerEvent.fromJson(Map<String, dynamic> json) =>
      _$ServerEventFromJson(json);

  /// Converts this `ServerEvent` to a JSON map.
  @override
  Map<String, dynamic> toJson() => _$ServerEventToJson(this);
}
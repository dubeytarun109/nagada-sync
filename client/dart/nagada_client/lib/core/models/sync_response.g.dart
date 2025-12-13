// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SyncResponse _$SyncResponseFromJson(Map<String, dynamic> json) => SyncResponse(
  successClientEventIds: (json['successClientEventIds'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  newServerEvents: (json['newServerEvents'] as List<dynamic>)
      .map((e) => ServerEvent.fromJson(e as Map<String, dynamic>))
      .toList(),
  nextHeartbeatMs: (json['nextHeartbeatMs'] as num).toInt(),
  errorClientEventIds: Map<String, String>.from(
    json['errorClientEventIds'] as Map,
  ),
);

Map<String, dynamic> _$SyncResponseToJson(
  SyncResponse instance,
) => <String, dynamic>{
  'successClientEventIds': instance.successClientEventIds,
  'newServerEvents': instance.newServerEvents.map((e) => e.toJson()).toList(),
  'errorClientEventIds': instance.errorClientEventIds,
  'nextHeartbeatMs': instance.nextHeartbeatMs,
};

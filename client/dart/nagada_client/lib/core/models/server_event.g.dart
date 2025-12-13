// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ServerEvent _$ServerEventFromJson(Map<String, dynamic> json) => ServerEvent(
  serverEventId: (json['serverEventId'] as num).toInt(),
  originClientEventId: json['originClientEventId'] as String,
  originClientDeviceId: json['originClientDeviceId'] as String,
  payload: json['payload'] as Map<String, dynamic>?,
  payloadManifest: (json['payloadManifest'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  createdAt: (json['createdAt'] as num).toInt(),
);

Map<String, dynamic> _$ServerEventToJson(ServerEvent instance) =>
    <String, dynamic>{
      'serverEventId': instance.serverEventId,
      'originClientEventId': instance.originClientEventId,
      'originClientDeviceId': instance.originClientDeviceId,
      'payload': instance.payload,
      'payloadManifest': instance.payloadManifest,
      'createdAt': instance.createdAt,
    };

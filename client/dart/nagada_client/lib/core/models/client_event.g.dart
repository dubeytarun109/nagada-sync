// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'client_event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ClientEvent _$ClientEventFromJson(Map<String, dynamic> json) => ClientEvent(
  clientEventId: json['clientEventId'] as String,
  type: json['type'] as String,
  payload: json['payload'] as Map<String, dynamic>?,
  payloadManifest: (json['payloadManifest'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  createdAt: (json['createdAt'] as num).toInt(),
);

Map<String, dynamic> _$ClientEventToJson(ClientEvent instance) =>
    <String, dynamic>{
      'clientEventId': instance.clientEventId,
      'type': instance.type,
      'payload': instance.payload,
      'payloadManifest': instance.payloadManifest,
      'createdAt': instance.createdAt,
    };

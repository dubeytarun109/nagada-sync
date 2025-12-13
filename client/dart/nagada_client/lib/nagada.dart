/// A client-side SDK for the Nagada Sync Protocol, enabling offline-first
/// data synchronization for Dart and Flutter applications.
library;

export 'api/nagada_client.dart';
export 'core/models/client_event.dart';
export 'core/models/server_event.dart';
export 'engine/sync_engine.dart' show ApplyEventsCallback;
export 'protocol/http_sync_transport.dart';
export 'storage/adapters/in_memory_adapter.dart';
export 'storage/offset_store.dart';
export 'storage/pending_outbox.dart';
export 'core/models/local_projection_store.dart';


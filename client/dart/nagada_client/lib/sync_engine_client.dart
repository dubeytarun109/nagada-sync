// Minimal Nagada client reference library
library nagada_client;

import 'outbox.dart';
import 'storage/projection_store.dart';
import 'sync_engine.dart';

export 'outbox.dart';
export 'storage/projection_store.dart';
export 'sync_engine.dart';

class SyncEngineClient {
  final SyncEngine syncEngine;
  final Outbox outbox;
  final ProjectionStore projections;

  SyncEngineClient({
    required this.syncEngine,
    required this.outbox,
    required this.projections,
  });

  void start() => syncEngine.start();
  void stop() => syncEngine.stop();
}

import 'dart:async';

import 'package:logging/logging.dart';

import 'conflict_resolver.dart';
import '../core/models/server_event.dart';
import '../core/models/sync_request.dart';
import '../protocol/http_sync_transport.dart';
import '../storage/offset_store.dart';
import '../storage/pending_outbox.dart';

/// A callback function to apply server events to the local application state.
typedef ApplyEventsCallback = Future<void> Function(List<ServerEvent> events);

/// The core orchestrator for the synchronization process.
class SyncEngine {
  final _log = Logger('SyncEngine');
  final String deviceId;
  final HttpSyncTransport transport;
  final OffsetStore offsetStore;
  final PendingOutbox outbox;
  final ConflictResolver conflictResolver;
  final ApplyEventsCallback onApplyEvents;

  bool _isSyncing = false;
  final _syncController = StreamController<void>.broadcast();

  SyncEngine({
    required this.deviceId,
    required this.transport,
    required this.offsetStore,
    required this.outbox,
    required this.onApplyEvents,
    ConflictResolver? conflictResolver,
  }) : conflictResolver = conflictResolver ?? ConflictResolver();

  /// A stream that emits an event whenever a sync cycle completes.
  Stream<void> get onSyncComplete => _syncController.stream;

  /// Triggers a single synchronization cycle.
  ///
  /// This involves sending pending local events to the server (push) and
  /// fetching new remote events from the server (pull).
  Future<void> runCycle() async {
    if (_isSyncing) {
      _log.info('Sync cycle already in progress. Skipping.');
      return;
    }
    _isSyncing = true;
    _log.info('Starting sync cycle...');

    try {
      final pendingEvents = await outbox.pending();
      final lastKnownId = await offsetStore.get() ?? -1;
      _log.fine('Found ${pendingEvents.length} pending events. Last known server ID: $lastKnownId');

      final request = SyncRequest(
        deviceId: deviceId,
        lastKnownServerEventId: lastKnownId,
        pendingEvents: pendingEvents,
      );

      final response = await transport.sync(request);
      _log.fine('Received sync response. Success: ${response.successClientEventIds.length}, Errors: ${response.errorClientEventIds.length}, New: ${response.newServerEvents.length}');

      final eventsToMark = [
        ...response.successClientEventIds,
        ...response.errorClientEventIds.keys,
      ];

      if (eventsToMark.isNotEmpty) {
        await outbox.markAsSynced(eventsToMark);
        _log.fine('Marked ${eventsToMark.length} events as synced.');
      }

      // Filter out events that are older than or equal to the last known ID
      final newServerEvents = response.newServerEvents
          .where((event) => event.serverEventId > lastKnownId)
          .toList();
      if (newServerEvents.length < response.newServerEvents.length) {
        _log.fine('Filtered out ${response.newServerEvents.length - newServerEvents.length} old server events.');
      }

      final resolvedEvents = conflictResolver.resolve(newServerEvents);
      if (resolvedEvents.isNotEmpty) {
        _log.fine('Applying ${resolvedEvents.length} resolved server events.');
        await onApplyEvents(resolvedEvents);
      }

      final maxId = resolvedEvents
          .map((e) => e.serverEventId)
          .fold(lastKnownId, (max, id) => id > max ? id : max);

      if (maxId > lastKnownId) {
        await offsetStore.save(maxId);
        _log.fine('Updated last known server ID to $maxId');
      }
      
      _syncController.add(null);
      _log.info('Sync cycle finished successfully.');
    } catch (e, s) {
      _log.severe('Error during sync cycle', e, s);
      rethrow;
    } finally {
      _isSyncing = false;
    }
  }

  void dispose() {
    _log.info('Disposing SyncEngine.');
    _syncController.close();
  }
}
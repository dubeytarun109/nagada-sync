import 'dart:async';
import 'dart:math';

import 'package:nagada_client/core/models/sync_request.dart';
import 'package:nagada_client/nagada.dart';
import 'package:nagada_client/storage/failed_server_event_store.dart';
import 'package:nagada_client/storage/projection_store.dart';



/// Status of the sync manager.
enum SyncStatus {
  idle,
  syncing,
  backoff,
  offline,
}

abstract class SyncManager {
  void start();
  void stop();
  void forceSync();
  bool get isRunning;
  bool get isSyncing;
  int get currentBackoffMs;
  SyncStatus get status;
  Stream<void> get onHeartbeat;
}

/// Manages the offline-first sync protocol (Nagada-Pulse).
class NagadaSyncManager implements SyncManager {
  final String deviceId;
  final PendingOutbox outbox;
  final OffsetStore offsetStore;
  final LocalProjectionStore projectionStore;
  final FailedEventStore failedEventStore;

  final SyncTransport transport;

  // Configuration
  final int minHeartbeatMs;
  final int maxBackoffMs;
  final void Function(String)? debugLog;

  // Event Hooks
  void Function(ServerEvent)? onProjectionUpdated;
  void Function(SyncStatus)? onSyncStatusChanged;
  void Function(Object)? onSyncError;

  // Internal State
  bool _isRunning = false;
  Timer? _heartbeatTimer;
  int _currentBackoffMs = 1000;
  bool _isSyncing = false;
  SyncStatus _status = SyncStatus.idle;
  final _heartbeatController = StreamController<void>.broadcast();

  NagadaSyncManager({
    required this.deviceId,
    required this.outbox,
    required this.offsetStore,
    required this.projectionStore,
    required this.transport,
    required this.failedEventStore,
    this.minHeartbeatMs = 1000,
    this.maxBackoffMs = 60000,
    this.debugLog,
  });

  @override
  bool get isRunning => _isRunning;

  @override
  bool get isSyncing => _isSyncing;

  @override
  int get currentBackoffMs => _currentBackoffMs;

  @override
  SyncStatus get status => _status;

  @override
  Stream<void> get onHeartbeat => _heartbeatController.stream;

  /// Starts the continuous heartbeat loop.
  void start() {
    _currentBackoffMs = 1000;
    if (_isRunning) return;
    debugLog?.call('Starting SyncManager...');
    _isRunning = true;
    _scheduleNextHeartbeat(0);
  }

  /// Stops the heartbeat loop.
  void stop() {
    debugLog?.call('Stopping SyncManager...');
    _isRunning = false;
    _heartbeatTimer?.cancel();
    _updateStatus(SyncStatus.idle);
  }

  @override
  void forceSync() {
    if (_isSyncing) {
      debugLog?.call('Cannot force sync: a sync operation is already in progress.');
      return;
    }
    if (!_isRunning) {
      debugLog?.call('Cannot force sync: the sync manager is not running.');
      return;
    }
    debugLog?.call('Forcing sync...');
    _scheduleNextHeartbeat(0);
  }

  void _scheduleNextHeartbeat(int delayMs) {
    if (!_isRunning) return;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer(Duration(milliseconds: delayMs), _performSystole);
  }

  Future<void> _performSystole() async {
    if (!_isRunning || _isSyncing) return;

    _isSyncing = true;
    _updateStatus(SyncStatus.syncing);

    try {
      debugLog?.call('Performing heartbeat sync...');
      // 1. Prepare Systole
      final pendingEvents = await outbox.pending();
      final lastKnownId = await offsetStore.get()??0;

      debugLog?.call('Systole: lastId=$lastKnownId, pending=${pendingEvents.length}');

      final request = SyncRequest(
        deviceId: deviceId,
        lastKnownServerEventId: lastKnownId,
        pendingEvents: pendingEvents,
      );
      debugLog?.call('calling /sync');

      // 2. Transport Exchange
      final response = await transport.sync(request);

      // 3. Process Diastole
      debugLog?.call('Diastole: acked=${response.successClientEventIds.length}, new=${response.newServerEvents.length}, next=${response.nextHeartbeatMs}ms');

      // Handle Acknowledgements
      if (response.successClientEventIds.isNotEmpty) {
        // Find the original ClientEvent objects that were acknowledged.
        final ackedClientEvents = pendingEvents.where(
          (event) => response.successClientEventIds.contains(event.clientEventId)
        ).toList();

        // Apply these client events to the local projection store
        for (final event in ackedClientEvents) {
          await projectionStore.applyClientEvent(event);
        }

        await outbox.markAsSynced(response.successClientEventIds);
      }

      // Handle Errors
      if (response.errorClientEventIds.isNotEmpty) {
        for (final entry in response.errorClientEventIds.entries) {
          final eventId = entry.key;
          final reason = entry.value;
          final failedEvent = pendingEvents.firstWhere((event) => event.clientEventId == eventId);
          await failedEventStore.addFailedEvent(failedEvent, reason);
        }
        await outbox.markAsSynced(response.errorClientEventIds.keys.toList());
      }
      
      // Apply New Events (Ordered)
      if (response.newServerEvents.isNotEmpty) {
        // Ensure strictly ordered by ID
        response.newServerEvents.sort((a, b) => a.serverEventId.compareTo(b.serverEventId));

        for (final event in response.newServerEvents) {
          // Idempotency check
          if (event.serverEventId > lastKnownId) {
            // Apply to projection
            await projectionStore.applyServerEvent(event);
            // Update cursor immediately after apply to ensure consistency
            await offsetStore.save(event.serverEventId);
            
            onProjectionUpdated?.call(event); // This line is correct, the previous comment was misleading.
          }
        }
      }

      // Reset backoff on success
      _currentBackoffMs = 1000;
      
      // Schedule next heartbeat
      final nextDelay = max(response.nextHeartbeatMs, minHeartbeatMs);
      _isSyncing = false;
      _updateStatus(SyncStatus.idle);
      _scheduleNextHeartbeat(nextDelay);

    } catch (e,s) {
      debugLog?.call('Sync Error: $e $s');
      _isSyncing = false;
      onSyncError?.call(e);

      // Exponential Backoff
      _updateStatus(SyncStatus.backoff);
      final delay = _currentBackoffMs;
      _currentBackoffMs = min(_currentBackoffMs * 2, maxBackoffMs);
      
      debugLog?.call('Backing off for $delay ms');
      _scheduleNextHeartbeat(delay); // This line was causing the error.
    }finally{
          _heartbeatController.add(null);
        _isSyncing = false;
    }
  }

  void _updateStatus(SyncStatus status) {
    _status = status;
    onSyncStatusChanged?.call(status);
  }


 }


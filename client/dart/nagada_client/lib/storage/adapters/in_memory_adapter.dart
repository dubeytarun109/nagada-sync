import 'package:logging/logging.dart';

import '../../core/models/client_event.dart';
import '../offset_store.dart';
import '../pending_outbox.dart';

class InMemoryAdapter implements OffsetStore, PendingOutbox {
  final _log = Logger('InMemoryAdapter');
  int? _offset;
  final List<ClientEvent> _outbox = [];

  @override
  Future<int?> get() {
    _log.fine('Getting last known server event ID: $_offset');
    return Future.value(_offset);
  }

  @override
  Future<void> save(int offset) {
    _log.fine('Saving last known server event ID: $offset');
    _offset = offset;
    return Future.value();
  }

  @override
  Future<void> add(ClientEvent event) {
    _log.fine('Adding event to outbox: ${event.clientEventId}');
    _outbox.add(event);
    return Future.value();
  }

  @override
  Future<List<ClientEvent>> pending() {
    _log.fine('Retrieving ${_outbox.length} pending events from outbox');
    // Create a new list before sorting to avoid mutating the original.
    final sortedList = _outbox.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return Future.value(List.unmodifiable(sortedList));
  }

  @override
  Future<void> markAsSynced(List<String> clientEventIds) {
    _log.fine('Marking ${clientEventIds.length} events as synced');
    _outbox.removeWhere((event) => clientEventIds.contains(event.clientEventId));
    return Future.value();
  }
}

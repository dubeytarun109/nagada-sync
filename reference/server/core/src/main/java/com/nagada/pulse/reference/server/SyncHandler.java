package com.nagada.pulse.reference.server;

import com.nagada.pulse.protocol.ServerEvent;
import com.nagada.pulse.protocol.SyncRequest;
import com.nagada.pulse.protocol.SyncResponse;
import java.util.List;
import java.util.stream.Collectors;

/**
 * Core sync handler: orchestrates systole + diastole for a single sync heartbeat.
 */
public class SyncHandler {

    private final SystoleProcessor systole;
    private final DiastoleProcessor diastole;

    public SyncHandler(EventStore eventStore, OffsetStore offsetStore) {
        this.systole = new SystoleProcessor(eventStore, offsetStore);
        this.diastole = new DiastoleProcessor(eventStore, offsetStore);
    }

    /**
     * Handle a sync request: process pending events (systole), fetch new events (diastole).
     */
    public SyncResponse handle(SyncRequest request) {
        // Systole: append pending events
        List<ServerEvent> appendedEvents = systole.process(request.deviceId, request.pendingEvents);

        // Diastole: fetch new events
        List<ServerEvent> newEvents = diastole.process(request.deviceId, request.lastKnownServerEventId);

        // Combine appended events and new events, ensuring uniqueness and preserving order
        java.util.Set<ServerEvent> uniqueEvents = new java.util.LinkedHashSet<>(appendedEvents);
        uniqueEvents.addAll(newEvents);
        List<ServerEvent> allNewEvents = new java.util.ArrayList<>(uniqueEvents);

        // Build response
        List<String> ackedClientEventIds = request.pendingEvents != null
            ? request.pendingEvents.stream()
                .map(e -> e.getClientEventId())
                .collect(java.util.stream.Collectors.toList())
            : java.util.List.of();

        return new SyncResponse(ackedClientEventIds, allNewEvents);
    }
}

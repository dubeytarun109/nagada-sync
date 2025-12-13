package com.nagada.pulse.reference.server;

import com.nagada.pulse.protocol.ClientEvent;
import com.nagada.pulse.protocol.ServerEvent;
import com.nagada.pulse.protocol.SyncRequest;
import com.nagada.pulse.protocol.SyncResponse;
import com.nagada.pulse.reference.server.EventConflictResolver;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;
import lombok.extern.slf4j.Slf4j;

/**
 * Core sync handler: orchestrates systole + diastole for a single sync heartbeat.
 */
@Slf4j
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
        log.info("Handling sync request for device: {}", request.getDeviceId());

        // Diastole: fetch new events first
        log.debug("Diastole phase: fetching new events since server event ID {}.", request.getLastKnownServerEventId());
        List<ServerEvent> newEvents = diastole.process(request.getDeviceId(), request.getLastKnownServerEventId());
        log.debug("Diastole phase: found {} new events.", newEvents.size());

        // Resolve conflicts before processing systole
        EventConflictResolver.ConflictResolutionResult resolutionResult =
                EventConflictResolver.resolveConflicts(request.getPendingEvents(), newEvents, false);
        log.debug("Conflict resolution: {} successful, {} failed.", resolutionResult.successClientEventIds.size(), resolutionResult.errorClientEventIds.size());

        // Filter for successful events to be persisted
        List<ClientEvent> successfulClientEvents = request.getPendingEvents() == null ? new ArrayList<>() : request.getPendingEvents().stream()
                .filter(ce -> resolutionResult.successClientEventIds.contains(ce.getClientEventId()))
                .collect(Collectors.toList());

        // Systole: append only the successful pending events
        log.debug("Systole phase: processing {} successful pending events.", successfulClientEvents.size());
        List<ServerEvent> appendedEvents = systole.process(request.getDeviceId(), successfulClientEvents);
        log.debug("Systole phase: appended {} events.", appendedEvents.size());

        // Combine appended events and new events, ensuring uniqueness and preserving order
        Set<ServerEvent> uniqueEvents = new LinkedHashSet<>(appendedEvents);
        uniqueEvents.addAll(newEvents);
        List<ServerEvent> newServerEvents = new ArrayList<>(uniqueEvents);

        SyncResponse response = new SyncResponse(
                resolutionResult.successClientEventIds,
                newServerEvents,
                -1,
                resolutionResult.errorClientEventIds
        );
        log.info("Finished handling sync request for device: {}. Sending {} events.", request.getDeviceId(), newServerEvents.size());
        return response;
    }
}

package com.nagada.pulse.reference.server;

import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

import com.nagada.pulse.protocol.ServerEvent;
import com.nagada.pulse.protocol.ClientEvent;
import com.nagada.pulse.protocol.SyncRequest;
import com.nagada.pulse.protocol.SyncResponse;
import java.util.stream.Collectors;

import reactor.core.publisher.Mono;

/**
 * Reactive core sync handler: orchestrates systole + diastole for a single sync heartbeat.
 */
public class ReactiveSyncHandler {

    private final ReactiveSystoleProcessor systole;
    private final ReactiveDiastoleProcessor diastole;

    public ReactiveSyncHandler(ReactiveEventStore eventStore, ReactiveOffsetStore offsetStore) {
        this.systole = new ReactiveSystoleProcessor(eventStore, offsetStore);
        this.diastole = new ReactiveDiastoleProcessor(eventStore, offsetStore);
    }

    /**
     * Handle a sync request reactively.
     */
    public Mono<SyncResponse> handle(SyncRequest request) {
        // Diastole first to fetch new events
        return diastole.process(request.getDeviceId(), request.getLastKnownServerEventId())
            .flatMap(newEvents -> {
                // Now, resolve conflicts before saving
                EventConflictResolver.ConflictResolutionResult resolutionResult =
                    EventConflictResolver.resolveConflicts(request.getPendingEvents(), newEvents, false);

                // Filter for successful events to be persisted
                List<ClientEvent> successfulClientEvents = request.getPendingEvents() == null ? new ArrayList<>() : request.getPendingEvents().stream()
                    .filter(ce -> resolutionResult.successClientEventIds.contains(ce.getClientEventId()))
                    .collect(Collectors.toList());

                // Systole: process only the successful (non-conflicting) pending events
                return systole.process(request.getDeviceId(), successfulClientEvents)
                    .map(appendedEvents -> {
                        // Combine appended events and new events, ensuring uniqueness and preserving order
                        Set<ServerEvent> uniqueEvents = new LinkedHashSet<>(appendedEvents);
                        uniqueEvents.addAll(newEvents);
                        List<ServerEvent> newServerEvents = new ArrayList<>(uniqueEvents);

                        return new SyncResponse(
                                resolutionResult.successClientEventIds,
                                newServerEvents,
                                15000,
                                resolutionResult.errorClientEventIds
                        );
                    });
            });
        }
    }
    
package com.nagada.pulse.reference.server;

import com.nagada.pulse.protocol.ClientEvent;
import com.nagada.pulse.protocol.ServerEvent;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;
import java.util.Collections;
import java.util.List;

/**
 * Reactive Systole (upstroke) processor: handles incoming client events.
 */
public class ReactiveSystoleProcessor {

    private final ReactiveEventStore eventStore;
    private final ReactiveOffsetStore offsetStore;

    public ReactiveSystoleProcessor(ReactiveEventStore eventStore, ReactiveOffsetStore offsetStore) {
        this.eventStore = eventStore;
        this.offsetStore = offsetStore;
    }

    /**
     * Process incoming client events: append new ones, return list of appended server events.
     */
    public Mono<List<ServerEvent>> process(String deviceId, List<ClientEvent> pendingEvents) {
        if (pendingEvents == null || pendingEvents.isEmpty()) {
            return Mono.just(Collections.emptyList());
        }

        return Flux.fromIterable(pendingEvents)
            .concatMap(clientEvent ->
                eventStore.exists(deviceId, clientEvent.getClientEventId())
                    .flatMap(exists -> {
                        if (!exists) {
                            return eventStore.append(deviceId, clientEvent)
                                .flatMap(storedEvent ->
                                    offsetStore.update(deviceId, storedEvent.getServerEventId())
                                        .thenReturn(storedEvent)
                                );
                        } else {
                            return Mono.empty();
                        }
                    })
            )
            .collectList();
    }
}
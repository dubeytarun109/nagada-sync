package com.nagada.pulse.reference.server;

import com.nagada.pulse.protocol.ServerEvent;
import reactor.core.publisher.Mono;
import java.util.List;

/**
 * Reactive Diastole (downstroke) processor: fetches new server events since last known offset.
 */
public class ReactiveDiastoleProcessor {

    private final ReactiveEventStore eventStore;
    private final ReactiveOffsetStore offsetStore;

    public ReactiveDiastoleProcessor(ReactiveEventStore eventStore, ReactiveOffsetStore offsetStore) {
        this.eventStore = eventStore;
        this.offsetStore = offsetStore;
    }

    /**
     * Process diastole: fetch new events since the given offset, update stored offset.
     */
    public Mono<List<ServerEvent>> process(String deviceId, long lastKnownServerEventId) {
        return offsetStore.update(deviceId, lastKnownServerEventId)
            .thenMany(eventStore.listAfter(lastKnownServerEventId))
            .collectList();
    }
}
package com.nagada.pulse.reference.server;

import com.nagada.pulse.protocol.ServerEvent;
import java.util.List;
import lombok.extern.slf4j.Slf4j;

/**
 * Diastole (downstroke) processor: fetches new server events since last known offset.
 * Returns events the client has not yet seen, updates the client's offset.
 */
@Slf4j
public class DiastoleProcessor {

    private final EventStore eventStore;
    private final OffsetStore offsetStore;

    public DiastoleProcessor(EventStore eventStore, OffsetStore offsetStore) {
        this.eventStore = eventStore;
        this.offsetStore = offsetStore;
    }

    /**
     * Process diastole: fetch new events since the given offset, update stored offset.
     */
    public List<ServerEvent> process(String deviceId, long lastKnownServerEventId) {
        log.debug("Processing diastole for device: {} from server event ID: {}", deviceId, lastKnownServerEventId);

        // Fetch new events
        offsetStore.update(deviceId, lastKnownServerEventId);
        log.trace("Updated offset for device {} to {}", deviceId, lastKnownServerEventId);
        
        List<ServerEvent> newEvents = eventStore.listAfter(lastKnownServerEventId);
        log.debug("Found {} new events for device: {}", newEvents.size(), deviceId);

        return newEvents;
    }
}

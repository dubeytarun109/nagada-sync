package com.nagada.pulse.reference.server;

import com.nagada.pulse.protocol.ServerEvent;
import java.util.List;

/**
 * Diastole (downstroke) processor: fetches new server events since last known offset.
 * Returns events the client has not yet seen, updates the client's offset.
 */
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

        // Fetch new events
        offsetStore.update(deviceId, lastKnownServerEventId);
        List<ServerEvent> newEvents = eventStore.listAfter(lastKnownServerEventId);

        return newEvents;
    }
}

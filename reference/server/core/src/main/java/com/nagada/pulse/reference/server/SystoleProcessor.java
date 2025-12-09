package com.nagada.pulse.reference.server;

import com.nagada.pulse.protocol.ClientEvent;
import com.nagada.pulse.protocol.ServerEvent;
import java.util.ArrayList;
import java.util.List;

/**
 * Systole (upstroke) processor: handles incoming client events.
 * Appends new events to the store, returns list of newly stored server events.
 */
public class SystoleProcessor {

    private final EventStore eventStore;
    private final OffsetStore offsetStore;

    public SystoleProcessor(EventStore eventStore, OffsetStore offsetStore) {
        this.eventStore = eventStore;
        this.offsetStore = offsetStore;
    }

    /**
     * Process incoming client events: append new ones, return list of appended server events.
     */
    public List<ServerEvent> process(String deviceId, List<ClientEvent> pendingEvents) {

        List<ServerEvent> appendedEvents = new ArrayList<>();

        if (pendingEvents == null || pendingEvents.isEmpty()) {
            return appendedEvents; // nothing incoming, nothing appended
        }

        for (ClientEvent clientEvent : pendingEvents) {

            boolean exists = eventStore.exists(deviceId, clientEvent.getClientEventId());

            if (!exists) {
                // ID is new → Append to global event log
                ServerEvent storedEvent = eventStore.append(deviceId, clientEvent);
                appendedEvents.add(storedEvent);
                offsetStore.update(deviceId, storedEvent.serverEventId);
            }

            // if exists → silently ignore (idempotent behavior)
        }

        return appendedEvents;
    }
}

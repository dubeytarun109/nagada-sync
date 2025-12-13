package com.nagada.pulse.reference.server;

import com.nagada.pulse.protocol.ClientEvent;
import com.nagada.pulse.protocol.ServerEvent;
import java.util.ArrayList;
import java.util.List;
import lombok.extern.slf4j.Slf4j;

/**
 * Systole (upstroke) processor: handles incoming client events.
 * Appends new events to the store, returns list of newly stored server events.
 */
@Slf4j
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
        log.debug("Processing {} pending events from device: {}", pendingEvents.size(), deviceId);
        List<ServerEvent> appendedEvents = new ArrayList<>();

        if (pendingEvents == null || pendingEvents.isEmpty()) {
            return appendedEvents; // nothing incoming, nothing appended
        }

        for (ClientEvent clientEvent : pendingEvents) {
            boolean exists = eventStore.exists(deviceId, clientEvent.getClientEventId());
            log.trace("Event {} from device {} exists? {}", clientEvent.getClientEventId(), deviceId, exists);

            if (!exists) {
                // ID is new → Append to global event log
                log.debug("Appending new event {} from device {}", clientEvent.getClientEventId(), deviceId);
                ServerEvent storedEvent = eventStore.append(deviceId, clientEvent);
                appendedEvents.add(storedEvent);
                offsetStore.update(deviceId, storedEvent.getServerEventId());
            } else {
                log.trace("Ignoring duplicate event {} from device {}", clientEvent.getClientEventId(), deviceId);
            }

            // if exists → silently ignore (idempotent behavior)
        }
        log.debug("Finished processing pending events for device: {}. Appended {} new events.", deviceId, appendedEvents.size());
        return appendedEvents;
    }
}

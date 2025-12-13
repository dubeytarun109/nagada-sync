package com.nagada.pulse.reference.server;

import com.nagada.pulse.protocol.ClientEvent;
import com.nagada.pulse.protocol.ServerEvent;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;
import lombok.extern.slf4j.Slf4j;

/**
 * In-memory implementation of EventStore for reference and testing.
 */
@Slf4j
public class InMemoryEventStore implements EventStore {

    private final AtomicLong nextId = new AtomicLong(1);
    private final List<ServerEvent> events = new ArrayList<>();
    private final Map<String, Map<String, Boolean>> seenClientEvents = new ConcurrentHashMap<>();

    @Override
    public ServerEvent append(String deviceId, ClientEvent clientEvent) {
        long id = nextId.getAndIncrement();
        log.debug("Appending event from device: {} with clientEventId: {} as serverEventId: {}", deviceId, clientEvent.getClientEventId(), id);
        ServerEvent event = new ServerEvent(id, clientEvent.getClientEventId(), deviceId, clientEvent.getPayload(),clientEvent.getPayloadManifest(), clientEvent.getCreatedAt());
        event.payloadManifest = clientEvent.getPayloadManifest();
        events.add(event);
        
        // Track that we've seen this client event
        seenClientEvents
            .computeIfAbsent(deviceId, k -> new ConcurrentHashMap<>())
            .put(clientEvent.getClientEventId(), true);
        
        return event;
    }

    @Override
    public List<ServerEvent> listAfter(long afterId) {
        log.debug("Listing events after serverEventId: {}", afterId);
        List<ServerEvent> result = new ArrayList<>();
        for (ServerEvent event : events) {
            if (event.getServerEventId() > afterId) {
                result.add(event);
            }
        }
        log.debug("Found {} events after serverEventId: {}", result.size(), afterId);
        return result;
    }

    @Override
    public boolean exists(String deviceId, String originClientEventId) {
        Map<String, Boolean> deviceSeenEvents = seenClientEvents.get(deviceId);
        boolean exists = deviceSeenEvents != null && deviceSeenEvents.containsKey(originClientEventId);
        log.trace("Checking existence of clientEventId: {} for device: {}. Exists: {}", originClientEventId, deviceId, exists);
        return exists;
    }

    public void clear() {
        log.warn("Clearing all events from InMemoryEventStore.");
        nextId.set(1);
        events.clear();
        seenClientEvents.clear();
    }
}

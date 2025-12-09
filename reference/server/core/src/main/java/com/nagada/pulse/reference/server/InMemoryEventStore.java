package com.nagada.pulse.reference.server;

import com.nagada.pulse.protocol.ClientEvent;
import com.nagada.pulse.protocol.ServerEvent;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;

/**
 * In-memory implementation of EventStore for reference and testing.
 */
public class InMemoryEventStore implements EventStore {

    private final AtomicLong nextId = new AtomicLong(1);
    private final List<ServerEvent> events = new ArrayList<>();
    private final Map<String, Map<String, Boolean>> seenClientEvents = new ConcurrentHashMap<>();

    @Override
    public ServerEvent append(String deviceId, ClientEvent clientEvent) {
        long id = nextId.getAndIncrement();
        ServerEvent event = new ServerEvent(id, clientEvent.getClientEventId(), deviceId, new String(clientEvent.getPayload()), System.currentTimeMillis());
        events.add(event);
        
        // Track that we've seen this client event
        seenClientEvents
            .computeIfAbsent(deviceId, k -> new ConcurrentHashMap<>())
            .put(clientEvent.getClientEventId(), true);
        
        return event;
    }

    @Override
    public List<ServerEvent> listAfter(long afterId) {
        List<ServerEvent> result = new ArrayList<>();
        for (ServerEvent event : events) {
            if (event.serverEventId > afterId) {
                result.add(event);
            }
        }
        return result;
    }

    @Override
    public boolean exists(String deviceId, String originClientEventId) {
        Map<String, Boolean> deviceSeenEvents = seenClientEvents.get(deviceId);
        return deviceSeenEvents != null && deviceSeenEvents.containsKey(originClientEventId);
    }

    public void clear() {
        nextId.set(1);
        events.clear();
        seenClientEvents.clear();
    }
}

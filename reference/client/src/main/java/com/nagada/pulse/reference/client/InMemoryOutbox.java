package com.nagada.pulse.reference.client;

import com.nagada.pulse.protocol.ClientEvent;

import java.util.*;
import java.util.concurrent.CopyOnWriteArrayList;

/**
 * In-memory implementation of PendingOutbox.
 * Maintains a list of events awaiting sync and provides deduplication.
 */
public class InMemoryOutbox implements PendingOutbox {
    private final List<ClientEvent> pendingEvents = new CopyOnWriteArrayList<>();

    @Override
    public void add(String clientEventId, byte[] payload,List<String> payloadManifest, long createdAt) {
        ClientEvent event = new ClientEvent(clientEventId, "default-type", payload, payloadManifest,createdAt);
        // Avoid duplicates if the same clientEventId already exists
        boolean exists = pendingEvents.stream()
                .anyMatch(e -> e.getClientEventId().equals(clientEventId));
        if (!exists) {
            pendingEvents.add(event);
        }
    }

    @Override
    public List<ClientEvent> drainPending() {
        List<ClientEvent> result = new ArrayList<>(pendingEvents);
        pendingEvents.clear();
        return result;
    }

    @Override
    public boolean hasPending() {
        return !pendingEvents.isEmpty();
    }

    /**
     * Returns a copy of pending events without draining.
     */
    public List<ClientEvent> getPending() {
        return new ArrayList<>(pendingEvents);
    }
}

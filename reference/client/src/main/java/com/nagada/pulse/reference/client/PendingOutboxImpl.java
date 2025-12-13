package com.nagada.pulse.reference.client;

import com.nagada.pulse.protocol.ClientEvent;
import java.util.ArrayList;
import java.util.List;

/**
 * Outbox: queues events to send in the next sync.
 */
public class PendingOutboxImpl implements PendingOutbox {

    private final List<ClientEvent> pending = new ArrayList<>();

    /**
     * Add an event to the pending queue.
     */
    @Override
    public void add(String clientEventId, byte[] payload,List<String> payloadManifest ,long createdAt) {
        pending.add(new ClientEvent(clientEventId, "default-type", payload,payloadManifest,createdAt));
    }

    /**
     * Get all pending events and clear the queue.
     */
    public List<ClientEvent> drainPending() {
        List<ClientEvent> result = new ArrayList<>(pending);
        pending.clear();
        return result;
    }

    /**
     * Check if there are pending events.
     */
    public boolean hasPending() {
        return !pending.isEmpty();
    }
}

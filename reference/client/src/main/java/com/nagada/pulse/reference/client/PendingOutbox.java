package com.nagada.pulse.reference.client;

import com.nagada.pulse.protocol.ClientEvent;
import java.util.List;

/**
 * Abstraction for an outbox holding client-originated events that need to be
 * processed by the server. This is intentionally minimal so different
 * implementations (in-memory, durable DB-backed) can be provided.
 */
public interface PendingOutbox {
    /**
     * Add a new pending event to the outbox. Implementations may choose to
     * deduplicate by `clientEventId`.
     *
     * @param clientEventId client-provided id for idempotency
     * @param payload opaque event payload bytes as string
     */
    void add(String clientEventId, byte[] payload,List<String> payloadManifest,long createdAt);

    /**
     * Drain and return all pending events currently stored in the outbox.
     * The returned list should contain the corresponding protocol-level
     * {@link ClientEvent} instances for processing by the Systole processor.
     */
    List<ClientEvent> drainPending();

    /**
     * Returns true if there are pending items in the outbox.
     */
    boolean hasPending();
}

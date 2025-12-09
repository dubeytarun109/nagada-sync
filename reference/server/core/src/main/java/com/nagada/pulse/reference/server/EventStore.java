package com.nagada.pulse.reference.server;

import com.nagada.pulse.protocol.ClientEvent;
import com.nagada.pulse.protocol.ServerEvent;
import java.util.List;

/**
 * Pluggable interface for persisting and querying server events.
 */
public interface EventStore {
    /**
     * Append a client event and return the stored ServerEvent with assigned server ID.
     */
    ServerEvent append(String deviceId, ClientEvent clientEvent);

    /**
     * List server events with id > afterId, ordered ascending.
     */
    List<ServerEvent> listAfter(long afterId);

    /**
     * Check if an event with the given client event ID has been stored for this device.
     */
    boolean exists(String deviceId, String clientEventId);
}

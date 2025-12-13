package com.nagada.pulse.protocol;

import java.util.List;

/**
 * Sync request from client: pending events + last known server event ID.
 */
public class SyncRequest {
    public String deviceId;
    public List<ClientEvent> pendingEvents;
    public long lastKnownServerEventId;

    public SyncRequest() {
    }

    public SyncRequest(String deviceId, List<ClientEvent> pendingEvents, long lastKnownServerEventId) {
        this.deviceId = deviceId;
        this.pendingEvents = pendingEvents;
        this.lastKnownServerEventId = lastKnownServerEventId;
    }
    public String getDeviceId() {
        return deviceId;
    }
    public List<ClientEvent> getPendingEvents() {
        return pendingEvents;
    }
    public long getLastKnownServerEventId() {
        return lastKnownServerEventId;
    }
    
}

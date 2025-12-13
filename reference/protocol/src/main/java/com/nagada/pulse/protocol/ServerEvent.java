package com.nagada.pulse.protocol;

import java.util.List;

/**
 * Server-side event: persisted with server-assigned ID and metadata.
 * Includes the ID of the client event that originated it, and the ID of the device that created it.
 */
public class ServerEvent {
    public long serverEventId;
    public String originClientEventId;
    public String originClientDeviceId;
    public List<String> payloadManifest; 
    public byte[] payload;
    public long createdAt;

    public ServerEvent(long serverEventId, String originClientEventId, String originClientDeviceId, 
        byte[] payload,List<String> payloadManifest, long createdAt) {
        this.serverEventId = serverEventId;
        this.originClientEventId = originClientEventId;
        this.originClientDeviceId = originClientDeviceId; 
        this.payload = payload;
        this.payloadManifest = payloadManifest;
        this.createdAt = createdAt;
    }

    public ServerEvent() {
        // for deserialization
    }
    public long getServerEventId() {
        return serverEventId;
    }
    public String getOriginClientEventId() {
        return originClientEventId;
    }
    public String getOriginClientDeviceId() {
        return originClientDeviceId;
    }
    public byte[] getPayload() {
        return payload;
    }

    public List<String> getPayloadManifest() {
        return payloadManifest;
    }
    
    public long getCreatedAt() {
        return createdAt;
    }
}

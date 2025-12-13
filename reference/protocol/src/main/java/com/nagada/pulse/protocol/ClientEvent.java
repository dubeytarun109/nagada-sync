package com.nagada.pulse.protocol;

import java.util.List;

/**
 * Minimal client-side event: opaque payload + client-assigned ID for idempotency.
 */
public class ClientEvent {
    private String clientEventId;
    private String type;
    public List<String> payloadManifest; 
    private byte[] payload;
    public long createdAt;

    public ClientEvent(String clientEventId, String type , byte[] payload ,List<String> payloadManifest ,long createdAt) {
        this.clientEventId = clientEventId;
        this.type = type;
        this.payload = payload;
        this.payloadManifest = payloadManifest;
        this.createdAt = createdAt;
    }

    private ClientEvent() {
        // for deserialization
    }

    public String getType() {
        return type;
    }

    public String getClientEventId() {
        return clientEventId;
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

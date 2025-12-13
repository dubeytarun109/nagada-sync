package com.nagada.pulse.protocol;

import java.util.List;
import java.util.Map;

/**
 * Sync response from server: acknowledgments + new server events.
 */
public class SyncResponse {
    public List<String> successClientEventIds;
    public List<ServerEvent> newServerEvents;
    public int nextHeartbeatMs;
    public Map<String,String> errorClientEventIds;
    public SyncResponse() {
    }

    public SyncResponse(
        List<String> successClientEventIds, 
        List<ServerEvent> newServerEvents,
        int nextHeartbeatMs,
        Map<String,String> errorClientEventIds) {
        this.successClientEventIds = successClientEventIds;
        this.newServerEvents = newServerEvents;
        this.nextHeartbeatMs=nextHeartbeatMs;
        this.errorClientEventIds=errorClientEventIds;
    }
    //add getters 
    public List<String> getSuccessClientEventIds() {
        return successClientEventIds;
    }
    public List<ServerEvent> getNewServerEvents() {
        return newServerEvents;
    }
    public int getNextHeartbeatMs() {
        return nextHeartbeatMs;
    }
    public Map<String, String> getErrorClientEventIds() {
        return errorClientEventIds;
    }
}

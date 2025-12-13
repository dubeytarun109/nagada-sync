package com.nagada.pulse.reference.server.http;

import com.nagada.pulse.protocol.SyncRequest;
import com.nagada.pulse.protocol.SyncResponse;
import com.nagada.pulse.reference.server.SyncHandler;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

/**
 * REST controller that exposes the sync protocol over HTTP.
 * Maps incoming HTTP JSON requests to SyncRequest messages and delegates
 * to the core SyncHandler for protocol processing.
 */
@Slf4j
@RestController
@RequestMapping("/sync")
public class SyncController {

    private final SyncHandler syncHandler;

    @Autowired
    public SyncController(SyncHandler syncHandler) {
        this.syncHandler = syncHandler;
    }

    /**
     * Handles a full Minimum Viable Sync Cycle (MVSC) in a single HTTP request/response.
     * <p>
     * This endpoint bundles the client-to-server and server-to-client phases:
     * <p>
     * <b>Client -> Server:</b>
     * <ul>
     *     <li><b>1. Hello/Identity:</b> The {@link SyncRequest} contains client identity and its last known server event ID.</li>
     *     <li><b>3. Pending Outbox Push:</b> The request includes new events created by the client.</li>
     *     <li><b>5. Acknowledgement:</b> The {@code lastKnownServerEventId} implicitly acknowledges events up to that point from the previous cycle.</li>
     * </ul>
     *
     * <b>Server -> Client:</b>
     * <ul>
     *     <li><b>2. Server Delta Stream:</b> The {@link SyncResponse} returns authoritative events the client is missing.</li>
     *     <li><b>4. Commit + Tail:</b> The response confirms which client events were committed and may include those newly committed events from other clients (the "tail").</li>
     * </ul>
     *
     * @param request The sync request from the client.
     * @return The sync response from the server.
     */
    @PostMapping
    public SyncResponse sync(@RequestBody SyncRequest request) {
        log.info("Received sync request from device: {}", request.getDeviceId());
        log.debug("Sync request details: {}", request);
        SyncResponse response = syncHandler.handle(request);
        log.info("Sending sync response to device: {}. {} new events.", request.getDeviceId(), response.getNewServerEvents().size());
        log.debug("Sync response details: {}", response);
        return response;
    }
}

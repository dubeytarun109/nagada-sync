package com.nagada.pulse.reference.server.http;


import com.nagada.pulse.protocol.ClientEvent;
import com.nagada.pulse.protocol.SyncRequest;
import com.nagada.pulse.protocol.SyncResponse;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.http.ResponseEntity;

import java.nio.charset.StandardCharsets;
import java.util.Collections;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Tests that replaying the same sync request does not result in duplicate events.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
public class IdempotencyTest {

    @Autowired
    private TestRestTemplate restTemplate;

    @Test
    void replayingSyncRequestDoesNotDuplicateEvents() {
        // 1. Send a request with a pending event.
        ClientEvent event = new ClientEvent("idempotent-ce-1", "user.updated", "{}".getBytes(StandardCharsets.UTF_8),List.of() ,0L  );
        SyncRequest request = new SyncRequest("client-idempotent", List.of(event), 0L);

        ResponseEntity<SyncResponse> firstResponse = restTemplate.postForEntity("/sync", request, SyncResponse.class);
        assertEquals(1, firstResponse.getBody().getNewServerEvents().size());
        long firstServerEventId = firstResponse.getBody().getNewServerEvents().get(0).getServerEventId();

        // 2. Send the exact same pending event again, but with an advanced lastKnownServerEventId.
        SyncRequest secondRequest = new SyncRequest(request.getDeviceId(), request.getPendingEvents(), firstServerEventId);
        ResponseEntity<SyncResponse> secondResponse = restTemplate.postForEntity("/sync", secondRequest, SyncResponse.class);

        // 3. Verify no new events were created (because lastKnownServerEventId was advanced)
        // and the original acknowledgement is returned.
        assertTrue(secondResponse.getBody().getNewServerEvents().isEmpty(), "Server should not return duplicate events when client has acknowledged them");
        assertTrue(secondResponse.getBody().getSuccessClientEventIds().contains("idempotent-ce-1"));

        // Verify the server event ID from the acknowledgement matches the original one.
        // Note: This requires the SyncHandler to be updated to return committed event mappings.
        // For now, we verify no new events are created.
    }

    @Test
    void repeatingSyncWithNoNewEventsHasNoSideEffects() {
        // 1. Perform an initial successful sync.
        SyncRequest initialRequest = new SyncRequest("client-repeat", Collections.emptyList(), 0L);
        ResponseEntity<SyncResponse> initialResponse = restTemplate.postForEntity("/sync", initialRequest, SyncResponse.class);
        long lastKnownId = initialResponse.getBody().getNewServerEvents().stream().mapToLong(e -> e.getServerEventId()).max().orElse(0L);

        // 2. Immediately perform a second sync with the same request data (no new events).
        SyncRequest repeatRequest = new SyncRequest("client-repeat", Collections.emptyList(), lastKnownId);
        ResponseEntity<SyncResponse> repeatResponse = restTemplate.postForEntity("/sync", repeatRequest, SyncResponse.class);

        // 3. Verify the server does not create duplicate events.
        // 4. Verify the server's response is minimal/empty (no new events).
        assertNotNull(repeatResponse.getBody());
        assertTrue(repeatResponse.getBody().getNewServerEvents().isEmpty(), "Second sync should return no new events");
        assertTrue(repeatResponse.getBody().getSuccessClientEventIds().isEmpty());
    }
}
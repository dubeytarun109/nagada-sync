package com.nagada.pulse.reference.server.http;


import com.nagada.pulse.protocol.ClientEvent;
import com.nagada.pulse.protocol.SyncRequest;
import com.nagada.pulse.protocol.SyncResponse;
import com.nagada.pulse.reference.server.InMemoryEventStore;
import com.nagada.pulse.reference.server.InMemoryOffsetStore;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;
import java.util.stream.IntStream;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Tests that a single client can complete a full sync cycle with the server.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)

public class BasicSyncTest {

    @Autowired
    private TestRestTemplate restTemplate;

    @Autowired
    private InMemoryEventStore eventStore; // Inject the in-memory event store

    @Autowired
    private InMemoryOffsetStore offsetStore; // Inject the in-memory offset store

    @BeforeEach
    void setUp() {
        eventStore.clear(); // Clear the event store before each test
        offsetStore.clear(); // Clear the offset store before each test
    }

    @Test
    void singleClientCanCompleteFullSyncCycle() {
        // 1. Client starts with no state.
        String clientEventId = "ce-" + UUID.randomUUID();
        ClientEvent event = new ClientEvent(clientEventId, 
            "item.created", "{\"text\":\"Hello\"}".getBytes(StandardCharsets.UTF_8),List.of() 
             ,0L );

        // 2. Client sends a sync request with one pending event.
        SyncRequest request = new SyncRequest("client-1", List.of(event), 0L);
        ResponseEntity<SyncResponse> responseEntity = restTemplate.postForEntity("/sync", request, SyncResponse.class);

        // 3. Server commits the event and returns it.
        assertEquals(HttpStatus.OK, responseEntity.getStatusCode());
        SyncResponse response = responseEntity.getBody();
        assertNotNull(response);

        // 4. Client projection is validated.
        assertEquals(1, response.getNewServerEvents().size());
        assertEquals(clientEventId, response.getNewServerEvents().get(0).getOriginClientEventId());
        assertEquals(1L, response.getNewServerEvents().get(0).getServerEventId());
        assertTrue(response.getSuccessClientEventIds().contains(clientEventId));
    }

    @Test
    void clientHandlesOfflineEventBurst() {
        // 1. Simulate a client generating multiple (e.g., 10) events while offline.
        List<ClientEvent> pendingEvents = IntStream.range(0, 10)
                .mapToObj(i -> new ClientEvent("ce-" + i, "item.created", "{}".getBytes(StandardCharsets.UTF_8),List.of()  ,0L ))
                .collect(Collectors.toList());

        // 2. Client comes online and sends a single sync request with all pending events.
        SyncRequest request = new SyncRequest("client-2", pendingEvents, 0L);
        ResponseEntity<SyncResponse> responseEntity = restTemplate.postForEntity("/sync", request, SyncResponse.class);

        assertEquals(HttpStatus.OK, responseEntity.getStatusCode());
        SyncResponse response = responseEntity.getBody();
        assertNotNull(response);

        // 3. Verify the server assigns continuous, ordered IDs to these events.
        assertEquals(10, response.getNewServerEvents().size());
        for (int i = 0; i < 10; i++) {
            assertEquals(i + 1L, response.getNewServerEvents().get(i).getServerEventId());
        }

        // 4. Verify the client receives the committed events and updates its state correctly.
        assertEquals(10, response.getSuccessClientEventIds().size());
        assertTrue(response.getSuccessClientEventIds().contains("ce-0"));
        assertTrue(response.getSuccessClientEventIds().contains("ce-9"));
    }
}
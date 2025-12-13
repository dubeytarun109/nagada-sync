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
import org.springframework.http.ResponseEntity;

import java.nio.charset.StandardCharsets;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Tests that two clients can sync concurrently without data corruption.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
public class TwoClientsTest {

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
    void concurrentClientsCanSyncWithoutCorruption() {
        // 1. Client A syncs and creates an event.
        ClientEvent eventA = new ClientEvent("client-a-ce-1", "msg.sent", "{\"text\":\"Hi from A\"}".getBytes(StandardCharsets.UTF_8),List.of()  ,0L );
        SyncRequest requestA = new SyncRequest("client-A", List.of(eventA), 0L);
        ResponseEntity<SyncResponse> responseA = restTemplate.postForEntity("/sync", requestA, SyncResponse.class);
        assertEquals(1, responseA.getBody().getNewServerEvents().size());
        long eventA_ServerId = responseA.getBody().getNewServerEvents().get(0).getServerEventId();
        assertEquals(1L, eventA_ServerId);

        // 2. Client B syncs, sending its own event and fetching updates from A.
        ClientEvent eventB = new ClientEvent("client-b-ce-1", "msg.sent", "{\"text\":\"Hi from B\"}".getBytes(StandardCharsets.UTF_8),List.of() ,0L  );
        SyncRequest requestB = new SyncRequest("client-B", List.of(eventB), 0L);
        ResponseEntity<SyncResponse> responseB = restTemplate.postForEntity("/sync", requestB, SyncResponse.class);

        // Client B should receive its own event back, plus the event from Client A.
        assertEquals(2, responseB.getBody().getNewServerEvents().size());
        assertTrue(responseB.getBody().getNewServerEvents().stream().anyMatch(e -> e.getServerEventId() == eventA_ServerId));
        assertTrue(responseB.getBody().getNewServerEvents().stream().anyMatch(e -> e.getOriginClientEventId().equals("client-b-ce-1")));
    }

    @Test
    void clientCorrectlyReconcilesLateServerEvents() {
        // 1. Client A starts with a known state (e.g., has seen event 1).
        concurrentClientsCanSyncWithoutCorruption(); // Run the first test to create 2 events.

        // 2. Client A syncs again, expecting events after ID 1.
        SyncRequest requestA2 = new SyncRequest("client-A", List.of(), 1L);
        ResponseEntity<SyncResponse> responseA2 = restTemplate.postForEntity("/sync", requestA2, SyncResponse.class);

        // 3. Verify Client A receives the event from Client B (which should be event 2).
        assertEquals(1, responseA2.getBody().getNewServerEvents().size(), "Client A should receive the event from Client B");
        assertEquals(2L, responseA2.getBody().getNewServerEvents().get(0).getServerEventId());
    }
}
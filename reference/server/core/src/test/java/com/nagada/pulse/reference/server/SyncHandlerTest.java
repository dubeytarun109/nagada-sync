package com.nagada.pulse.reference.server;

import com.nagada.pulse.protocol.ClientEvent;
import com.nagada.pulse.protocol.SyncRequest;
import com.nagada.pulse.protocol.SyncResponse;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

public class SyncHandlerTest {

    private SyncHandler syncHandler;
    private InMemoryEventStore eventStore;
    private InMemoryOffsetStore offsetStore;

    @BeforeEach
    void setUp() {
        eventStore = new InMemoryEventStore();
        offsetStore = new InMemoryOffsetStore();
        syncHandler = new SyncHandler(eventStore, offsetStore);
    }

    @Test
    void testConflict_ManifestOverlap() {
        // Given an existing event in the store with a specific manifest
        ClientEvent existingEvent = new ClientEvent("existing-1", "type", "data".getBytes(), List.of("resource-A"),0L);
        eventStore.append("other-device", existingEvent);

        // When a client tries to sync a new event with an overlapping manifest
        ClientEvent conflictingEvent = new ClientEvent("new-1", "type", "data".getBytes(), List.of("resource-A"),0L);
        SyncRequest request = new SyncRequest("device-1", List.of(conflictingEvent), 0L);

        SyncResponse response = syncHandler.handle(request);

        // Then the new event should be marked as an error
        assertThat(response.getErrorClientEventIds()).containsKey("new-1");
        assertThat(response.getErrorClientEventIds().get("new-1")).contains("manifest overlaps");

        // And it should not be in the success list
        assertThat(response.getSuccessClientEventIds()).doesNotContain("new-1");

        // And the server should return the existing conflicting event
        assertThat(response.getNewServerEvents()).anyMatch(se -> se.getOriginClientEventId().equals("existing-1"));

        // And the conflicting event should not have been saved to the event store
        assertThat(eventStore.exists(request.getDeviceId(), conflictingEvent.getClientEventId())).isFalse();
    }
}
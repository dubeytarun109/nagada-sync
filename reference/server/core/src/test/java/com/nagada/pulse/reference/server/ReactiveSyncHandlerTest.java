package com.nagada.pulse.reference.server;

import com.nagada.pulse.protocol.ClientEvent;
import com.nagada.pulse.protocol.ServerEvent;
import com.nagada.pulse.protocol.SyncRequest;
import com.nagada.pulse.protocol.SyncResponse;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import reactor.test.StepVerifier;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

class ReactiveSyncHandlerTest {

    private InMemoryReactiveEventStore eventStore;
    private InMemoryReactiveOffsetStore offsetStore;
    private ReactiveSyncHandler syncHandler;

    @BeforeEach
    void setUp() {
        eventStore = new InMemoryReactiveEventStore();
        offsetStore = new InMemoryReactiveOffsetStore();
        syncHandler = new ReactiveSyncHandler(eventStore, offsetStore);
    }

    @Test
    void testSystole_AppendEvents() {
        // Given a client with one pending event
        ClientEvent clientEvent = new ClientEvent("ce-1", "test-type", "data".getBytes(),List.of(),0L);
        SyncRequest request = new SyncRequest("dev-1", List.of(clientEvent), 0L);

        // When handling the sync
        StepVerifier.create(syncHandler.handle(request))
                .assertNext(response -> {
                    // Then the event is acked
                    assertThat(response.getSuccessClientEventIds()).containsExactly("ce-1");
                    
                    // And returned as a new server event
                    assertThat(response.getNewServerEvents()).hasSize(1);
                    ServerEvent se = response.getNewServerEvents().get(0);
                    assertThat(se.getOriginClientEventId()).isEqualTo("ce-1");
                    assertThat(se.getOriginClientDeviceId()).isEqualTo("dev-1");
                })
                .verifyComplete();
    }

    @Test
    void testDiastole_FetchNewEvents() {
        // Given an existing event from another device
        ClientEvent ce1 = new ClientEvent("ce-other", "type", "data".getBytes(),List.of() ,0L  );
        eventStore.append("other-dev", ce1).block();

        // When dev-1 syncs with lastKnownId = 0
        SyncRequest request = new SyncRequest("dev-1", null, 0L);

        StepVerifier.create(syncHandler.handle(request))
                .assertNext(response -> {
                    // Then it receives the existing event
                    assertThat(response.getNewServerEvents()).hasSize(1);
                    assertThat(response.getNewServerEvents().get(0).getOriginClientEventId()).isEqualTo("ce-other");
                })
                .verifyComplete();
    }

    @Test
    void testIdempotency_DuplicateUpload() {
        ClientEvent ce1 = new ClientEvent("ce-1", "type", "data".getBytes(),List.of() ,0L  );
        
        // 1. First sync: uploads the event
        syncHandler.handle(new SyncRequest("dev-1", List.of(ce1), 0L)).block();
        
        // 2. Second sync: re-uploads the same event (e.g. client didn't get ack)
        StepVerifier.create(syncHandler.handle(new SyncRequest("dev-1", List.of(ce1), 0L)))
                .assertNext(response -> {
                    // It should still be acked
                    assertThat(response.getSuccessClientEventIds()).contains("ce-1");
                    
                    // It should be returned in newServerEvents (fetched via Diastole since it exists in store)
                    assertThat(response.getNewServerEvents()).hasSize(1);
                    assertThat(response.getNewServerEvents().get(0).getOriginClientEventId()).isEqualTo("ce-1");
                })
                .verifyComplete();
    }

    @Test
    void testOffsetUpdate() {
        ClientEvent ce1 = new ClientEvent("ce-1", "type", "data".getBytes(),List.of()  ,0L );
        eventStore.append("dev-1", ce1).block(); // This creates ServerEvent ID 1

        // Sync with lastKnown = 1
        SyncRequest request = new SyncRequest("dev-1", null, 1L);
        
        StepVerifier.create(syncHandler.handle(request))
                .expectNextCount(1)
                .verifyComplete();

        // Verify offset store was updated
        StepVerifier.create(offsetStore.get("dev-1"))
                .expectNext(1L)
                .verifyComplete();
    }

    @Test
    void testConflict_ManifestOverlap() {
        // Given an existing event in the store with a specific manifest
        ClientEvent existingEvent = new ClientEvent("existing-1", "type", "data".getBytes(), List.of("resource-A"),0L);
        eventStore.append("other-device", existingEvent).block();

        // When a client tries to sync a new event with an overlapping manifest
        ClientEvent conflictingEvent = new ClientEvent("new-1", "type", "data".getBytes(), List.of("resource-A"),0L);
        SyncRequest request = new SyncRequest("device-1", List.of(conflictingEvent), 0L);

        StepVerifier.create(syncHandler.handle(request))
                .assertNext(response -> {
                    // Then the new event should be marked as an error
                    assertThat(response.getErrorClientEventIds()).containsKey("new-1");
                    
                    // And it should not be in the success list
                    assertThat(response.getSuccessClientEventIds()).doesNotContain("new-1");
                    
                    // And the conflicting event should not have been saved to the event store
                    StepVerifier.create(eventStore.exists(request.getDeviceId(), conflictingEvent.getClientEventId()))
                        .expectNext(false)
                        .verifyComplete();
                })
                .verifyComplete();
    }
}
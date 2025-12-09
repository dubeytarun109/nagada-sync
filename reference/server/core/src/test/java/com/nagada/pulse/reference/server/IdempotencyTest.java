package com.nagada.pulse.reference.server;

import com.nagada.pulse.protocol.ClientEvent;
import com.nagada.pulse.protocol.SyncRequest;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

public class IdempotencyTest {

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
    void shouldNotAppendDuplicateClientEvents() {
        // Given a client event
        ClientEvent clientEvent = new ClientEvent("client-event-1", "test", "payload".getBytes());
        SyncRequest request = new SyncRequest("device-1", List.of(clientEvent), 0L);

        // When I send it once
        syncHandler.handle(request);
        assertThat(eventStore.listAfter(0)).hasSize(1);

        // When I send it again
        syncHandler.handle(request);

        // Then the event store still has only one event
        assertThat(eventStore.listAfter(0)).hasSize(1);
    }
}

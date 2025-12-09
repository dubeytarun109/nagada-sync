package com.nagada.pulse.reference.client;

import com.nagada.pulse.protocol.ClientEvent;
import com.nagada.pulse.protocol.ServerEvent;
import com.nagada.pulse.protocol.SyncRequest;
import com.nagada.pulse.protocol.SyncResponse;
import org.junit.jupiter.api.Test;

import java.util.ArrayList;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

public class SyncEngineTest {

    @Test
    void buildSyncRequestShouldDrainOutboxAndGetLastKnownEventId() {
        // Given
        InMemoryOutbox outbox = new InMemoryOutbox();
        InMemoryProjectionStore projectionStore = new InMemoryProjectionStore();
        SyncEngine syncEngine = new SyncEngine("device-1", outbox, projectionStore, (SyncEngine.SyncTransport) null);
        outbox.add("c1", "p".getBytes());
        projectionStore.recordEvents(List.of(new ServerEvent(10L, "c","d", "p", 0)));

        // When
        SyncRequest request = syncEngine.buildSyncRequest();

        // Then
        assertThat(request.getDeviceId()).isEqualTo("device-1");
        assertThat(request.getPendingEvents()).hasSize(1);
        assertThat(request.getPendingEvents().get(0).getClientEventId()).isEqualTo("c1");
        assertThat(request.getLastKnownServerEventId()).isEqualTo(10L);
        assertThat(outbox.isEmpty()).isTrue();
    }

    // Helper classes for testing
    private static class InMemoryOutbox implements PendingOutbox {
        private final List<ClientEvent> events = new ArrayList<>();

        @Override
        public void add(String clientEventId, byte[] payload) {
            events.add(new ClientEvent(clientEventId, "default-type", payload));
        }

        @Override
        public List<ClientEvent> drainPending() {
            List<ClientEvent> drained = new ArrayList<>(events);
            events.clear();
            return drained;
        }

        @Override
        public boolean hasPending() {
            return !events.isEmpty();
        }

        public boolean isEmpty() {
            return events.isEmpty();
        }
    }

    private static class InMemoryProjectionStore implements LocalProjectionStore {
        private long lastKnownServerEventId = 0;
        private final List<ServerEvent> receivedEvents = new ArrayList<>();


        @Override
        public long getLastKnownServerEventId() {
            return lastKnownServerEventId;
        }

        @Override
        public void recordEvents(List<ServerEvent> events) {
            for (ServerEvent event : events) {
                receivedEvents.add(event);
                if (event.getServerEventId() > lastKnownServerEventId) {
                    lastKnownServerEventId = event.getServerEventId();
                }
            }
        }

        @Override
        public List<ServerEvent> getAllEvents() {
            return new ArrayList<>(receivedEvents);
        }
    }
}
package com.nagada.pulse.reference.server;

import com.nagada.pulse.protocol.ClientEvent;
import com.nagada.pulse.protocol.ServerEvent;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

public class OrderingTest {

    private InMemoryEventStore eventStore;

    @BeforeEach
    void setUp() {
        eventStore = new InMemoryEventStore();
        // Append some events
        eventStore.append("device-1", new ClientEvent("c1", "t", "p".getBytes()));
        eventStore.append("device-1", new ClientEvent("c2", "t", "p".getBytes()));
        eventStore.append("device-1", new ClientEvent("c3", "t", "p".getBytes()));
    }

    @Test
    void listAfterShouldReturnEventsInAscendingOrderOfId() {
        // When
        List<ServerEvent> events = eventStore.listAfter(0);

        // Then
        assertThat(events).hasSize(3);
        assertThat(events.get(0).getServerEventId()).isEqualTo(1L);
        assertThat(events.get(1).getServerEventId()).isEqualTo(2L);
        assertThat(events.get(2).getServerEventId()).isEqualTo(3L);
    }

    @Test
    void listAfterShouldRespectOffset() {
        // When
        List<ServerEvent> events = eventStore.listAfter(1);

        // Then
        assertThat(events).hasSize(2);
        assertThat(events.get(0).getServerEventId()).isEqualTo(2L);
        assertThat(events.get(1).getServerEventId()).isEqualTo(3L);
    }

    @Test
    void listAfterShouldReturnEmptyListWhenOffsetIsAtLatest() {
        // When
        List<ServerEvent> events = eventStore.listAfter(3);

        // Then
        assertThat(events).isEmpty();
    }
}
package com.nagada.pulse.reference.server;

import com.nagada.pulse.protocol.ClientEvent;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

public class OffsetTest {

    private SystoleProcessor systoleProcessor;
    private InMemoryEventStore eventStore;
    private InMemoryOffsetStore offsetStore;

    @BeforeEach
    void setUp() {
        eventStore = new InMemoryEventStore();
        offsetStore = new InMemoryOffsetStore();
        systoleProcessor = new SystoleProcessor(eventStore, offsetStore);
    }

    @Test
    void shouldAdvanceOffsetWhenProcessingEvents() {
        // Given
        String deviceId = "device-1";
        ClientEvent clientEvent1 = new ClientEvent("c1", "t", "p".getBytes());
        ClientEvent clientEvent2 = new ClientEvent("c2", "t", "p".getBytes());

        // When
        systoleProcessor.process(deviceId, List.of(clientEvent1, clientEvent2));

        // Then
        assertThat(offsetStore.get(deviceId)).isEqualTo(-1L);
    }

    @Test
    void shouldNotAdvanceOffsetForEmptyEvents() {
        // Given
        String deviceId = "device-1";
        offsetStore.update(deviceId, 10L);

        // When
        systoleProcessor.process(deviceId, List.of());

        // Then
        assertThat(offsetStore.get(deviceId)).isEqualTo(10L);
    }
}

package com.nagada.pulse.protocol;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

public class JsonSerializationTest {

    private final ObjectMapper objectMapper = new ObjectMapper();

    @Test
    void testClientEvent() throws Exception {
        ClientEvent original = new ClientEvent("c-event-1", "test-type", "payload".getBytes(), List.of("item1", "item2"),0L);
        String json = objectMapper.writeValueAsString(original);
        ClientEvent deserialized = objectMapper.readValue(json, ClientEvent.class);
        assertThat(deserialized.getClientEventId()).isEqualTo(original.getClientEventId());
        assertThat(deserialized.getType()).isEqualTo(original.getType());
        assertThat(deserialized.getPayload()).isEqualTo(original.getPayload());
    }

    @Test
    void testServerEvent() throws Exception {
        ServerEvent original = new ServerEvent(1L, "test-client-event-id", 
        "device-1", "payload".getBytes(), List.of("p"),System.currentTimeMillis());
        String json = objectMapper.writeValueAsString(original);
        ServerEvent deserialized = objectMapper.readValue(json, ServerEvent.class);
        assertThat(deserialized).usingRecursiveComparison().isEqualTo(original);
    }

    @Test
    void testSyncRequest() throws Exception {
        ClientEvent clientEvent = new ClientEvent("c-event-1", "test-type", "payload".getBytes(), List.of("item1", "item2"),0L);
        SyncRequest original = new SyncRequest("device-1", List.of(clientEvent), 0L);
        String json = objectMapper.writeValueAsString(original);
        SyncRequest deserialized = objectMapper.readValue(json, SyncRequest.class);

        assertThat(deserialized.getDeviceId()).isEqualTo(original.getDeviceId());
        assertThat(deserialized.getLastKnownServerEventId()).isEqualTo(original.getLastKnownServerEventId());
        assertThat(deserialized.getPendingEvents()).hasSize(1);
        assertThat(deserialized.getPendingEvents().get(0).getClientEventId()).isEqualTo(clientEvent.getClientEventId());
    }

    @Test
    void testSyncResponse() throws Exception {
        ServerEvent serverEvent = new ServerEvent(1L, "test-client-event-id", "device-1", "payload".getBytes(),List.of("p"), System.currentTimeMillis());
        SyncResponse original = new SyncResponse(List.of("c-event-1"), List.of(serverEvent),0,Map.of());
        String json = objectMapper.writeValueAsString(original);
        SyncResponse deserialized = objectMapper.readValue(json, SyncResponse.class);

        assertThat(deserialized.getSuccessClientEventIds()).isEqualTo(original.getSuccessClientEventIds());
        assertThat(deserialized.getNewServerEvents()).usingRecursiveFieldByFieldElementComparator().isEqualTo(original.getNewServerEvents());
    }
}

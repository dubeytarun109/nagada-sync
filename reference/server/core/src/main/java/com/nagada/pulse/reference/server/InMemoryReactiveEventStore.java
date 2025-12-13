package com.nagada.pulse.reference.server;

import com.nagada.pulse.protocol.ClientEvent;
import com.nagada.pulse.protocol.ServerEvent;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.atomic.AtomicLong;

/**
 * In-memory implementation of ReactiveEventStore for testing.
 */
public class InMemoryReactiveEventStore implements ReactiveEventStore {

    private final AtomicLong nextId = new AtomicLong(1);
    private final List<ServerEvent> events = new CopyOnWriteArrayList<>();
    private final Map<String, Map<String, Boolean>> seenClientEvents = new ConcurrentHashMap<>();

    @Override
    public Mono<ServerEvent> append(String deviceId, ClientEvent clientEvent) {
        return Mono.fromCallable(() -> {
            long id = nextId.getAndIncrement();
            ServerEvent event = new ServerEvent(id, clientEvent.getClientEventId(), deviceId, clientEvent.getPayload(),clientEvent.getPayloadManifest(), clientEvent.getCreatedAt());
            event.payloadManifest = clientEvent.getPayloadManifest();
            
            events.add(event);
            
            seenClientEvents
                .computeIfAbsent(deviceId, k -> new ConcurrentHashMap<>())
                .put(clientEvent.getClientEventId(), true);
            
            return event;
        });
    }

    @Override
    public Flux<ServerEvent> listAfter(long afterId) {
        return Flux.fromIterable(events)
                .filter(e -> e.getServerEventId() > afterId);
    }

    @Override
    public Mono<Boolean> exists(String deviceId, String clientEventId) {
        return Mono.fromCallable(() -> {
            Map<String, Boolean> deviceSeen = seenClientEvents.get(deviceId);
            return deviceSeen != null && deviceSeen.containsKey(clientEventId);
        });
    }
}
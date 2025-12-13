package com.nagada.pulse.reference.server;

import reactor.core.publisher.Mono;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * In-memory implementation of ReactiveOffsetStore for testing.
 */
public class InMemoryReactiveOffsetStore implements ReactiveOffsetStore {

    private final Map<String, Long> offsets = new ConcurrentHashMap<>();

    @Override
    public Mono<Long> get(String deviceId) {
        return Mono.fromCallable(() -> offsets.getOrDefault(deviceId, -1L));
    }

    @Override
    public Mono<Void> update(String deviceId, long offset) {
        return Mono.fromRunnable(() -> offsets.put(deviceId, offset));
    }
}
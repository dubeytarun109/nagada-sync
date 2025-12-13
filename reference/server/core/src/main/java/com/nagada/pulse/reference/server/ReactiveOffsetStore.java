package com.nagada.pulse.reference.server;

import reactor.core.publisher.Mono;

/**
 * Reactive interface for tracking per-device offsets.
 */
public interface ReactiveOffsetStore {
    Mono<Long> get(String deviceId);

    Mono<Void> update(String deviceId, long offset);
}
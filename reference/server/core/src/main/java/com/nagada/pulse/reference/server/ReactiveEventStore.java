package com.nagada.pulse.reference.server;

import com.nagada.pulse.protocol.ClientEvent;
import com.nagada.pulse.protocol.ServerEvent;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * Reactive interface for persisting and querying server events.
 */
public interface ReactiveEventStore {
    Mono<ServerEvent> append(String deviceId, ClientEvent clientEvent);

    Flux<ServerEvent> listAfter(long afterId);

    Mono<Boolean> exists(String deviceId, String clientEventId);
}
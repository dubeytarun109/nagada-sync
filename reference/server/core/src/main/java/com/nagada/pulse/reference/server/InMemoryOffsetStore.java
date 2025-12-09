package com.nagada.pulse.reference.server;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * In-memory implementation of OffsetStore for reference and testing.
 */
public class InMemoryOffsetStore implements OffsetStore {

    private final Map<String, Long> offsets = new ConcurrentHashMap<>();

    @Override
    public long get(String deviceId) {
        return offsets.getOrDefault(deviceId, -1L);
    }

    @Override
    public void update(String deviceId, long offset) {
        offsets.put(deviceId, offset);
    }

    public void clear() {
        offsets.clear();
    }
}

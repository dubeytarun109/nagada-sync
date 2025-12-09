package com.nagada.pulse.reference.server;

/**
 * Pluggable interface for tracking per-device offsets.
 */
public interface OffsetStore {
    /**
     * Get the last committed offset for a device. Return -1 if none.
     */
    long get(String deviceId);

    /**
     * Update the last committed offset for a device.
     */
    void update(String deviceId, long offset);
}

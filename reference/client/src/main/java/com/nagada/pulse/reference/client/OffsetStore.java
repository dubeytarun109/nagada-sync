package com.nagada.pulse.reference.client;

/**
 * Pluggable interface for tracking per-device offsets. (Does not participate in sync loop)
 * User only for reporting and debug purpose.
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

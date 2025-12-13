package com.nagada.pulse.reference.client.example;

import com.nagada.pulse.protocol.ServerEvent;
import com.nagada.pulse.protocol.SyncRequest;
import com.nagada.pulse.protocol.SyncResponse;
import com.nagada.pulse.reference.client.*;

import java.util.List;

/**
 * Demonstration script showing how a client would use the reference sync engine.
 * This example shows:
 * - Creating a SyncEngine with local stores
 * - Adding events to the outbox
 * - Simulating sync cycles
 * - Processing received events
 */
public class ConsoleClientExample {

    public static void main(String[] args) {
        System.out.println("=== Nagada Pulse Sync Client Example ===\n");

        // 1. Create local stores
        PendingOutbox outbox = new InMemoryOutbox();
        LocalProjectionStore projectionStore = new InMemoryProjectionStore();
        BackoffStrategy backoffStrategy = new BackoffStrategy();

        System.out.println("1. Created client stores:");
        System.out.println("   - PendingOutbox: ready");
        System.out.println("   - LocalProjectionStore: ready");
        System.out.println("   - BackoffStrategy: ready\n");

        // 2. Create sync engine
        String deviceId = "client-demo-001";
        SyncEngine syncEngine = new SyncEngine(deviceId, outbox, projectionStore, backoffStrategy);

        System.out.println("2. Created SyncEngine with deviceId: " + deviceId + "\n");

        // 3. Add some events to the outbox
        System.out.println("3. Adding events to outbox:");
        outbox.add("event-1", "hello world".getBytes(),List.of("text"),0);
        outbox.add("event-2", "sync test".getBytes(),List.of("text"),0);
        outbox.add("event-3", "client example".getBytes(),List.of("text"),0);
        System.out.println("   - Added 3 events\n");

        // 4. Build a sync request
        System.out.println("4. Building SyncRequest:");
        SyncRequest request = syncEngine.buildSyncRequest();
        System.out.println("   - Device ID: " + request.deviceId);
        System.out.println("   - Pending events: " + request.pendingEvents.size());
        System.out.println("   - Last known server event ID: " + request.lastKnownServerEventId + "\n");

        // 5. Simulate receiving a sync response
        System.out.println("5. Simulating server response:");
        SyncResponse response = new SyncResponse();
        // In a real scenario, the server would populate this with actual events
        System.out.println("   - Response received with events (simulated)\n");

        // 6. Record response events in local projection
        if (response.newServerEvents != null && !response.newServerEvents.isEmpty()) {
            List<ServerEvent> newEvents = response.newServerEvents;
            projectionStore.recordEvents(newEvents);
            System.out.println("6. Recorded " + newEvents.size() + " server events in projection\n");
        } else {
            System.out.println("6. No new events from server (expected in demo)\n");
        }

        // 7. Check local projection state
        System.out.println("7. Local projection state:");
        if (projectionStore instanceof InMemoryProjectionStore) {
            InMemoryProjectionStore inMemory = (InMemoryProjectionStore) projectionStore;
            System.out.println("   - Total events received: " + inMemory.getEventCount());
            System.out.println("   - Last known server event ID: " + inMemory.getLastKnownServerEventId() + "\n");
        }

        // 8. Check outbox state (should be empty after sync)
        System.out.println("8. Outbox state after sync:");
        if (outbox instanceof InMemoryOutbox) {
            InMemoryOutbox inMemory = (InMemoryOutbox) outbox;
            System.out.println("   - Pending events: " + inMemory.getPending().size());
            System.out.println("   - Has pending: " + outbox.hasPending() + "\n");
        }

        System.out.println("=== Example Complete ===");
    }
}

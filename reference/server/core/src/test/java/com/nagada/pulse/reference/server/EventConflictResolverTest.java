package com.nagada.pulse.reference.server;

import com.nagada.pulse.protocol.ClientEvent;
import com.nagada.pulse.protocol.ServerEvent;
import org.junit.jupiter.api.Test;

import java.util.Collections;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

public class EventConflictResolverTest {

    @Test
    public void testResolveConflicts_NewerWins_True_PendingIsNewer() {
        // Arrange
        ClientEvent pendingEvent = new ClientEvent("client-1", "test-type", "payload".getBytes(),
                Collections.singletonList("item-A"), 200L);

        ServerEvent serverEvent = new ServerEvent(1L, "server-1", "device-2", "payload".getBytes(),
                Collections.singletonList("item-A"), 100L);

        // Act
        EventConflictResolver.ConflictResolutionResult result = EventConflictResolver.resolveConflicts(
                Collections.singletonList(pendingEvent),
                Collections.singletonList(serverEvent),
                true
        );

        // Assert
        assertTrue(result.successClientEventIds.contains("client-1"), "Pending event should succeed as it is newer.");
        assertTrue(result.errorClientEventIds.isEmpty(), "There should be no error events.");
    }

    @Test
    public void testResolveConflicts_NewerWins_True_PendingIsOlder() {
        ClientEvent pendingEvent = new ClientEvent("client-1", "test-type", "payload".getBytes(),
                Collections.singletonList("item-A"), 100L);

        ServerEvent serverEvent = new ServerEvent(1L, "server-1", "device-2", "payload".getBytes(),
                Collections.singletonList("item-A"), 200L);

        // Act
        EventConflictResolver.ConflictResolutionResult result = EventConflictResolver.resolveConflicts(
                Collections.singletonList(pendingEvent),
                Collections.singletonList(serverEvent),
                true
        );

        // Assert
        assertTrue(result.errorClientEventIds.containsKey("client-1"), "Pending event should fail as it is older.");
        assertEquals("CONFLICT|NEWER_WINS", result.errorClientEventIds.get("client-1"));
        assertTrue(result.successClientEventIds.isEmpty(), "There should be no success events.");
    }

    @Test
    public void testResolveConflicts_NewerWins_True_SameTimestamp() {
        // Arrange
        ClientEvent pendingEvent = new ClientEvent("client-1", "test-type", "payload".getBytes(),
                Collections.singletonList("item-A"), 200L);

        ServerEvent serverEvent = new ServerEvent(1L, "server-1", "device-2", "payload".getBytes(),
                Collections.singletonList("item-A"), 200L);
        // Act
        EventConflictResolver.ConflictResolutionResult result = EventConflictResolver.resolveConflicts(
                Collections.singletonList(pendingEvent),
                Collections.singletonList(serverEvent),
                true
        );

        // Assert
        assertTrue(result.errorClientEventIds.containsKey("client-1"), "Pending event should fail with same timestamp due to '<=' check.");
        assertTrue(result.successClientEventIds.isEmpty(), "There should be no success events.");
    }

    @Test
    public void testResolveConflicts_NewerWins_True_NoManifestOverlap() {
        // Arrange
        ClientEvent pendingEvent = new ClientEvent("client-1", "test-type", "payload".getBytes(),
                Collections.singletonList("item-A"), 100L);

        ServerEvent serverEvent = new ServerEvent(1L, "server-1", "device-2", "payload".getBytes(),
                Collections.singletonList("item-B"), 200L);

        // Act
        EventConflictResolver.ConflictResolutionResult result = EventConflictResolver.resolveConflicts(
                Collections.singletonList(pendingEvent),
                Collections.singletonList(serverEvent),
                true
        );

        // Assert
        assertTrue(result.successClientEventIds.contains("client-1"), "Pending event should succeed as there is no manifest overlap.");
        assertTrue(result.errorClientEventIds.isEmpty(), "There should be no error events.");
    }

    @Test
    public void testResolveConflicts_NewerWins_False_ManifestOverlap() {
        // Arrange
        ClientEvent pendingEvent = new ClientEvent("client-1", "test-type", "payload".getBytes(),
                Collections.singletonList("item-A"), 100L);

        ServerEvent serverEvent = new ServerEvent(1L, "server-1", "device-2", "payload".getBytes(),
                Collections.singletonList("item-A"), 200L);

        // Act

        EventConflictResolver.ConflictResolutionResult result = EventConflictResolver.resolveConflicts(
                Collections.singletonList(pendingEvent),
                Collections.singletonList(serverEvent),
                false
        );

        // Assert
        assertTrue(result.errorClientEventIds.containsKey("client-1"), "Pending event should fail due to manifest overlap.");
        assertTrue(result.successClientEventIds.isEmpty(), "There should be no success events.");
    }

    @Test
    public void testResolveConflicts_NewerWins_False_NoManifestOverlap() {
        // Arrange
        ClientEvent pendingEvent = new ClientEvent("client-1", "test-type", "payload".getBytes(),
                Collections.singletonList("item-A"), 100L);

        ServerEvent serverEvent = new ServerEvent(1L, "server-1", "device-2", "payload".getBytes(),
                Collections.singletonList("item-B"), 200L);

        // Act

        EventConflictResolver.ConflictResolutionResult result = EventConflictResolver.resolveConflicts(
                Collections.singletonList(pendingEvent),
                Collections.singletonList(serverEvent),
                false
        );

        // Assert
        assertTrue(result.successClientEventIds.contains("client-1"), "Pending event should succeed as there is no manifest overlap.");
        assertTrue(result.errorClientEventIds.isEmpty(), "There should be no error events.");
    }
}
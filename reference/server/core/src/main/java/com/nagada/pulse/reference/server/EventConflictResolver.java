package com.nagada.pulse.reference.server;

import com.nagada.pulse.protocol.ClientEvent;
import com.nagada.pulse.protocol.ServerEvent;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

public class EventConflictResolver {

    // Helper class to return both success and error client event IDs
    public static class ConflictResolutionResult {
        public final List<String> successClientEventIds;
        public final Map<String, String> errorClientEventIds;

        public ConflictResolutionResult(List<String> successClientEventIds, Map<String, String> errorClientEventIds) {
            this.successClientEventIds = successClientEventIds;
            this.errorClientEventIds = errorClientEventIds;
        }
    }

    public static ConflictResolutionResult resolveConflicts(List<ClientEvent> pendingEvents, List<ServerEvent> newEvents, boolean newerWins) {
        Set<String> pendingIds = pendingEvents == null ? new HashSet<>() : pendingEvents.stream()
                .map(ClientEvent::getClientEventId)
                .collect(Collectors.toSet());

        Map<String, String> errorClientEventIds = new HashMap<>();
        List<String> successClientEventIds = new ArrayList<>();

        if (pendingEvents == null) {
            return new ConflictResolutionResult(new ArrayList<>(), new HashMap<>());
        }

        if (newerWins) {
            Map<String, Long> manifestToTimestamp = new HashMap<>();
            newEvents.stream()
                .filter(se -> !pendingIds.contains(se.getOriginClientEventId()) && se.getPayloadManifest() != null)
                .forEach(se -> {
                    for (String manifest : se.getPayloadManifest()) {
                        manifestToTimestamp.merge(manifest, se.getCreatedAt(), Long::max);
                    }
                });

            for (ClientEvent pendingEvent : pendingEvents) {
                boolean isConflict = false;
                if (pendingEvent.getPayloadManifest() != null) {
                    for (String manifest : pendingEvent.getPayloadManifest()) {
                        if (manifestToTimestamp.containsKey(manifest)) {
                            if (pendingEvent.getCreatedAt() <= manifestToTimestamp.get(manifest)) {
                                errorClientEventIds.put(pendingEvent.getClientEventId(), "CONFLICT|"+(newerWins?"NEWER_WINS":"OLDER_WINS"));
                                isConflict = true;
                                break;
                            }
                        }
                    }
                }
                if (!isConflict) {
                    successClientEventIds.add(pendingEvent.getClientEventId());
                }
            }
        } else {
            Set<String> newServerPayloadManifestItems = newEvents.stream()
                    .filter(se -> !pendingIds.contains(se.getOriginClientEventId()))
                    .flatMap(serverEvent -> serverEvent.payloadManifest != null ? serverEvent.payloadManifest.stream() : java.util.stream.Stream.empty())
                    .collect(Collectors.toSet());
            
            for (ClientEvent pendingEvent : pendingEvents) {
                boolean isError = false;
                if (pendingEvent.getPayloadManifest() != null) {
                    for (String clientManifestItem : pendingEvent.getPayloadManifest()) {
                        if (newServerPayloadManifestItems.contains(clientManifestItem)) {
                            errorClientEventIds.put(pendingEvent.getClientEventId(), "Client event manifest overlaps with server event manifest.");
                            isError = true;
                            break; 
                        }
                    }
                }
                if (!isError) {
                    successClientEventIds.add(pendingEvent.getClientEventId());
                }
            }
        }
        return new ConflictResolutionResult(successClientEventIds, errorClientEventIds);
    }
}

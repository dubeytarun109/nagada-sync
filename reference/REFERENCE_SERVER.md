# Nagada-Pulse HTTP Reference Server

**Status:** Active  
**Stage:** v0.3 — Validation  
**Purpose:** Executable model of the Nagada-Pulse protocol over HTTP

---

## Overview

This reference server provides the baseline implementation of the Nagada-Pulse sync protocol using standard HTTP POST transport.

It exists to:

- Validate the written specification through executable behavior  
- Serve as an authoritative example for implementers  
- Support interoperability and conformance testing  
- Provide a learning path for developers building custom servers or clients  

This implementation prioritizes correctness over performance.

---

## Features

- Append-only event store  
- Idempotent event ingestion  
- Heartbeat-based synchronization (`systole → diastole`)  
- Per-device offset tracking  
- Ordered event replay  
- Retry-safe semantics  
- Backoff hints (`nextHeartbeatMs`)

---

## Requirements

- Java **17+**  
- Maven (recommended)  
- SQLite (default) or another lightweight persistent store  

---

## Running the Server

Run the server using Maven (recommended):

```bash
cd reference/server/http
mvn spring-boot:run
```

The sync endpoint will be available at:

```
POST /api/sync/heartbeat
Content-Type: application/json
```

---

## Example Request

```
{
  "deviceId": "device-xyz",
  "lastKnownServerEventId": 0,
  "pendingEvents": []
}
```

---

## Example Response

```
{
  "status": "OK",
  "acknowledgedEventIds": [],
  "newServerEvents": [],
  "nextHeartbeatMs": 3000
}
```

---

## Project Structure

```
reference/
  http-server/
    src/
    test/
    data/
```

Future reference components may be added:

```
reference/
  websocket-server/
  js-client/
  dart-client/
```

---

## Intended Use Cases

| Use Case | Supported |
|----------|-----------|
| Learning the protocol | ✔ |
| Developing client SDKs | ✔ |
| Interoperability testing | ✔ |
| Production deployment | ❌ Recommended only after optimization and hardening |

---

## Conformance Expectations

The reference server must remain aligned with the protocol specification.

If behavior and documentation differ:

> The specification is authoritative unless resolved through the governance process.

Once the conformance suite lands (planned milestone: `v0.5`), this implementation will act as the primary reference for validation.

---

## Contribution Guidelines

Before proposing protocol-impacting changes, review:

- `GOVERNANCE.md`  
- `PROPOSAL_TEMPLATE.md`  
- `/spec/`

Bug fixes, clarity improvements, and additional testing are welcome.

---

## Roadmap

| Version | Focus |
|--------|--------|
| `v0.2` | Basic sync wiring |
| `v0.3` | Full specification compliance |
| `v0.4` | Automated test coverage  (**current**) |
| `v0.5` | Conformance harness |
| `v0.6+` | Optional extensions (WebSockets, Snapshotting, CRDT, etc.) |

---

## License

Licensed under **Apache-2.0**, consistent with the Nagada-Pulse protocol and ecosystem.

---

### Summary

This server is the canonical working model of the Nagada-Pulse protocol over HTTP.  
It exists to teach, validate, and ensure consistent interpretation — not to lock users into a single implementation.

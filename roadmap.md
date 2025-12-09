# Roadmap

This document outlines the planned features and milestones for Nagada-Pulse.

## Version Milestones

**0.1** — Initial specification + reference HTTP sync  
**0.2** — Minimal server + Dart client (experimental)  
**0.3** — Conformance test kit  
**0.4** — Reference Client (Dart)
**0.5** — Spring Boot starter + conformance suite & examples  
**0.6** — Flutter example app  
**0.7** — WebSocket optional transport (see `extensions/websocket-transport.md`)  
**0.8** — Snapshotting + CRDT event payload support (see `extensions/snapshotting-strategy.md` & `extensions/crdt-payload-proposal.md`)  
**1.0** — Stable production-ready specification + comprehensive tests  

## Phase Details

### Phase 0 (Current): Specification & Core
- [x] Core specification documents (philosophy, terminology, protocol overview)
- [x] Wire format definition
- [x] Client and server behavior specifications
- [x] Conflict resolution framework
- [x] Versioning and compatibility guidelines
- [x] Reference HTTP sync implementation

### Phase 1: Foundation Implementations (0.2–0.4)
- [x] Minimal server implementation (HTTP baseline)
- [ ] Dart client SDK (experimental)
- [ ] Conformance test kit
- [ ] JavaScript client SDK
- [ ] Projection helper libraries

### Phase 2: Extensions & Hardening (0.5–0.8)
- [ ] Spring Boot starter
- [ ] Flutter example application
- [ ] WebSocket transport extension
- [ ] CRDT payload support
- [ ] Snapshotting and event pruning strategy

### Phase 3: Production Release (1.0)
- [ ] Stable protocol specification
- [ ] Comprehensive conformance tests
- [ ] Production-ready implementations
- [ ] Performance benchmarks
- [ ] Security audit

## Future Research

See `docs/future-ideas.md` for discussion of:
- Live presence and awareness
- Compression and bandwidth optimization
- Advanced conflict resolution
- Sharding and partitioning
- Security extensions

## Community Contributions

We welcome proposals, implementations, and feedback on any milestone. See [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines.


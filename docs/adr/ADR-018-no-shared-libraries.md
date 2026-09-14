# ADR-018 — No shared service libraries

**Status:** Accepted
**Date:** 2026-09-14
**Deciders:** platform-team

## Context
Shared packages become coupling magnets. One change ripples into seven deployments.

## Decision
WALFA services share NOTHING at code level. No packages/ tree, no shared Go module. Each service self-contained Go module. Compatibility from frozen SPECs (docs/specs/) + per-service conformance tests. Copying small frozen behaviors is the mechanism.

## Consequences
Accepted duplication. Every spec ships conformance checklist. Envelope changes are explicit versioned events (ADR + coordinated PRs). CI rejects cross-service imports. PR adding shared package or importing another service fails review by definition.

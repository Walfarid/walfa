# ADR-008 — Message transport is abstracted

**Status:** Accepted
**Date:** 2026-09-14
**Deciders:** platform-team

## Context
Event contract is small and frozen; per-service implementation cheap. But transport is one managed service.

## Decision
OCI Queue canonical. NATS/self-hosted would trade solved problem for cluster resources free profile lacks.

## Consequences
Each service implements own publisher/consumer from frozen spec; no shared transport library.

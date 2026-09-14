# ADR-005 — Transactional outbox

**Status:** Accepted
**Date:** 2026-09-14
**Deciders:** platform-team

## Context
Prevents domain writes succeeding while event publication silently fails.

## Decision
Every emitting service writes to local event_outbox within same transaction; dispatcher publishes to OCI Queue after commit.

## Consequences
At-least-once delivery; consumers idempotent; exponential backoff with jitter.

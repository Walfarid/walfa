# ADR-009 — OCI Queue is canonical message transport

**Status:** Accepted (closed out Phase 13)
**Date:** 2026-09-14
**Deciders:** platform-team

## Context
Operator-confirmed free tier (~1M API calls/month free) covers workload with 100x headroom. Estimated <50k calls/month.

## Decision
OCI Queue only. Five category queues + DLQ. Spend-alarmed at $0.

## Consequences
Do not introduce any other message transport. Re-verification Phase 5; closure Phase 13 with budget math.

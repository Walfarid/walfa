# Queue Topology (Frozen Spec v1)

## Queues

| Queue | Category | Purpose |
|---|---|---|
| `walfa-identity-events` | identity | User lifecycle events |
| `walfa-portfolio-events` | portfolio | Profile/skill/project CRUD |
| `walfa-publishing-events` | publishing | Article state transitions |
| `walfa-media-events` | media | Upload/finalize/cleanup |
| `walfa-analytics-events` | analytics | Beacon aggregation, purge |
| `walfa-dlq` | dead-letter | Poison messages after max deliveries |

## Configuration

- Visibility timeout: 30s (default)
- Max delivery count: 10 (then native DLQ routing)
- Retention: per queue default (messages auto-expire after retention period)
- Message size limit: 64 KiB (payloads stay small domain events — oversized = design error, store a reference instead)

## Startup resolution

Services resolve queue OCIDs by display name at startup (OCIDs as fallback env override). Display names are stable; OCIDs may change on recreation.

## Publishing

Mandatory batching: PutMessages with batch of up to 10 messages per call. Never single-message puts in a loop.

## Consuming

Long-poll GetMessages (wait up to visibility timeout). DeleteMessages AFTER local commit succeeds (never before). If commit fails, message becomes visible again after timeout — at-least-once semantics.

## In-memory fake (for tests)

Each service implements its OWN in-memory fake implementing exactly three operations: put, get, delete. Nothing more. The fake is used in unit/integration tests. The real Queue is proven in Phase 13 (selftest) and Phase 24 (e2e + chaos).

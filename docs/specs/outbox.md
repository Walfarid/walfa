# Outbox Contract (Frozen Spec v1)

Every WALFA service that emits integration events owns an `event_outbox` table and a dispatcher.

## Table DDL

```sql
CREATE TABLE event_outbox (
    id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    event_id VARCHAR2(36) NOT NULL,
    queue_name VARCHAR2(128) NOT NULL,
    occurred_at TIMESTAMP WITH TIME ZONE NOT NULL,
    aggregate_type VARCHAR2(64) NOT NULL,
    aggregate_id VARCHAR2(128) NOT NULL,
    entity_version NUMBER NOT NULL,
    event_type VARCHAR2(128) NOT NULL,
    payload CLOB NOT NULL,
    attempt_count NUMBER DEFAULT 0 NOT NULL,
    next_attempt_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    published_at TIMESTAMP WITH TIME ZONE NULL,
    last_error VARCHAR2(2000) NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT uq_event_outbox_event_id UNIQUE (event_id)
);
```

## Dispatcher algorithm

1. Select bounded batch: `SELECT ... FROM event_outbox WHERE published_at IS NULL AND next_attempt_at <= CURRENT_TIMESTAMP AND ROWNUM <= 50 FOR UPDATE SKIP LOCKED`
2. For each row: publish to OCI Queue (PutMessages, batched)
3. On success: `UPDATE event_outbox SET published_at = SYSTIMESTAMP WHERE id = :id`
4. On failure: `UPDATE event_outbox SET attempt_count = attempt_count + 1, next_attempt_at = CURRENT_TIMESTAMP + POWER(2, attempt_count) * INTERVAL '1' SECOND + DBMS_RANDOM.VALUE(0, 1) * INTERVAL '1' SECOND, last_error = :err WHERE id = :id`
5. After N attempts (default 10): forward to `walfa-dlq` and mark `published_at` (prevent re-processing)

## Idempotency

Consumer key: `consumer_name + event_id`. Handlers must be safe to execute more than once. Duplicate delivery = zero state change (verified per service).

## DLQ forwarding

After `attempt_count >= 10` (configurable per service): forward payload to `walfa-dlq` with original metadata preserved. Alert on DLQ arrival (OCI Monitoring alarm from Phase 5).

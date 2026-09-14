# Phase 2 — Frozen specs (tasks 2.1–2.10). Documents, NOT code.

**GOAL:** the single written contract every self-contained service implements independently. ZERO Go code in this phase.
**START ONLY WHEN:** Phase 1 gate fully ticked.
**Workdir:** `walfa/docs/specs/`.

## Task 2.1 — Event envelope schema

- [x] Write `event-envelope.v1.json` (JSON Schema draft 2020-12).
- [x] Required: `event_id` (uuid), `occurred_at` (RFC3339), `aggregate_type`, `aggregate_id`, `entity_version` (int ≥1), `event_type` (pattern `^[a-z]+\.[a-z-]+\.v1$`), `payload` (object). `additionalProperties: false`.
- [x] Header comment: ANY change = `v2` + ADR + coordinated per-service PRs.

**Verify:** `python3 -c "import json; json.load(open('docs/specs/event-envelope.v1.json')); print('VALID JSON')"`.

## Task 2.2 — HTTP conventions

- [x] Write `http-conventions.md`: error shape `{code,message,request_id}`; pagination (`page,page_size`, max 100, 422 on overflow); `X-Request-Id` generate-if-absent + propagate; mandatory `GET /health/live`, `/health/ready`, `/metrics`; JWT allow-list values `RS256, ES256` (hardcoded locally per service — never imported); security-headers list.

**Verify:** each rule has an example (good request + bad request) in the doc.

## Task 2.3 — Outbox contract

- [x] Write `outbox.md`: table DDL (master §8.2 verbatim); dispatcher algorithm (bounded batch → `SKIP LOCKED` → publish → mark → attempt++/backoff+jitter → alert); idempotency rule (`consumer_name + event_id`); DLQ rule (10 deliveries → native `walfa-dlq` routing).

**Verify:** DDL diffed against master §8.2 — identical.

## Task 2.4 — Valkey key layout

- [x] Write `valkey-keys.md`: `sess:<id>` (TTL = session idle), `ratelimit:<scope>:<key>` (TTL = window), `bff:public:<route>` (TTL ≤300s). NO immortal keys. Auth mandatory.

**Verify:** every namespace has prefix + TTL rule + one example key.

## Task 2.5 — Queue topology spec

- [x] Write `queue-topology.md`: one queue per category (`walfa-<category>-events`) + `walfa-dlq`; startup resolution by display name (OCIDs fallback); batched PutMessages (mandatory); long-poll GetMessages + DeleteMessages-after-commit; visibility 30s; max-deliveries=10 → native DLQ; 64 KiB size discipline; per-service in-memory fake discipline (put/get/delete only).
- [x] Header comment: queue set changes (add/remove/rename) = Terraform + ADR, never ad-hoc queues from services.

**Verify:** all 6 queue names listed; each rule names its Terraform source of truth (`queue.tf`).

## Task 2.6 — Conformance checklist

- [x] Write `conformance-checklist.md`: tick-list every service phase satisfies with OWN tests — envelope good + 5 bad fixtures; outbox drains after consumer outage; duplicate delivery = zero state change; poison → DLQ; error shape exact; pagination caps; 401/429/413 (gateway).

**Verify:** every row names the spec section it checks (no orphan rows).

## Task 2.7 — Migration-file contract (no goose: no Oracle dialect exists)

- [x] Write `migrations.md`: `NNNN_name.up.sql` / `.down.sql` pairs, plain Oracle DDL/DML only, one statement per `;`-at-line-end, CI grep gate rejecting `BEGIN|DECLARE|CREATE TRIGGER|CREATE PROCEDURE|CREATE PACKAGE`, `schema_version(version NUMBER PK, name, applied_at, checksum)` + SHA256 rule, `up`/`status` semantics (second `up` = no-op), down-files for local teardown ONLY.
- [x] Example pair for a toy table (proves the format parses by eye).

**Verify:** doc states the no-goose reason explicitly (prevents rediscovery).

## Task 2.8 — Validator + fixtures

- [x] `fixtures/` with one GOOD and one BAD envelope JSON.
- [x] `scripts/validate-envelope.py` (stdlib ONLY): GOOD passes, BAD fails, exit 0 overall.
- [x] Wire into `ci.yml` placeholder.

**Verify:**
```bash
python3 scripts/validate-envelope.py
grep -rn "package " docs/specs/ || echo "NO CODE IN SPECS"
```

## Task 2.9 — ADR status lines

- [x] ADR-009: open, owner Phase 13. ADR-010: open, owner Phase 11.

**Verify:** both files contain owner + phase number.

## Task 2.10 — Phase gate

- [x] 7 spec docs + fixtures + validator committed.
- [x] Zero `.go` files repo-wide: `find . -name "*.go" | wc -l` → `0`.

## Phase gate

- [x] Specs frozen + validated · [x] zero Go files · [x] ADR ownership recorded

**DO NOT:** write Go helpers, a shared module, a code generator, or "one tiny shared package".

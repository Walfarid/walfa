# Conformance Checklist (Frozen Spec v1)

Every service phase must satisfy these rows with its OWN tests. Tick each row in the service's PR description.

## Event envelope

- [ ] Validates against `docs/specs/event-envelope.v1.json`
- [ ] Good fixture passes validation
- [ ] At least 5 bad fixtures fail validation (missing fields, wrong types, bad pattern, extra fields, wrong version)

## Outbox

- [ ] Outbox drains after consumer outage (stop consumer → produce events → restart consumer → events delivered)
- [ ] Duplicate delivery = zero state change (deliver same event twice → second is no-op)
- [ ] Poison message routes to DLQ after max attempts

## HTTP

- [ ] Error shape matches `{code, message, request_id}` exactly
- [ ] Pagination caps enforced (page_size > 100 → 422)
- [ ] 401 on missing/invalid auth (gateway-enforced)
- [ ] 429 on rate limit burst (gateway-enforced)
- [ ] 413 on oversized body (gateway-enforced)

## Migrations

- [ ] Baseline migration applies clean on `oracle-free`
- [ ] Second apply is no-op
- [ ] Down migration tears down cleanly (local dev only)
- [ ] Forbidden-keyword grep is clean

## Transport

- [ ] Batched PutMessages (not single-message loop)
- [ ] DeleteMessages after local commit (not before)
- [ ] Startup queue resolution by display name

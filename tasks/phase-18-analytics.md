# Phase 18 — Analytics service (tasks 18.1–18.6)

**GOAL:** cheap beacon intake + rollups + retention + purge propagation. Own module.
**START ONLY WHEN:** Phase 17 gate fully ticked.

## Task 18.1 — Migrations

- [ ] Raw events table (no IP column — forbidden), rollup tables (minute/hour/day), retention bookkeeping. Expand/migrate/contract.

**Verify:** double-apply no-op test green on local oracle-free; schema contains no IP field (`grep -i "\bip\b" migrations || echo CLEAN`).

## Task 18.2 — Module code

- [ ] Own module (`services/analytics`): skeleton as 14.2, conformance rows ticked.
- [ ] `POST /api/v1/beacon`: validate → insert raw → 204, p95 <100ms local. Fields per master §14 (`anonymous_id` or `session_id`, DNT respected).
- [ ] Rollup worker (minute→hour→day); retention purge CronJob (raw deleted per policy, rollups kept); `user.purged.v1` consumer scrubs user rows.

**Verify:** `go build ./... && go test ./...`; beacon latency benchmark recorded.

## Task 18.3 — Domain gates

- [ ] Fixture beacons reconcile EXACTLY with rollups; retention deletes only expired rows; purge propagates (query zero).

**Verify:** reconcile + retention + purge tests green.

## Task 18.4 — Dockerfile + ARM64 smoke

- [ ] Same hardening as 14.4.

**Verify:** `buildx --platform linux/arm64` + `--help`.

## Task 18.5 — Manifests + live migrate-Job run + CronJobs

- [ ] `infra/kubernetes/base/analytics/`: Deployment (replicas 2, soft pod anti-affinity, PDB minAvailable 1) + ClusterIP + migrate-Job + rollup worker (Deployment or CronJob) + retention CronJob + NetworkPolicy.
- [ ] Execute `migrate-analytics` Job against ADB + `wait --for=condition=complete`; `schema_version` row proves it.

**Verify:** `kustomize build` renders; Job completes; `SELECT version FROM ANL_SVC.schema_version` returns the baseline.

## Task 18.6 — Phase gate

- [ ] Reconcile + retention + purge proven by OWN tests. Conformance rows ticked.

## Phase gate

All of 18.6 + builds + no foreign imports.

**DO NOT:** store IPs, import raw legacy events (none exist), or keep unbounded raw logs.

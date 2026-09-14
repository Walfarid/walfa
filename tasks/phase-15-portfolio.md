# Phase 15 — Portfolio service (tasks 15.1–15.6)

**GOAL:** profile/experience/education/skills/projects CRUD + optimistic concurrency + events. Own module.
**START ONLY WHEN:** Phase 14 gate fully ticked.

## Task 15.1 — Migrations

- [ ] Domain tables + indexes (justified in comments). Expand/migrate/contract.

**Verify:** double-apply no-op test green on local oracle-free.

## Task 15.2 — Module code

- [ ] Own module (`services/portfolio`): same skeleton as 14.2 (local http/outbox/consumer/testhelper, conformance rows ticked).
- [ ] Owner-only writes; `entity_version` checked on update (409 on mismatch).

**Verify:** `go build ./... && go test ./...` in module; no-cross-import grep empty.

## Task 15.3 — Domain gates

- [ ] Full CRUD suite green; concurrent-edit returns 409; `portfolio.*.v1` events observed in `walfa-portfolio-events` (`oci queue message list`).

**Verify:** 409 test green; event-capture test green against the service's OWN Queue fake (real Queue proven in Phase 13/24).

## Task 15.4 — Dockerfile + ARM64 smoke

- [ ] Same hardening as 14.4.

**Verify:** `buildx --platform linux/arm64` + `--help` shows `serve|migrate`.

## Task 15.5 — Manifests + live migrate-Job run

- [ ] `infra/kubernetes/base/portfolio/`: Deployment (replicas 2, soft pod anti-affinity, PDB minAvailable 1) + ClusterIP + migrate-Job + NetworkPolicy (gateway-only ingress; emits to Queue, reads Valkey if needed).
- [ ] Execute `migrate-portfolio` Job against ADB + `wait --for=condition=complete`; `schema_version` row proves it.

**Verify:** `kustomize build` renders; Job completes; `SELECT version FROM PFO_SVC.schema_version` returns the baseline.

## Task 15.6 — Phase gate

- [ ] CRUD + 409 + events proven by OWN tests. Conformance rows ticked.

## Phase gate

All of 15.6 + builds + no foreign imports.

**DO NOT:** share code with identity, skip the 409 path, or emit outside the envelope.

# Phase 14 — Identity service (tasks 14.1–14.6)

**GOAL:** `(issuer,subject)` principals, sessions, purge + audit. Own Go module, zero sharing.
**START ONLY WHEN:** Phase 13 gate fully ticked.

## Task 14.1 — Migrations

- [ ] Beyond baseline: tables for local profile, sessions refs, audit log. Expand/migrate/contract in `migrations.md` format (grep gate green).

**Verify:** double-apply no-op test green on local oracle-free; `./app migrate status` (14.2 binary) agrees.

## Task 14.2 — Module code (independent implementation)

- [ ] `go mod init github.com/<org>/walfa/services/identity` + `go.work use`; `main.go` (`serve|migrate`), `config.go` (fail-fast), `domain/` (>80% unit cov), `store/` (`go-ora`, §7.4a pool), `http/` (chi, LOCAL error shape/pagination/request-ID per spec), `outbox.go` (LOCAL per `outbox.md` + envelope schema), `consumer.go` (`user.*` as needed, `consumer_name+event_id` idempotency), `internal/testhelper/` (OWN fake OIDC + fixtures), `internal/migrate/` (OWN migrator per `migrations.md` spec).
- [ ] Tick every applicable `conformance-checklist.md` row with OWN tests.

**Verify:** `(cd services/identity && go build ./... && go test ./... -count=1)`; no-cross-import grep empty for this module.

## Task 14.3 — Domain gates

- [ ] Login creates/loads local user keyed `(issuer,subject)` (never email).
- [ ] Logout kills session cluster-wide (Valkey `sess:` DEL).
- [ ] Purge cascades + emits `user.purged.v1`; counts zero across all five schemas.
- [ ] Audit events emitted for auth + purge.

**Verify:** integration tests cover all four; run green on local oracle-free.

## Task 14.4 — Dockerfile + ARM64 smoke

- [ ] Multi-stage, non-root, read-only FS, `linux/arm64+amd64`, no secrets.

**Verify:** `docker buildx build --platform linux/arm64 -t walfa/identity:test --load services/identity && docker run --rm walfa/identity:test ./app --help` shows `serve|migrate`.

## Task 14.5 — Manifests + FIRST LIVE migrate-Job run

- [ ] `infra/kubernetes/base/identity/`: Deployment (§11.2 band, replicas 2, soft pod anti-affinity, PDB minAvailable 1, `TNS_ADMIN=/wallet`, own Secret, probes live 20s/3 + ready 10s/3), ClusterIP, migrate-Job (Phase 10 pattern), NetworkPolicy (gateway-only ingress).
- [ ] Execute `migrate-identity` Job against ADB (first live run since Phase 10) + `wait --for=condition=complete`; `schema_version` row proves it.

**Verify:** `kustomize build` renders; Job completes; `SELECT version FROM ID_SVC.schema_version` returns the baseline.

## Task 14.6 — Phase gate

- [ ] Live Job green + `schema_version` proven; login/load, logout, purge, audit all proven by OWN tests. Conformance rows ticked.

## Phase gate

All of 14.6 + module builds + no foreign imports.

**DO NOT:** import another service, add a shared package, or key principals by email.

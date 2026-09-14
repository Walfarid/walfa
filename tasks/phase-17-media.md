# Phase 17 — Media service (tasks 17.1–17.6)

**GOAL:** private validated media + upload auth per ADR-010 + orphan cleanup. Own module.
**START ONLY WHEN:** Phase 16 gate fully ticked. (ADR-010 already closed in Phase 11.)

## Task 17.1 — Migrations

- [ ] Metadata table (owner, object key server-generated, mime, size, checksum, state) + outbox. Expand/migrate/contract.

**Verify:** double-apply no-op test green on local oracle-free.

## Task 17.2 — Module code

- [ ] Own module (`services/media`): skeleton as 14.2, conformance rows ticked.
- [ ] Upload auth per ADR-010: A = PAR per upload (single object, 15-min, server key) via conditional `par-issuer-key`; B = proxied stream. Implement ONLY the chosen one.
- [ ] MIME sniffed from bytes (`DetectContentType` + extension cross-check); SVG rejected unless sanitizer ADR'd; size caps enforced; checksum stored at finalize.

**Verify:** `go build ./... && go test ./...`; wrong-type + oversized + expired-grant tests green.

## Task 17.3 — Domain gates

- [ ] Anonymous LIST denied; GET with exact key works (ObjectRead by design); unauthenticated PUT/DELETE → 403; PAR expiry enforced; orphan-cleanup CronJob (24h grace, domain-ref check, audit event) dry-run lists exactly fixtures' orphans.

**Verify:** all four proofs green (integration tests, not hand-waving).

## Task 17.4 — Dockerfile + ARM64 smoke

- [ ] Same hardening as 14.4.

**Verify:** `buildx --platform linux/arm64` + `--help`.

## Task 17.5 — Manifests + live migrate-Job run + CronJob

- [ ] `infra/kubernetes/base/media/`: Deployment (replicas 2, soft pod anti-affinity, PDB minAvailable 1) + ClusterIP + migrate-Job + orphan CronJob + NetworkPolicy.
- [ ] Execute `migrate-media` Job against ADB + `wait --for=condition=complete`; `schema_version` row proves it.

**Verify:** `kustomize build` renders; Job completes; `SELECT version FROM MDS_SVC.schema_version` returns the baseline.

## Task 17.6 — Phase gate

- [ ] Grant/expiry/validation/orphan proofs by OWN tests. Conformance rows ticked.

## Phase gate

All of 17.6 + builds + no foreign imports.

**DO NOT:** implement both upload options, trust extensions, or skip the domain-ref check.

# Phase 16 — Publishing service (tasks 16.1–16.6)

**GOAL:** articles/tags/guides/legal + state machine + events. Own module.
**START ONLY WHEN:** Phase 15 gate fully ticked.

## Task 16.1 — Migrations

- [ ] Articles, tags, guides, legal tables + slug uniqueness + state column. Expand/migrate/contract.

**Verify:** double-apply no-op test green on local oracle-free.

## Task 16.2 — Module code

- [ ] Own module (`services/publishing`): skeleton as 14.2, conformance rows ticked.
- [ ] State machine `draft→preview→published→unpublished`; illegal transitions 422 with tested transition matrix.

**Verify:** `go build ./... && go test ./...`; matrix test covers every illegal edge.

## Task 16.3 — Domain gates

- [ ] Preview/publish/unpublish cycle green; illegal-transition rejection green; sitemap fields exposed; `publishing.*.v1` events observed.

**Verify:** cycle + matrix + event tests pass.

## Task 16.4 — Dockerfile + ARM64 smoke

- [ ] Same hardening as 14.4.

**Verify:** `buildx --platform linux/arm64` + `--help`.

## Task 16.5 — Manifests + live migrate-Job run

- [ ] `infra/kubernetes/base/publishing/`: Deployment (replicas 2, soft pod anti-affinity, PDB minAvailable 1) + ClusterIP + migrate-Job + NetworkPolicy.
- [ ] Execute `migrate-publishing` Job against ADB + `wait --for=condition=complete`; `schema_version` row proves it.

**Verify:** `kustomize build` renders; Job completes; `SELECT version FROM PUB_SVC.schema_version` returns the baseline.

## Task 16.6 — Phase gate

- [ ] Cycle + matrix + events proven by OWN tests. Conformance rows ticked.

## Phase gate

All of 16.6 + builds + no foreign imports.

**DO NOT:** allow unwritten transitions, share code, or emit outside the envelope.

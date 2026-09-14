# Phase 23 — Full GitHub Actions CI/CD (tasks 23.1–23.8)

**GOAL:** every merge path automated, gated, credential-clean. OIDC-first.
**START ONLY WHEN:** Phase 22 done. **Workdir:** `walfa/.github/workflows/`.

## Task 23.1 — `ci.yml` (PR gate, the big one)

- [ ] Pinned task-runner install FIRST (per versions table; every later step calls `task`).
- [ ] Per-module loop: fmt/vet/test/race for each `services/*`; `golangci-lint` per module.
- [ ] **no-cross-import job**: per module, `grep -rn "walfa/services/" services/<s> --include="*.go" | grep -v "walfa/services/<s>"` must be EMPTY.
- [ ] **no-shared-package job**: `test ! -d packages` (directory must never return).
- [ ] Frontend lint/typecheck/test; migration validation (forbidden-keyword grep + double-apply no-op on disposable `oracle-free`, per service); buildx smoke (no push); tf fmt -check + validate; `kustomize build overlays/prod | kubeconform`; `python3 scripts/validate-envelope.py`; trivy fs+config; gitleaks; commitlint.
- [ ] `.github/dependabot.yml` (gomod, npm, docker, terraform, github-actions — weekly): bump PRs update `docs/versions.md` FIRST, code second.
- [ ] Fork PRs: ZERO OCI credentials (negative-test job fails if secrets reachable).

**Verify:** green on a no-op PR.

## Task 23.2 — `security.yml`

- [ ] Weekly + dep-touching PRs: `govulncheck` per module, `npm audit`, image CVE rescan of pinned digests, license check (AGPL policy → ADR-016).

**Verify:** scheduled run green.

## Task 23.3 — Terraform plan/apply + drift watch

- [ ] Complete Phase 7 skeleton; add nightly drift plan on main (alert-on-diff, never auto-apply).

**Verify:** nightly run posts "no diff" (or a real diff gets human eyes).

## Task 23.4 — `build-publish.yml` (main only)

- [ ] Test → buildx ARM64+AMD64 → scan → push OCIR (sanctioned token ONLY here) → SBOM/provenance → digest manifest artifact.

**Verify:** artifact contains 8 digests matching Phase 22 pins.

## Task 23.5 — `deploy-prod.yml` (`production`, human approval)

- [ ] OIDC → public-endpoint kubeconfig (short-lived, no tunnel) → render Vault secrets → migrate-Jobs SERIALLY + `wait` each (any failure ABORTS before rollout) → `kustomize build overlays/prod | kubectl apply -f -` → `rollout status` each → `warm-bff.sh` (best-effort) → smoke suite → metadata to `docs/releases/`.

**Verify:** dry-run (`--dry-run=client` + kubeconform) passes; approval gate blocks unapproved runs.

## Task 23.6 — `release.yml` (tag `v*`)

- [ ] Conventional-commits changelog; Release with digest table + SBOM links + rollback pointer (prior digests + forward-fix note, down-migrations never run in production).

**Verify:** test tag on a scratch branch produces a correct draft release (delete after).

## Task 23.7 — Rollback runbook

- [ ] `docs/runbooks/rollback.md`: exact commands (prior release dir, `rollout undo` semantics, forward-fix migrations, LB/DNS untouched). Walk it once against staging state.

**Verify:** walk-through log pasted in PR.

## Task 23.8 — Phase gate (adversarial fixtures)

- [ ] Broken-migration PR fails at the migration job (fixture tested).
- [ ] Cross-importing PR fails at no-cross-import (fixture tested).
- [ ] Fork simulation: no credential access.

## Phase gate

- [ ] 7 workflows green · [ ] serial migrations proven · [ ] guards proven with fixtures · [ ] rollback walkable · [ ] only OCIR+Cloudflare long-lived tokens

**DO NOT:** `apply -auto-approve` from branches, re-plan inside apply, or expose Vault/OCIR to forks.

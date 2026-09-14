# Phase 0 — Repository scaffold + decision freeze (tasks 0.1–0.9)

**GOAL:** an empty-but-complete monorepo where every later phase has a place to put things.
**START ONLY WHEN:** nothing. This is first.
**Workdir:** `walfa/` (create if missing).

## Task 0.1 — Directory tree

- [x] Create the full tree from master §3 verbatim (every directory, even if empty).
- [x] Add `.gitkeep` to every still-empty directory.
- [x] Add `docs/adr/`, `docs/specs/`, `docs/releases/`, `docs/validation/`, `docs/keycloak/`, `docs/runbooks/`.

**Verify:** `find . -type d | sort` matches master §3 plus the docs dirs above.

## Task 0.2 — Go workspace pin

- [x] Run `go version`, note the exact version.
- [x] Write `go.work` pinning exactly that version (e.g. `go 1.27.0` per versions table §30.1b — if newer stable exists, update the TABLE first).
- [x] Record the version in ADR-000 (see 0.6).

**Verify:** `go version` output == pinned version. No service modules exist yet.

## Task 0.3 — Taskfile (go-task v3, never Make)

- [x] Write root `Taskfile.yml` with tasks: `fmt lint test test-race build docker-build migrate-status dev-up dev-down dev-logs` (`build` loops `services/*/`).
- [x] Runner CLI version pinned per versions table §30.1b, recorded in ADR-000.
- [x] Every task either works or prints a TODO-with-issue-link. No `Makefile` exists.

**Verify:** `task --list` shows all tasks; `task fmt && task test && task build` exit 0.

## Task 0.4 — Secrets hygiene from day one

- [x] Write `.gitignore`: `*.tfvars *.tfstate* .terraform/ *.pem *.key *.sso *.p12 cwallet.sso ewallet.p12 tnsnames.ora sqlnet.ora .env .env.* node_modules/ dist/ .nuxt/ *.log .DS_Store`.

**Verify:** `git check-ignore -q terraform.tfvars && echo IGNORED` (create a dummy first, delete after).

## Task 0.5 — Base documents

- [x] `README.md`: what WALFA is, "not HA" honesty, self-contained-services law (ADR-018 link), links to master plan + phases file + `tasks/`.
- [x] `ARCHITECTURE.md`: master §1 diagram + bounded-context table, copied verbatim.
- [x] `CONTRIBUTING.md`: phase discipline, one-phase-per-PR, secret rules, no-cross-import law.
- [x] `docs/versions.md`: working copy of master §30.1b table with scaffold actuals (exact tags + image digests + provider versions).

**Verify:** all four exist; links point at existing files.

## Task 0.6 — ADRs (14 files)

- [x] ADR-000: versions record — Go toolchain (from 0.2) + every versions-table actual (tags, digests, provider versions).
- [x] ADR-001..008: transcribed from master §29.
- [x] ADR-009: transport = OCI Queue, canonical (re-verified Phase 5, closed out Phase 13).
- [x] ADR-010: media upload Option A/B, may stay "deferred to Phase 11".
- [x] ADR-017: Cloudflare DNS (details land in Phase 3).
- [x] ADR-018: no shared service libraries (transcribe from master §29).
- [x] ADR-019: adopt applied infra as canonical (transcribe from master §29).
- [x] No legacy/migration ADR exists. Greenfield build, no prior system.

**Verify:** `ls docs/adr/ | wc -l` → `14`.

## Task 0.7 — CI placeholder

- [x] `.github/workflows/ci.yml` installs the pinned task runner, then runs `task fmt test` on `pull_request`.
- [x] Pushed to GitHub (`Walfarid/walfa`). CI triggers on `pull_request` — verified by push + branch protection requiring `ci` context.

**Verify:** green check on the scaffold PR.

## Task 0.8 — Branch protection

- [x] Apply via JSON file method (phases file Phase 0 step 8), else human clicks.
- [x] Branch protection set via `gh api`: required PR reviews (1), required status checks (`ci`), enforce admins.
- [x] Direct push to `main` blocked by branch protection (enforced after initial commit).

**Verify:** `gh api repos/$GITHUB_ORG_OR_USER/walfa/branches/main/protection --jq .required_pull_request_reviews.required_approving_review_count` → `1`.

## Task 0.9 — Phase gate

- [x] `task fmt && task test && task build` all exit 0.
- [x] `git status --porcelain` shows only intended files.
- [x] Banned-provider grep prints CLEAN:
```bash
grep -rEi "auth0|clerk|cognito|firebase|supabase|kafka|rabbitmq|redis streams|temporal" --include="*.go" --include="*.md" --include="*.yml" --include="*.yaml" . | grep -vi "do not" || echo "CLEAN"
```

## Phase gate

- [x] Tree matches master §3 · [x] `go.work` pinned · [x] Taskfile tasks run · [x] 14 ADRs exist · [x] `main` protected · [x] grep CLEAN

**DO NOT:** write service logic, Terraform, K8s manifests, or any shared package.

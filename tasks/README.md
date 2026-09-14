# WALFA task checklists — index

One file per build phase. Each file breaks its phase into numbered tasks (`N.1`, `N.2`, …).
Every task has `[ ]` checkboxes (the work) and a `Verify` block (the proof).

**Authority:** `../WALFA_PHASES.md` governs. These files are its checklist translation.
On any conflict, the phases file wins and this file gets patched.

**How to work a file:**
1. Check your phase's `START ONLY WHEN` — the previous phase's gate must be fully ticked.
2. Work tasks in order. Tick each `[ ]` only after the action is really done.
3. Run every `Verify` block. Paste output into the PR if anything is surprising.
4. Merge only when the file's `## Phase gate` is fully ticked. One phase = one PR (`phase-N-short-name`).

| File | Phase | Goal |
|---|---|---|
| `phase-00-scaffold.md` | 0 | Repo scaffold + decision freeze |
| `phase-01-local-dev.md` | 1 | Local dev loop |
| `phase-02-frozen-specs.md` | 2 | Frozen specs (documents, no code) |
| `phase-03-oci-bootstrap.md` | 3 | OCI account + operator bootstrap |
| `phase-04-adopt-terraform.md` | 4 | Adopt Terraform root + remote state |
| `phase-05-data-security.md` | 5 | Terraform additions (DB, Vault, Queue, DNS, alarms) |
| `phase-06-oke.md` | 6 | OKE CNI switch + verification |
| `phase-07-github-oidc.md` | 7 | GitHub OIDC federation + IAM |
| `phase-08-k8s-baseline.md` | 8 | K8s platform baseline |
| `phase-09-secrets.md` | 9 | Vault values + secret delivery |
| `phase-10-database.md` | 10 | Database init |
| `phase-11-keycloak.md` | 11 | Keycloak |
| `phase-12-valkey.md` | 12 | Valkey |
| `phase-13-oci-queue.md` | 13 | OCI Queue access + SDK conformance |
| `phase-14-identity.md` | 14 | Identity service |
| `phase-15-portfolio.md` | 15 | Portfolio service |
| `phase-16-publishing.md` | 16 | Publishing service |
| `phase-17-media.md` | 17 | Media service |
| `phase-18-analytics.md` | 18 | Analytics service |
| `phase-19-edge-gateway.md` | 19 | Edge gateway |
| `phase-20-web-bff.md` | 20 | Web BFF |
| `phase-21-nuxt-spa.md` | 21 | Nuxt SPA |
| `phase-22-docker-ocir.md` | 22 | Docker multi-arch + OCIR |
| `phase-23-cicd.md` | 23 | Full GitHub Actions CI/CD |
| `phase-24-validation.md` | 24 | Production validation on free capacity |
| `phase-25-hardening-handoff.md` | 25 + 25b | Hardening + DR + cost audit + handoff |

Global laws (every phase, no exceptions): no secrets in git · cost tripwire (Always Free only)
· single-LB tripwire (max 1 LB) · no cross-service imports · no shared packages.

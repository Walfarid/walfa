# Phase 7 — GitHub OIDC federation + IAM (tasks 7.1–7.5)

**GOAL:** CI deploys with short-lived identity; OCIR token exception caged.
**START ONLY WHEN:** Phase 6 done (nodes Ready).

## Task 7.1 — FIX the dynamic group rule (ADR-014)

- [ ] Adopted group `walfa-gha` EXISTS but its rule (`instance.compartment.id`) matches compute instances — USELESS for GitHub OIDC. REPLACE with exact claim `repo:$GITHUB_ORG_OR_USER/walfa:*` (per Oracle OIDC tutorial).
- [ ] DELETE the commented-out `manage all-resources in tenancy` placeholder (replaced by 7.2 scoped policies — must never be uncommented).
- [ ] Rule recorded verbatim in ADR-014.

**Verify:** group shows the repo-claim rule; plan shows rule replacement + placeholder deletion ONLY.

## Task 7.2 — Three scoped policies

- [ ] `walfa-ci-plan`: inspect/read infra in WALFA compartment only.
- [ ] `walfa-ci-apply`: manage VCN/OKE/DB-net/Vault-use in WALFA compartment only. No tenancy-wide rights.
- [ ] `walfa-ci-deploy`: use OKE + read OCIR + use Vault secrets.
- [ ] Plan and apply are DIFFERENT principals.

**Verify:** `oci iam policy list` shows all three; none contains `manage all-resources` or tenancy scope.

## Task 7.3 — GitHub environments + secrets

- [ ] Environments: `terraform-plan` (no approval); `terraform-apply` + `production` (human reviewer, no bypass).
- [ ] Secrets ONLY: `OCI_TENANCY_OCID OCI_REGION OCI_COMPARTMENT_OCID OCIR_NAMESPACE OCIR_TOKEN_USER OCIR_TOKEN CLOUDFLARE_API_TOKEN CLOUDFLARE_ZONE_ID`.
- [ ] Human user API key (adopted `providers.tf`) stays LOCAL/BOOTSTRAP ONLY — never in GitHub. CI uses OIDC exclusively.
- [ ] OCIR machine user created (repos push/pull in WALFA compartment ONLY); token stored; 90-day rotation issue filed (combined with Cloudflare token).

**Verify:** secret list matches exactly (no PEM, no private keys); rotation issue open with date.

## Task 7.4 — Skeleton workflows

- [ ] Extend `ci.yml`; add `terraform-plan.yml` (PR: fmt/validate/plan + summary comment).
- [ ] `terraform-apply.yml` (main + `production` approval: OIDC → apply SAVED plan artifact, never re-plan).

**Verify:** files exist; `apply` references an artifact download step, not a fresh plan.

## Task 7.5 — Phase gate (live loop test)

- [ ] Test PR (Terraform comment only) → plan workflow posts zero-diff summary.
- [ ] Empty commit to main → apply workflow WAITS for approval (do not approve unless a change is pending).

## Phase gate

- [ ] OIDC works, no API keys in GitHub · [ ] plan/apply split · [ ] rotation issue · [ ] test PR proves loop

**DO NOT:** store OCI private keys in GitHub, grant tenancy-wide rights, auto-approve applies.

# Phase 9 — Vault values + secret delivery (tasks 9.1–9.5)

**GOAL:** every secret in exactly one home (master §10); least-privilege delivery; rotation proven early.
**START ONLY WHEN:** Phase 8 done.

## Task 9.1 — Fill 10 Vault secrets (human, local CLI)

- [ ] `openssl rand -hex 32` locally per secret; `oci vault secrets secret create-base64` for: 5× `db-*-password` (PLACEHOLDERS now → real in Phase 10), `wallet-password`, `keycloak-admin` (32+ chars), `oidc-client-secret`, `session-secret` (64 hex), `valkey-password`.
- [ ] NOT now: `par-issuer-key` (only if ADR-010 → Option A in Phase 11).
- [ ] Verify by LISTING only. Never print payloads, never via Terraform values.

**Verify:** 10 secrets listed; `git status` clean (nothing written to repo).

## Task 9.2 — CI-rendered Secret templates

- [ ] `infra/kubernetes/base/secrets/*.tmpl.yaml`: placeholders `REDACTED-BY-CI`, `stringData`, one Secret per consumer: `identity-db portfolio-db publishing-db media-db analytics-db keycloak-admin oidc-client valkey-auth oracle-wallet edge-gateway-session`.
- [ ] Deploy workflow renders + applies (documented; full automation in Phase 23).

**Verify:** `grep -ri "REDACTED-BY-CI" infra/kubernetes/base/secrets/ | wc -l` > 0; templates: `ls infra/kubernetes/base/secrets/*.tmpl.yaml | wc -l` == 10; no real values: `grep -rEi "password\s*[:=]\s*['\"][^'\"]{4,}" infra/ || echo CLEAN`.

## Task 9.3 — Wallet mount pattern

- [ ] `oracle-wallet` template mounts read-only at `/wallet`, `TNS_ADMIN=/wallet` in the template Deployment all DB services will copy.

**Verify:** template YAML contains `mountPath: /wallet` + `readOnly: true`.

## Task 9.4 — Rotation drill + runbook

- [ ] Rotate `valkey-password` placeholder → re-render → new hash differs:
```bash
kubectl -n platform get secret valkey-auth -o jsonpath='{.data.password}'
```
- [ ] Write `docs/runbooks/secret-rotation.md` with the exact 5 commands used.

**Verify:** old vs new hash differ; runbook re-runnable from its own text.

## Task 9.5 — Phase gate (leak scan)

- [ ] `git log -p --all | grep -iE "BEGIN (RSA )?PRIVATE KEY|password\s*[:=]\s*['\"][^'\"]{4,}" || echo "NO LEAKS"`.
- [ ] Per-service Secrets exist with zero overlap; deploy logs show `***` only.

## Phase gate

- [ ] 10 Vault secrets filled · [ ] templates valueless in git · [ ] drill recorded · [ ] NO LEAKS

**DO NOT:** commit wallet files, print payloads, or share one Secret across services.

# Phase 11 — Keycloak (tasks 11.1–11.6)

**GOAL:** working OIDC provider, realm-as-code, MFA-ready, recoverable.
**START ONLY WHEN:** Phase 10 done. **Workdir:** `walfa/infra/kubernetes/base/keycloak/`.

## Task 11.1 — StatefulSet (private only)

- [ ] 1 replica — single-replica stateful workload; DB-backed sessions survive restarts, so HA at the Keycloak layer is unnecessary on free capacity, and PDB is omitted (phase-08 policy for single-replica workloads). `250m/768Mi` (inside master §11.2 band), ClusterIP Service (NEVER LoadBalancer/NodePort).
- [ ] Env: `KC_DB=oracle`, JDBC thin TNS descriptor, wallet via `JAVA_OPTS_APPEND="-Doracle.net.tns_admin=/wallet -Doracle.net.wallet_location=(SOURCE=(METHOD=file)(METHOD_DATA=(DIRECTORY=/wallet)))"`, `/wallet` from Secret.
- [ ] `KC_HOSTNAME=https://auth.$WALFA_DOMAIN`, `KC_PROXY=edge`, `--optimized --cache=local --http-enabled=false`, admin from Vault Secret.
- [ ] Image pinned `quay.io/keycloak/keycloak:26.7.3` exactly (+ digest in ADR-000; patch-review monthly per versions table).

**Verify:** pod Running; `kubectl top` inside budget; admin console NOT reachable publicly.

## Task 11.2 — Realm-as-code

- [ ] `docs/keycloak/realm-walfa.json` in git: realm `walfa`, client `walfa-web` (code flow + PKCE), redirects `https://app.$WALFA_DOMAIN/*`, origins, logout URLs, break-glass policies, WebAuthn policy.
- [ ] Imported at first boot (`--import-realm`); later changes via re-import PRs only.

**Verify:** re-import is a no-op diff.

## Task 11.3 — Issuer sanity

- [ ] `OIDC_ISSUER_URL=https://auth.$WALFA_DOMAIN/realms/walfa` recorded for Phase 19 pinning.

**Verify:** `curl https://auth.$WALFA_DOMAIN/realms/walfa/.well-known/openid-configuration` returns JSON with matching issuer.

## Task 11.4 — Break-glass + MFA

- [ ] `docs/runbooks/keycloak-recovery.md` (Vault admin pw + port-forward + re-import).
- [ ] Realm WebAuthn/authenticator MFA on; one human account tested.

**Verify:** recovery runbook executed once; MFA login succeeds.

## Task 11.5 — Close ADR-010 (media PAR decision, deadline now)

- [ ] Option A (PARs) or B (proxied). No third option, no deferral.
- [ ] Option A → create conditional `par-issuer-key` via Phase 9 procedure.

**Verify:** ADR-010 status = decided.

## Task 11.6 — Phase gate

- [ ] Browser code-flow login/logout/refresh works directly against `https://auth.$WALFA_DOMAIN` (public ingress, no tunnel).
- [ ] Forged `alg:none` token recorded as future negative test.
- [ ] Pod kill → restart → login still works (DB-backed).

## Phase gate

- [ ] Login works · [ ] realm in git · [ ] MFA on · [ ] recovery tested · [ ] usage in budget · [ ] ADR-010 closed

**DO NOT:** add Dex, store WALFA passwords, or expose admin publicly.

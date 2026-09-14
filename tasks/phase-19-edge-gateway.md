# Phase 19 — Edge gateway (tasks 19.1–19.5)

**GOAL:** every external byte inspected, stripped, limited, attributed. Own module, built AFTER what it protects.
**START ONLY WHEN:** Phases 14–18 gates green.

## Task 19.1 — Pipeline module (exact order, master §12)

- [ ] Own module (`services/edge-gateway`): strip client identity headers → request-ID → origin/CSRF → body/header limits → Valkey fixed-window rate limits per IP+route (beacon stricter) → OIDC/session (pinned issuer `https://auth.$WALFA_DOMAIN/realms/walfa`, LOCAL allow-list `RS256, ES256`, JWKS cache, OWN fake-OIDC in tests) → context injection (`X-Request-Id/X-Trace-Id/X-Authenticated-User-Id/X-Service-Identity`) → route.
- [ ] `Dockerfile` (multi-stage, non-root, read-only FS, `linux/arm64+amd64`, no secrets) — final push Phase 22, but the file + local `docker buildx build --platform linux/arm64` smoke test happen here.
- [ ] Security headers on all responses. `/health/*` open; default-deny + explicit public allow-list (GET reads, beacon POST, login callbacks).

**Verify:** module builds; pipeline order asserted by a middleware-chain test.

## Task 19.2 — Negative tests (all green)

- [ ] Unauthenticated mutation → 401; forged `X-Authenticated-User-Id` stripped (downstream sees server value); burst → 429 + `Retry-After`; `alg:none` → 401; oversized body → 413.

**Verify:** each case an automated test, all green.

## Task 19.3 — Manifests

- [ ] `infra/kubernetes/base/edge-gateway/`: Deployment (requests/limits from master §11.2 band, replicas 2, soft pod anti-affinity, PDB minAvailable 1, probes: `liveness /health/live period 20s failureThreshold 3`, `readiness /health/ready period 10s failureThreshold 3`) + ClusterIP + NetworkPolicy (only workload allowed to receive ingress traffic).

**Verify:** render + dry-run clean.

## Task 19.4 — Bypass impossibility (network layer)

- [ ] From a debug pod, curl downstream services directly → timeout (NetworkPolicies).

**Verify:** bypass attempts logged in PR with timeouts shown.

## Task 19.5 — Phase gate (human review)

- [ ] Public-route allow-list reviewed + approved by human.

## Phase gate

- [ ] All negative tests green · [ ] bypass impossible · [ ] allow-list human-approved

**DO NOT:** add business logic, DB access, temp admin routes, or a shared auth package.

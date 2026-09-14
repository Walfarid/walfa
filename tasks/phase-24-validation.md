# Phase 24 — Production validation on free capacity (tasks 24.1–24.7, in order)

**GOAL:** whole stack, CI-deployed, stable under load and failure. Human on standby.
**START ONLY WHEN:** Phase 23 done.

## Task 24.1 — Full production deploy + prod TLS

- [ ] Run `deploy-prod.yml` to production: migrate-Jobs → Deployments → ingress → FIRST `letsencrypt-prod` certs (DNS-01).
- [ ] Full (strict) proof: `curl --resolve app.$WALFA_DOMAIN:443:<LB-IP> https://app.$WALFA_DOMAIN/` shows valid LE origin cert.

**Verify:** origin check output pasted; not just the edge cert.

## Task 24.2 — Smoke suite

- [ ] `scripts/smoke-prod.sh` (committed): HTTPS 200s, login→CRUD→logout, beacon 204, sitemap valid, `/metrics` internal-only.

**Verify:** script exits 0 end-to-end.

## Task 24.3 — Load test (free physics)

- [ ] `scripts/load-prod.js` (k6, committed): ≤8 Mbps / 50 VUs. Assert p95 + zero 5xx + LB unsaturated + ≥20% memory headroom against the PAYG-MAX 24 GB A1 envelope (≈4.8 GB free).
- [ ] Headroom fails → shed analytics workers/retention frequency FIRST (ADR), never raise §11.2 bands silently.

**Verify:** k6 summary pasted; headroom numbers shown.

## Task 24.4 — Connection audit

- [ ] `SELECT COUNT(*) ... GROUP BY username` vs §7.4a: total ≤40.

**Verify:** query output pasted, math shown.

## Task 24.5 — Chaos set (one at a time, time each recovery)

- [ ] Delete one app pod → recovery time recorded.
- [ ] Delete Valkey pod → sessions survive via AOF replay (`INFO persistence` confirms), time recorded.
- [ ] Restart Keycloak → old sessions continue, new logins pause, time recorded.
- [ ] Pause Queue consumers 60s (`kubectl scale deploy -n apps -l app.kubernetes.io/consumes-queues --replicas=0`) → backlog alarm fires → scale back → drains, zero loss. Time it.
- [ ] Fill media tmp → 7d lifecycle purges (simulate with short-prefix test rule, DELETE the rule after).

**Verify:** five timings in `docs/validation/prod-YYYY-MM-DD/`.

## Task 24.6 — Wallet-rotation rehearsal

- [ ] Re-download wallet → update Secret → rolling restart → zero-downtime proof.

**Verify:** no failed requests during restart (smoke re-run clean).

## Task 24.6b — Rate-limit independence

- [ ] Two distinct clients (different `X-Forwarded-For`) burst concurrently; assert each is limited independently.

**Verify:** result recorded in `VALIDATION.md`.

## Task 24.6c — Node-drain chaos

- [ ] `kubectl cordon` + `kubectl drain` one node (evicting stateless pods) → all seven stateless Deployments stay available (replicas 2 + PDB minAvailable 1) → record zero-downtime proof → `kubectl uncordon` the node → confirm all pods re-scheduled and healthy.

**Verify:** recovery timeline + pod displacement count in `docs/validation/prod-YYYY-MM-DD/`.

## Task 24.7 — Validation pack + gate

- [ ] All seven task logs committed under `docs/validation/prod-YYYY-MM-DD/`.
- [ ] Every referenced runbook executed once with real commands pasted.
- [ ] Master §24 table fully ticked in `VALIDATION.md`.

## Phase gate

- [ ] Stable with headroom · [ ] chaos timed · [ ] sessions ≤ budget · [ ] prod TLS + renewal calendar entry · [ ] pack committed

**DO NOT:** raise limits to pass, skip wallet rehearsal, or declare victory on staging certs.

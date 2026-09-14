# Phase 20 — Web BFF (tasks 20.1–20.5)

**GOAL:** fast public reads that survive downstream restarts. Own module.
**START ONLY WHEN:** Phase 19 done.

## Task 20.1 — Aggregate endpoints (own module)

- [ ] `services/web-bff`: homepage, public profile, article render, sitemap.xml, robots.txt, ads.txt-if-needed, canonical-URL helpers. Reads service APIs THROUGH the gateway. No writes, no DB.
- [ ] `infra/kubernetes/base/web-bff/`: Deployment (replicas 2, soft pod anti-affinity, PDB minAvailable 1) + ClusterIP + NetworkPolicy (per skeleton §391; no write endpoints, no DB, no migrate-Job).

**Verify:** module builds; endpoint list matches sitemap/SEO needs; manifests render + dry-run clean.

## Task 20.2 — Cache + precise invalidation

- [ ] Own Valkey client per `valkey-keys.md` (`bff:public:`, TTL ≤300s). Own Queue consumer per `queue-topology.md` (oci-go-sdk, long-poll): on `portfolio.*`/`publishing.*` → precise key DEL, never flush-all.

**Verify:** publish event → key invalidated within 10s (test asserts fresh content).

## Task 20.3 — Stale-while-revalidate

- [ ] Downstream down → serve stale with `Warning: 110` semantics logged. Cold empty cache → slow-but-correct render, no 500s.

**Verify:** stop portfolio Deployment → public pages 200 from cache (test, then restore).

## Task 20.4 — Warm hook

- [ ] `scripts/warm-bff.sh`: curls top routes post-deploy (best-effort, logged, never blocks rollout). Wired into `deploy-prod.yml` later (Phase 23).

**Verify:** run twice; second pass shows higher cache hit-rate in logs.

## Task 20.5 — Phase gate (SEO artifacts)

- [ ] Sitemap validates (validator run, canonical/OG tags checked).

## Phase gate

- [ ] Stale-serving proven · [ ] invalidation precise · [ ] SEO valid · [ ] warm hook committed

**DO NOT:** add writes, DB access, immortal keys, or a shared caching library.

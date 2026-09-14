# Phase 12 — Valkey (tasks 12.1–12.4)

**GOAL:** authed cache/session/rate-limit backbone with proven graceful degradation.
**START ONLY WHEN:** Phase 11 done. **Workdir:** `walfa/infra/kubernetes/base/valkey/`.

## Task 12.1 — Manifests

- [ ] Image `valkey/valkey:9.1.1` (+ digest in ADR-000); StatefulSet 1× (`100m/512Mi`, `--maxmemory 512mb --maxmemory-policy allkeys-lru`, `requirepass` from Secret, AOF persistence enabled (`appendonly yes`, `appendfsync everysec`) on a 10 GB PVC (`storageClassName` per OKE default; `volumeClaimTemplates` `10Gi`)).
- [ ] ClusterIP `valkey.platform.svc:6379`; NetworkPolicy apps-only; NO PDB (document why: single replica). NO shared client wrapper (each service writes its own per `valkey-keys.md`).

**Verify:** `kubectl -n platform get statefulset valkey`; wrong password rejected (`redis-cli -a wrong ping` → NOAUTH/error).

## Task 12.2 — Throwaway conformance client (DELETE after)

- [ ] Temporary client (thin wrapper over `valkey-go`, per versions table) implementing `docs/specs/valkey-keys.md` prefixes + TTLs; proves layout works.
- [ ] DELETE it afterwards. It must NOT become a shared helper (that would violate ADR-018).

**Verify:** prefixes + TTLs observed in Valkey; client files removed (`git status` clean of them).

## Task 12.3 — Eviction + restart behavior (AOF recovery proof)

- [ ] Fill test (mass SET with TTLs) → `INFO memory` shows `allkeys-lru` evicting.
- [ ] Delete pod → data retained via AOF on PVC; `INFO persistence` confirms `aof_enabled:1`, `aof_last_bgrewrite_status` clean after reload → sessions SURVIVE (re-login NOT required — document recovery timeline in runbook).
- [ ] `kubectl top` inside budget.

**Verify:** eviction log + restart log pasted into runbook.

## Task 12.4 — Phase gate

- [ ] Auth enforced · [ ] AOF persistence live on 10 GB PVC · [ ] layout proven then client deleted · [ ] restart survival documented · [ ] usage in budget.

## Phase gate

All of 12.4 ticked.

**DO NOT:** share across envs, store TTL-less keys, or keep the throwaway client.

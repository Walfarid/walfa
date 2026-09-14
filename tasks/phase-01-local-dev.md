# Phase 1 — Local dev loop (tasks 1.1–1.5)

**GOAL:** any engineer/LLM runs the whole dependency set locally in one command.
**START ONLY WHEN:** Phase 0 gate fully ticked.
**Workdir:** `walfa/`.

## Task 1.1 — Compose file

- [x] Write `scripts/dev-compose.yml` (pinned minor versions, ARM64+AMD64 images):
  - `oracle`: `gvenzl/oracle-free:slim`, `ORACLE_PASSWORD=dev-only-not-secret`, PDB service `FREEPDB1`
  - `valkey`: `valkey/valkey:9.1.1`, password `dev-only`
  - `keycloak`: `quay.io/keycloak/keycloak:26.7.3` with `start-dev`, admin `admin/admin`
- [x] File states LOUDLY that these credentials are dev-only.
- [x] Image digests recorded in ADR-000 (`docker images --digests` after first pull).
- [x] No Queue container: OCI Queue has no local emulator (strategy in 1.4).

**Verify:** `docker compose -f scripts/dev-compose.yml config` parses without errors.

## Task 1.2 — Make targets

- [x] `task dev-up` → `docker compose -f scripts/dev-compose.yml up -d`.
- [x] `task dev-down` → `... down -v`.
- [x] `task dev-logs` → `... logs -f`.

**Verify:** `task dev-up && sleep 10` then:
```bash
docker ps --format "{{.Names}} {{.Status}}" | grep -Ei "oracle|valkey|keycloak"   # 3 containers Up
```

## Task 1.3 — Seed script

- [x] Write `scripts/dev-seed.sh`: waits for Oracle (`docker exec` health loop, timeout 300s), prints host/ports/users summary.
- [x] Script is idempotent (safe twice in a row). `chmod +x`.

**Verify:** `scripts/dev-seed.sh && scripts/dev-seed.sh` — second run exits 0 with no errors.

## Task 1.4 — Document the loop

- [x] `CONTRIBUTING.md` ports table: Oracle 1521, Valkey 6379, Keycloak 8080.
- [x] Document `DB_WALLET_ENABLED=false` locally; dev passwords never reused in production.
- [x] Document Queue test strategy: unit/integration use each service's OWN in-memory fake; real tenancy Queue proven in Phase 13/24.

**Verify:** ports in doc match `dev-compose.yml` (`grep` both, compare).

## Task 1.5 — Phase gate

- [x] `task dev-down` removes all compose containers.
- [x] Nothing in this phase touched OCI (no `oci` CLI calls, no cloud resources).

```bash
task dev-down && docker ps -q | wc -l   # compose containers gone (0, or only unrelated)
```

## Phase gate

- [x] 3 healthy containers on `dev-up` · [x] seed idempotent · [x] ports documented · [x] Queue fake strategy documented · [x] zero OCI contact · [x] image digests in ADR-000

**DO NOT:** use dev passwords anywhere else; put real credentials in compose.

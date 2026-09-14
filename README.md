# WALFA Portfolio

Personal portfolio platform: 7 self-contained Go services + 1 Nuxt SPA, running on OCI Always Free.

## Reality check

The free profile is **not** highly available. Single availability domain, single Valkey instance, single Keycloak instance, 10 Mbps load balancer. Two replicas with PodDisruptionBudgets provide node-redundancy for stateless services, but this is not high availability. The system is designed for backup/restore, not zero-downtime failover.

## Self-contained services

Each service is its own Go module. There are **no shared libraries** — no `packages/` tree, no common Go module. Compatibility comes from frozen spec documents (`docs/specs/`) and per-service conformance tests. See [ADR-018](docs/adr/ADR-018-no-shared-libraries.md).

## Plans

- [Master build plan](WALFA_BUILD_MASTER.md) — architecture, rules, non-negotiables
- [Phase execution order](WALFA_PHASES.md) — exact steps with verification gates
- [Task checklists](tasks/README.md) — per-phase checkbox files

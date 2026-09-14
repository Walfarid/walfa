# ADR-007 — Free profile is not HA

**Status:** Accepted
**Date:** 2026-09-14
**Deciders:** platform-team

## Context
Free-tier limits (single AD, single Valkey/Keycloak, 10 Mbps LB) do not justify HA claim.

## Decision
Designed for backup/restore, not zero-downtime failover. 2 replicas with PDBs for stateless node-redundancy.

## Consequences
Runbooks focus on restore; no multi-AZ; honest failure-domain docs.

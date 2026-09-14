# ADR-019 — Adopt applied infra as canonical

**Status:** Accepted
**Date:** 2026-09-14
**Deciders:** platform-team

## Context
infra-new/ was already applied (OKE + VCN + bastion host + OCIR + bucket + IP + tags + logs + state). Greenfield layout would fight reality.

## Decision
Adopt: module-managed network, bastion host, PUBLIC API endpoint (guarded), VCN-native CNI (switched pre-workload), walfa tag namespace, prod env name, ObjectRead media bucket, reserved-IP reuse. Fix broken: dynamic-group rule (Phase 7), bastion CIDRs (Phase 4), CNI (Phase 6).

## Consequences
Flat single-root Terraform. infra-new/ relocated to infra/terraform/ with state migrated to S3 backend. No parallel systems.

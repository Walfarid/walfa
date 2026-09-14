# ADR-001 — Terraform is infrastructure source of truth

**Status:** Accepted
**Date:** 2026-09-14
**Deciders:** platform-team

## Context
Reproducibility, reviewability, drift control.

## Decision
Terraform owns all OCI infrastructure; state in OCI Object Storage S3-compatible backend; no manual provisioning.

## Consequences
All infra changes via PR review; drift detected by plan.

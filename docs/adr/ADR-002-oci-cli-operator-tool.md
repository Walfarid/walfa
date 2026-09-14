# ADR-002 — OCI CLI is operator tooling

**Status:** Accepted
**Date:** 2026-09-14
**Deciders:** platform-team

## Context
Interactive auth/troubleshooting differs from declarative infra.

## Decision
CLI for human auth, inspection, debugging, one-time bootstrap only — never source of truth.

## Consequences
Terraform canonical; CLI for kubeconfig gen, wallet download, quota checks.

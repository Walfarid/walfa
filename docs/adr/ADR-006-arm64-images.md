# ADR-006 — ARM64-first production images

**Status:** Accepted
**Date:** 2026-09-14
**Deciders:** platform-team

## Context
Always Free OKE uses Ampere A1 (ARM64).

## Decision
All images build linux/arm64 + linux/amd64; ARM64 primary.

## Consequences
Docker buildx; CGO_ENABLED=0; no C deps lacking ARM64.

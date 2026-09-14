# ADR-003 — Self-hosted OIDC

**Status:** Accepted
**Date:** 2026-09-14
**Deciders:** platform-team

## Context
No SaaS identity dependency.

## Decision
Keycloak is canonical self-hosted OIDC provider. Dex is optional broker only.

## Consequences
Keycloak as OKE platform workload; WALFA never stores passwords.

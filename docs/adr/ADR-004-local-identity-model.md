# ADR-004 — Local WALFA identity model

**Status:** Accepted
**Date:** 2026-09-14
**Deciders:** platform-team

## Context
External OIDC subject and app user record are separate concerns.

## Decision
identity service stores WALFA-specific records keyed by (issuer, subject), not email. No password storage.

## Consequences
Stable OIDC subject; email changes do not break identity.

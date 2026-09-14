# ADR-010 — Media uploads via PARs (Option A default)

**Status:** Deferred to Phase 11
**Date:** 2026-09-14
**Deciders:** platform-team

## Context
Two options for upload authorization: Option A (PARs, direct-to-bucket) or Option B (proxied through media service).

## Decision
Option A default — direct upload via pre-authenticated requests. Media service holds sanctioned PAR-issuer API key, creates one PAR per approved upload (single object, 15-min expiry, server-generated key).

## Consequences
One extra credential to rotate (90-day rhythm); bytes off cluster; must confirm/change in Phase 11.

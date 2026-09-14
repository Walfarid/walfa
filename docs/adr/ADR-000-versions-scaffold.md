# ADR-000 — Initial decision scaffold

**Status:** Accepted
**Date:** 2026-09-14
**Deciders:** platform-team

## Context
Pinned versions, toolchain, and repo layout recorded at project start.

## Decision
Go 1.27.1, go-task CLI 3.53.1, Keycloak 26.7.3, Valkey 9.1.1, Nuxt 4.5.2, Node 24 LTS, K8s v1.36.1, cert-manager v1.21.1, OCI TF provider ~>9.0 (9.1.0), Cloudflare TF provider ~>5.0 (5.24.0), OKE module 5.5.1, logging module 0.4.0, Terraform >=1.16, oracle-free slim (dev). All verified 2026-09-14.

### Container image digests (pinned 2026-09-14)
| Image | Digest |
|---|---|
| `gvenzl/oracle-free:slim` | `sha256:6d61d267a3b978c24c5ac1790e62e927416a0aec446bd86e4b3a1527562757bd` |
| `valkey/valkey:9.1.1` | `sha256:64e361b630ecf18dff7ca4df6a88e6eafc193687eb48cff2c7e0a293ab67d29a` |
| `quay.io/keycloak/keycloak:26.7.3` | `sha256:29be7252db0a106f1cd2ac17b9a56ff2668073da645638a38b9fc67deeb2d6c4` |

## Consequences
docs/versions.md is the working copy; dependabot updates table + workspace + CI in same PR.

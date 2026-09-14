# WALFA — Pinned Versions

Working copy of the versions table. Updated by dependabot PRs (table first, code second).
All versions verified 2026-09-14.

| Component | Pinned Version | Track Policy | Where Pinned |
|---|---|---|---|
| Go toolchain | 1.27.1 | latest stable; bump quarterly | go.work, ci.yml, Dockerfiles |
| go-task CLI | 3.53.1 | latest stable v3 | Taskfile.yml, ci.yml |
| Keycloak | 26.7.3 | latest stable patch on 26.x; monthly patch review | compose, StatefulSet + digest |
| Valkey | 9.1.1 | latest stable minor (9.x to 2029) | compose, StatefulSet + digest |
| Nuxt | 4.5.2 | stable major 4 ONLY (v3 EOL forbidden); v5 no earlier than 6mo after GA + ADR | package.json + lockfile |
| Node | 24 LTS "Krypton" | Active LTS satisfying Nuxt engines | CI, web Dockerfile |
| Kubernetes | v1.36.1 | OKE-supported; re-verify before upgrade | oke module |
| cert-manager | v1.21.1 | latest stable (N+2 support window) | manifests URL |
| ingress-nginx | TBD at Phase 8 | resolve version + digest at scaffold | manifests URL |
| metrics-server | TBD at Phase 8 | record version at scaffold | manifests URL |
| OCI TF provider | ~> 9.0 (9.1.0 locked) | latest major; lock committed | required_providers + .terraform.lock.hcl |
| Cloudflare TF provider | ~> 5.0 (5.24.0) | latest major v5 ONLY | required_providers + lock |
| OKE module | 5.5.1 | exact version (adopted) | main.tf |
| logging module | 0.4.0 | exact version (adopted) | logging.tf |
| Terraform CLI | >= 1.16 | adopted required_version | workflows, ADR-000 |
| oracle-free (dev) | slim + digest at Phase 1 | dev-only; multi-arch; re-pull quarterly | compose |
| golangci-lint, trivy, k6 | latest stable at scaffold | pinned SHAs in workflows | .github/ |

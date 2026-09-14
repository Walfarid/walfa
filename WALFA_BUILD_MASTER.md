# WALFA Portfolio — Canonical Infrastructure, Architecture, Implementation & Migration Engineering Plan

**Version:** 4.0
**Status:** Canonical implementation specification
**Target environment:** Oracle Cloud Infrastructure (OCI) Always Free, OKE Basic
**Repository:** GitHub
**Infrastructure as Code:** Terraform
**Container runtime:** OCI Container Engine for Kubernetes (OKE)
**Container registry:** OCI Container Registry (OCIR)
**CI/CD:** GitHub Actions with OIDC federation
**Primary database:** Oracle Autonomous AI Database / Always Free Autonomous Database
**Messaging:** OCI Queue (managed). Operator-confirmed free tier covers the workload (see §8.1, ADR-009); usage is alarmed, never assumed.
**Identity:** Self-hosted OIDC; Keycloak is the default provider. Dex is an optional broker, not the default identity server.
**Authentication provider:** Self-hosted OIDC only; no SaaS identity dependency.
**Post-quantum:** Security consideration and cryptographic-agility requirement only; this system is not designed around PQ cryptography.

---

## 0. Purpose and non-negotiable rules

This document is the source of truth for implementation. An implementation LLM must follow it instead of inventing replacement infrastructure, identity, deployment, or persistence platforms.

### 0.1 Non-negotiable decisions

1. Production runs on OCI OKE.
2. The Always Free profile is the first deployment target.
3. Terraform owns OCI infrastructure. Kubernetes manifests/Helm/Kustomize own Kubernetes resources. Application code never provisions infrastructure.
4. OCI CLI is an operator tool for authentication, inspection, debugging, and one-time bootstrap tasks. It is not the infrastructure source of truth.
5. GitHub Actions is the CI/CD control plane.
6. GitHub Actions must prefer short-lived OIDC federation over long-lived OCI API keys.
7. Images are built with Docker/Buildx and pushed to OCIR.
8. ARM64 is a required production image target because the Always Free OKE worker profile uses Ampere A1.
9. Authentication uses a self-hosted OIDC provider. Keycloak is the canonical choice. Dex may be used only when there is a concrete upstream identity-broker requirement.
10. Do not add a hosted identity provider such as Auth0, Clerk, Cognito, Firebase Auth, Supabase Auth, or another SaaS identity platform.
11. Do not implement custom username/password authentication inside WALFA. The application trusts validated OIDC identity tokens and manages application-local profile/session state.
12. Post-quantum cryptography is not the architectural center of the system. Use algorithm allow-lists, modern TLS, key rotation, and crypto agility so future PQ migration is possible.
13. Do not introduce Kafka, RabbitMQ, Redis Streams, Temporal, NATS, or another message platform — self-hosted or managed — unless this document is explicitly revised. OCI Queue is the transport.
14. Do not add a service merely because it is common in microservice diagrams. Every service needs a bounded-context reason, owner, storage boundary, API contract, and operational justification.
15. The free profile must be honest about its failure domains (single AD, single-instance Valkey and Keycloak, 10 Mbps LB). Do not label the free profile highly available.
16. Cloudflare is the canonical DNS provider. Do not create OCI DNS zones. DNS records are managed by Terraform via the Cloudflare provider; TLS issuance uses ACME DNS-01 against Cloudflare (see §5.4 `dns` module and §11.4).
17. No shared service libraries. There is no `packages/` tree, no shared Go module, no common utility repo. Each service is a self-contained Go module that owns its own copy of every behavior it needs. Cross-service compatibility comes from frozen SPEC documents (`docs/specs/`) plus per-service conformance tests — never from shared code. Duplication of small, frozen, versioned specs is intentional; a shared library is reviewed as a defect.

### 0.2 Desired operational posture

The implementation should be boring to deploy and easy for another engineer or LLM to reason about:

- deterministic repository layout;
- reproducible builds;
- immutable image tags;
- declarative infrastructure;
- explicit environment configuration;
- least-privilege IAM;
- database migrations committed to source control;
- observable background jobs;
- idempotent event consumers;
- auditable releases;
- rollback instructions for application and migration changes.

---

# 1. Target architecture

The system contains seven Go services and one Nuxt SPA.

```text
                                      Internet
                                         |
                                         v
                               +-------------------------+
                               | OCI Flexible Load Balancer|
                               |   TCP :443 passthrough   |
                               +------------+--------------+
                                            |
                                            v
                               +-------------------------+
                               |      ingress-nginx      |
                               | TLS via cert-manager /  |
                               | Let's Encrypt (§11.4)   |
                               +------------+--------------+
                                            |
                                            v
                               +-------------------------+
                               |       edge-gateway       |
                               | auth | rate limit | CSRF |
                               +------+---------------+----+
                                     |               |
                        +------------+               +------------------+
                        |                                               |
                        v                                               v
                 +-------------+                                +--------------+
                 |  web-bff    |                                |    media     |
                 | read facade |                                | upload/meta  |
                 +------+------+                                +------+-------+
                        |                                              |
                        +------------------+---------------------------+
                                           |
                                           v
                              +--------------------------+
                              |        OKE cluster      |
                              |                          |
                              | identity | portfolio    |
                              | publishing | analytics  |
                              | edge | bff | media      |
                              | Keycloak | Valkey       |
                               | queue workers (outbox dispatchers + consumers) |
                              +------------+-------------+
                                           |
                     +---------------------+----------------------+
                     |                     |                      |
                     v                     v                      v
              Oracle Autonomous DB     OCI Object Storage      OCI Queue
              service schemas          private media bucket   (managed, async events)
```

## 1.1 Bounded contexts

| Component | Responsibility | Persistence | External dependencies |
|---|---|---|---|
| `edge-gateway` | authentication enforcement, rate limits, request normalization, CSRF checks, routing | none | OIDC provider, Valkey |
| `identity` | application users, local profile linkage, active sessions, account purge | `ID_SCHEMA` | self-hosted OIDC provider, queue/event transport |
| `portfolio` | profile, experience, education, skills, projects | `PORTFOLIO_SCHEMA` | event transport |
| `publishing` | articles, tags, technical guides, policy/legal pages | `PUBLISHING_SCHEMA` | event transport |
| `media` | media metadata, upload workflow, validation, cleanup | `MEDIA_SCHEMA` | OCI Object Storage, event transport |
| `analytics` | beacon intake (`POST /api/v1/beacon` routed via gateway), aggregation, retention, removal workflows | `ANALYTICS_SCHEMA` | event transport |
| `web-bff` | public aggregation, sitemap, ads.txt, cache warming | cache only | Valkey, service APIs |
| Nuxt SPA | browser UI | browser storage only | gateway |

## 1.2 Service communication rule

Synchronous calls are allowed for read composition where a response cannot be produced correctly without current information. Cross-service transactional writes are prohibited.

Writes follow:

```text
HTTP request
   -> owning service transaction
      -> domain tables
      -> event_outbox
   -> commit
   -> outbox dispatcher
   -> message transport
   -> idempotent consumer
   -> local state/cache/read model
```

---

# 2. OCI Always Free capacity envelope

Always Free is a hard design constraint, not a suggestion. OCI's PAYG-maximum free envelope provides **4 OCPUs and 24 GB RAM** of Ampere A1 compute, spread across up to two worker nodes (2 OCPU / 12 GB each), plus up to two E2.1.Micro instances. This plan consumes the full A1 PAYG-max envelope: one node pool with 2 nodes × (2 OCPU / 12 GB), giving node-redundant capacity for stateless workloads while remaining within the free cost profile.

Autonomous Always Free databases are currently fixed at 1 CPU and 20 GB per database, with up to two Always Free Autonomous AI Database instances.

OCI's current Always Free page also lists one Flexible Load Balancer at 10 Mbps and 200 GB aggregate Always Free Block Volume storage.

### 2.1 Canonical free profile

| Resource | Canonical allocation | Purpose |
|---|---:|---|
| Ampere A1 | 4 OCPU / 24 GB total, 2 nodes (1 pool × 2 OCPU/12 GB each) | OKE worker compute |
| E2.1.Micro | 1x bastion host (retained) + 1 spare (documented) | operator SSH + `ssh -L` tunnels; bastion boot 47 GB (§11.7) |
| Autonomous AI Database | 1 Always Free instance | application data |
| Object Storage | <= 20 GB combined free-account allowance | media + Terraform state/backups, budgeted explicitly |
| Flexible Load Balancer | 1 x 10 Mbps | public ingress |
| Block Volume | ~157 GB committed of 200 GB (2× worker boot + bastion boot + Valkey PVC) | one PVC (Valkey AOF, 10 GB) |
| Vault | Always Free secrets/keys | application secrets |
| VCN | 1 (module-managed) | application network |
| OKE | 1 Basic cluster, VCN-native CNI, PUBLIC endpoint (guarded, §11.1) | orchestration |
| Registry | OCIR (8 repos, `walfa/*`) | image storage |
| Queue | OCI Queue, 5 queues + DLQ, spend-alarmed | event transport |

### 2.2 Bastion host (retained) + operator access

The OKE-module bastion host (`VM.Standard.E2.1.Micro`, 47 GB boot volume) is retained. Operator access rides this host:

- operator SSH: `terraform output ssh_to_bastion` → bastion → worker private IP (port 22);
- DB tunnels: `ssh -L` through the bastion → ADB private endpoint IP:1522;
- K8s API: public endpoint directly (no tunnel at all, §11.1).

ADR-020: `bastion_allowed_cidrs` is tightened from `0.0.0.0/0` to the operator address in Phase 4; Phase 25 audits it. The host stays; the open CIDR does not.

What stays forbidden: any app workload on VMs, any second access path, `0.0.0.0/0` on any allow-list.

The managed OCI Bastion service (session-based, IAM-authorized, auto-expiring) is a future/scale-profile option — never a Phase 4 action.

### 2.3 Free profile is not HA

The canonical free profile runs 2 worker nodes, so stateless services (all Go services, edge-gateway, web-bff) survive a single-node loss with 2 replicas spread across both nodes and PodDisruptionBudgets keeping at least 1 available. The profile is still **not** highly available: a single AD, a single Valkey instance, a single Keycloak instance, and a 10 Mbps load balancer are all single points of failure. Stateful components remain single-instance and must be designed for backup/restore and replay.

The `scale` profile later adds worker capacity beyond PAYG-max, multi-AZ/AD design, and managed or external HA dependencies.

---

# 3. Repository structure

The repository is a monorepo.

```text
walfa/
├── apps/
│   └── web/
├── services/
│   ├── edge-gateway/      # each service is a SELF-CONTAINED Go module:
│   ├── identity/          #   main.go (serve|migrate), config.go, domain/,
│   ├── portfolio/         #   store/, http/, outbox.go, consumer.go (where
│   ├── publishing/        #   applicable), *_test.go — no imports from any
│   ├── media/             #   other service, no shared packages (see §0.1-17,
│   ├── analytics/         #   §30.1a, ADR-018)
│   └── web-bff/
├── docs/
│   ├── specs/             # FROZEN specs (JSON Schema + markdown): the only
│   │                      # cross-service contract. Code is per-service.
│   ├── architecture/
│   ├── runbooks/
│   ├── releases/
│   ├── validation/
│   ├── keycloak/          # realm-walfa.json (realm-as-code)
│   └── adr/
├── db/
│   ├── migrations/
│   │   ├── identity/
│   │   ├── portfolio/
│   │   ├── publishing/
│   │   ├── media/
│   │   └── analytics/
│   └── seeds/
├── infra/
│   ├── terraform/              # ADOPTED flat single root (was infra-new/):
│   │   │                       # one dir, registry modules + resource files,
│   │   │                       # NO modules/ split, NO per-env roots.
│   │   ├── main.tf             # oke module 5.5.1: VCN, bastion host, cluster
│   │   ├── services.tf         # OCIR repos, media bucket, reserved IP, dynamic group
│   │   ├── queue.tf            # (added Phase 5) 5 queues + DLQ
│   │   ├── database.tf         # (added Phase 5) Always Free ADB
│   │   ├── vault.tf            # (added Phase 5) vault + secret shells
│   │   ├── dns.tf              # (added Phase 5) cloudflare_dns_record (v5)
│   │   ├── observability.tf    # (added Phase 5) alarms incl. Queue spend
│   │   ├── logging.tf          # VCN flow logs (existing, module 0.4.0)
│   │   ├── tags.tf             # walfa namespace (existing — imported, not recreated)
│   │   ├── locals.tf providers.tf terraform.tf variables.tf outputs.tf
│   │   └── environments/
│   │       └── prod/
│   │           └── prod.tfvars.example   # env values only (real prod.tfvars gitignored)
│   └── kubernetes/
│       ├── base/
│       └── overlays/
│           ├── prod/           # live env (free capacity profile)
│           └── scale/          # future capacity profile (README only)
├── .github/
│   └── workflows/              # incl. deploy-prod.yml
├── scripts/             # dev-compose.yml, dev-seed.sh, smoke-prod.sh,
│                      # load-prod.js, assert-podsecurity.sh
├── Taskfile.yml         # go-task v3 — the ONLY runner. No Makefile may exist.
├── go.work
├── README.md
├── tasks/               # per-phase checklist translation of WALFA_PHASES.md
│                        # (tasks/README.md index; one file per phase)
```

Terraform and Kubernetes definitions are deliberately separate.

- `infra/terraform` creates OCI resources.
- `infra/kubernetes` creates cluster workloads.
- `.github/workflows` performs CI/CD.
- `services` contains business code.
- `db/migrations` owns schema evolution.

No Terraform resource should depend on application container implementation details except where a secret, registry, identity, or infrastructure reference is structurally necessary.

---

# 4. OCI authentication model

## 4.1 Human operator authentication

OCI CLI is the human-facing tool.

Recommended operator flow:

```text
oci session authenticate
      |
      v
~/.oci/config / session token profile
      |
      +--> terraform plan/apply when doing manual bootstrap or emergency repair
      +--> oci inspection commands
      +--> Bastion session creation
      +--> OKE kubeconfig/token operations
```

Session-token authentication is appropriate for short-lived manual CLI/Terraform operations; Oracle documents `SecurityToken` authentication for the OCI Terraform provider. The token is short-lived, so it is not a good mechanism for long provisioning runs.

For routine CI, do not copy a local OCI private key into GitHub secrets.

## 4.2 GitHub Actions authentication

GitHub Actions uses GitHub's native OIDC federation to access OKE/OCI without long-lived credentials. Oracle provides an OKE GitHub Actions OIDC tutorial specifically for this model.

The desired trust path is:

```text
GitHub workflow
   |
   | OIDC token
   v
OCI trust/federation policy
   |
   v
short-lived OCI identity
   |
   +--> Terraform
   +--> OCIR
   +--> OKE deployment
```

Where an OCI integration requires a user/API key because a specific provider action has no OIDC path, isolate that exception, restrict it to the minimum resource scope, and document the secret's rotation.

Sanctioned long-lived exceptions (the only three permitted; all recorded in an ADR with rotation dates):

1. **OCIR push/pull auth token.** `docker login` to OCIR requires a username/auth-token pair; GitHub OIDC cannot perform a registry login. Create one machine user in a group whose IAM policy allows only `manage repos` in the WALFA compartment. Its auth token lives in GitHub Actions secrets, rotation every 90 days.
2. **Media-service PAR issuer credential.** If the media service issues Object Storage pre-authenticated requests directly (see §13), it needs an OCI API key for a least-privilege machine user allowed only to manage objects in the media bucket. Alternative: proxy uploads through the media service and avoid this credential entirely. The choice is recorded in an ADR in Phase 11; do not create the key speculatively.
3. **Queue client API key.** Pods on a Basic cluster have no workload identity, so every emitting/consuming service authenticates to OCI Queue with the API key of ONE least-privilege machine user (`walfa-queue-client`, IAM policy: queue operations ONLY in the WALFA compartment). Terraform creates the user, group, and policy; the human creates the API key pair via CLI/console in Phase 13 and stores the private key in Vault (`queue-client-key`). Services mount it at `/.oci/` (standard SDK file-auth, `OCI_CONFIG_FILE=/.oci/config`). Rotation every 90 days, same rhythm as the OCIR token.

## 4.3 OKE workload identity

When the cluster profile supports OKE workload identity, use it for pods that need direct OCI API access instead of placing OCI API keys in Kubernetes Secrets. Oracle documents OKE workload identity as the preferred identity model for Kubernetes workloads, and it requires an Enhanced cluster. Therefore the free profile must verify cluster-type capability before enabling it; do not silently switch the cluster class just to obtain the feature.

For the Basic/free profile, prefer service mediation through narrowly scoped backend APIs or dedicated short-lived credentials when workload identity is unavailable.

---

# 5. Terraform architecture

Terraform is the source of truth for OCI infrastructure. The root at `infra/terraform/` is ADOPTED from the previously applied `infra-new/` provisioning — flat single root, registry modules, no `modules/` split, no per-env roots. Existing state is real: OKE (VCN, bastion host, cluster), OCIR repos, media bucket, reserved IP, tag namespace, log group, and the (broken-rule) dynamic group all exist. New work ADDS files for what is missing (database, vault, queue, DNS, alarms) and FIXES what is wrong (dynamic-group rule, CNI, bastion CIDRs) — it does not rebuild what works.

## 5.1 Terraform state

The adopted root currently keeps LOCAL state (`terraform.tfstate` beside the config — it contains secrets and must never be committed). Phase 4 migrates it to the OCI Object Storage S3-compatible backend and shreds local copies only after the remote state verifies clean:

Migration sequence (once):

1. Authenticate locally with OCI CLI.
2. Confirm the WALFA compartment OCID (existing — reference, do not recreate).
3. Create the Terraform state bucket with versioning enabled (if not already present).
4. `terraform init -migrate-state` with the S3 backend config (namespace + region `ap-singapore-1`).
5. `terraform plan` must be EMPTY (migration moved state, changed nothing).
6. Shred local `terraform.tfstate*` copies; all future changes use normal `plan`/`apply`.

Terraform state (local or remote) must never be committed to Git.

## 5.2 Terraform environment separation

`prod` is the live environment (tag value `Environment=prod` — the applied tag namespace enforces an ENUM without any `free` value, so `free` must never appear as an environment identifier; `free` describes the COST PROFILE only).

`scale` is an explicit future capacity profile of the same prod environment and must never be provisioned accidentally.

Env values live in `infra/terraform/environments/prod/prod.tfvars(.example)`; the root holds ALL resources (no per-env roots to drift apart).

## 5.3 Provider configuration

Do not commit credentials into Terraform files.

Adopted reality: human/bootstrap authentication uses a user API key (`user_ocid`/`fingerprint`/`private_key_path` variables, values in gitignored `prod.tfvars` only). That key stays for LOCAL and emergency use. CI never sees it: GitHub Actions authenticates via OIDC federation (Phase 7) for plan/apply/deploy.

Home-region alias (`oci.home`, region = tenancy home region `ap-singapore-1`) is required for IAM/tag operations — keep the adopted dual-provider block.

## 5.4 Adopted resources (keep) + new files (add in Phase 5)

### Kept as-is: OKE module (`main.tf`, `oracle-terraform-modules/oke/oci` 5.5.1)

Owns the VCN (module-managed — there is NO hand-rolled network module and none will be written), the bastion host, and the cluster:

- Basic cluster, two-node A1 pool (4 OCPU / 24 GB total, 1 node pool × 2 nodes each 2 OCPU/12 GB, boot 50 GB each, OL9, ARM64, custom image ID via the `oke_worker` data-source workaround — the tenancy rejects compartment-scoped image lookup, so the region-specific image-compartment OCID stays a variable);
- PUBLIC Kubernetes API endpoint (adopted — simplifies CI/K8s access enormously; guarded by RBAC + short-lived kubeconfigs, §11.1; the private-endpoint plan is abandoned, ADR-019);
- `cni_type = "vcn-native"` (SWITCHED from applied `flannel` in Phase 6 — flannel cannot enforce NetworkPolicy, which §20.2 and the Phase 19 bypass gate depend on; nothing is deployed yet so the cluster recreates cheaply NOW; ADR-019);
- `bastion_allowed_cidrs` tightened to the operator address in Phase 4 (ADR-020; bastion host retained, §2.2), `create_operator = false` (stays false), `allow_worker_ssh_access = true` with the operator `ssh_public_key`;
- `create_iam_resources = true`; `cluster_type = "basic"` (free control plane — never Enhanced).

### Kept as-is: OCIR repos, media bucket, reserved IP (`services.tf`)

- 8 repos `walfa/edge-gateway web-bff identity portfolio publishing media analytics frontend` — note `frontend`, not `web`. Adopted; Phase 5 adds nothing here.
- `walfa-media` bucket: `access_type = "ObjectRead"` (ADOPTED — public reads of unguessable server-generated keys; LIST/WRITE still require auth; see §13), `versioning = "Enabled"`, Standard tier. Adopted.
- `walfa-ingress-ip` RESERVED public IP: adopted — Phase 8 associates it with the ingress LB (annotation key verified in ADR-015) instead of creating any new IP.

### Kept as-is: tags (`tags.tf`, `locals.tf`)

Defined namespace `walfa` with the applied tag set (Owner, Environment ENUM `dev|staging|prod|test|sandbox`, Project, Application, Component incl. all 7 services + `frontend`, CostCenter, DataClassification, SecurityLevel, AutoDelete, RetentionDays, BackupPolicy, ManagedBy, Version, Stack, Tier, SLA) and `component_tags` per-service classification (identity = confidential/high, media backup daily, tiers/SLAs). IMPORT the namespace if recreating state; never recreate it (duplicate namespaces break every `defined_tags` reference). §6 below is aligned to this reality.

### Kept as-is: logging (`logging.tf`, module 0.4.0)

`walfa_log_group` (30-day retention) + VCN flow logs. Adopted; Phase 5 adds alarms + budget, Phase 8 wires workload logs. Flow-log ingestion bytes are an explicit line item in the Phase 25 cost audit.

### Fixed in later phases (broken as applied)

- Dynamic group `walfa-gha` matching rule targets compute instances (`instance.compartment.id`) — USELESS for GitHub OIDC. Phase 7 REPLACES it with the repo-claim rule (ADR-014) and deletes the commented-out `manage all-resources in tenancy` placeholder (replaced by scoped policies).
- `bastion_allowed_cidrs` defaults to `0.0.0.0/0` — Phase 4 sets the operator address; Phase 25 audits it.
- `control_plane_is_public` + `cni_type = "flannel"` — endpoint kept public (decision above), CNI switched to `vcn-native` (decision above).

### Added in Phase 5 (missing resources)

- `database.tf`: ONE Always Free Autonomous AI Database (fixed 1 CPU / 20 GB — no tunable CPU/storage variables), private endpoint, outputs = connection strings + OCID only.
- `vault.tf`: Vault + key + the §10 secret shells (names only, values in Phase 9/13).
- `queue.tf`: five category queues + `walfa-dlq` (visibility 30s, max-delivery 10 → DLQ, retention). Confirm `oci_queue_queue` attribute names against provider 9.1.0 registry docs, record in file header.
- `dns.tf`: Cloudflare v5 `cloudflare_dns_record` (`app`, `auth`, `tls-test` → reserved IP, proxied).
- `observability.tf`: alarms (5xx, outbox-age, DB-CPU>80%, memory-pressure, cert-expiry, $0 budget incl. Queue spend + flow-log ingestion watch).

### `load-balancer` / `bastion-service` modules

Neither exists and neither will be created: the single LB is born from the ingress-nginx K8s Service (Phase 8, associated with the reserved IP), and SSH access rides the module's bastion host. A Terraform file that creates either is a defect.

### `dns` (Cloudflare — canonical, see ADR-017)

There are NO OCI DNS zones. The human creates the Cloudflare account and zone once (Phase 3); Terraform manages records only, via the Cloudflare provider **v5** (`~> 5.0`, lock file committed) authenticated with a least-privilege API token (`Zone:DNS:Edit` + `Zone:Zone:Read` on the one zone, token from env `CLOUDFLARE_API_TOKEN`, variable marked `sensitive`, never committed). The zone is passed as a plain variable (`var.cloudflare_zone_id`, from `CLOUDFLARE_ZONE_ID`) — no data-source lookup needed:

```hcl
resource "cloudflare_dns_record" "app" {
  zone_id = var.cloudflare_zone_id
  name    = "app"
  type    = "A"
  content = var.lb_reserved_ip
  proxied = true
}
```

(v5 renamed everything: `cloudflare_record`/`content`-vs-`value` shapes from v4 guides DO NOT APPLY. Confirm the final argument names against the pinned v5 registry docs in Phase 5 and record them in the module README.)

Records: `app.<domain>`, `auth.<domain>` (proxied/orange-cloud, permanent), and `tls-test.<domain>` (proxied, used by the Phase 8 staging-TLS verification Ingress; kept afterwards as the permanent TLS-canary host), all pointing at the LB reserved IP. Cloudflare SSL mode must be **Full (strict)** so edge-to-origin traffic is validated against the cert-manager origin certificates (§11.4). Optional hardening (Phase 25, not a gate): restrict LB-subnet ingress to Cloudflare IP ranges (https://www.cloudflare.com/ips/) — ranges change, so this is a documented periodic check, not a one-time rule.

Valkey is deliberately NOT a Terraform module: it is a Kubernetes platform workload defined in `infra/kubernetes/base/` (see §11.6). Messaging needs no cluster workload at all — OCI Queue is managed (see §8.1). Terraform owns OCI resources only.

### `observability`

Creates logging, alarms, notifications, and budget/resource monitoring within free-tier limits.

---

# 6. Terraform tagging and governance

The applied Defined Tag Namespace is `walfa` (`tags.tf`) — IMPORT it if rebuilding state, NEVER recreate it (a duplicate namespace orphans every `defined_tags` reference). The applied tag set is binding:

```text
walfa
├── Owner            ENUM platform-team|dev-team|ops-team|security-team (= platform-team)
├── Environment      ENUM dev|staging|prod|test|sandbox (= prod for live; NO "free" value exists)
├── Project          (= walfa-platform)
├── Application      (free text service name)
├── Component        ENUM edge-gateway|web-bff|identity|portfolio|publishing|media|analytics|frontend|network|storage|compute|database
├── CostCenter       (chargeback code)
├── DataClassification ENUM public|internal|confidential|restricted|pii|pci (= internal default)
├── SecurityLevel    ENUM low|medium|high|critical (= medium default)
├── AutoDelete / RetentionDays / BackupPolicy / Version / Stack / Tier / SLA
└── ManagedBy        ENUM terraform|manual|cloud-guard|resource-manager (= terraform)
```

Per-component classification (`component_tags` in `tags.tf`) is adopted as the security baseline: identity = confidential/high tier-1; media = storage tier with daily backup; network tier-1. New resources copy the nearest component block — no new tag keys without an ADR (ENUM changes are breaking).

Do not hardcode a personal owner name anywhere. Every persistent OCI resource carries the common defined tags plus freeform `Stack=oke, Project=walfa`.

---

# 7. Database architecture

## 7.1 Database selection

Use one Always Free Autonomous AI Database for the application, with logical schemas/users per service.

The current Always Free database baseline is fixed at 1 CPU and 20 GB, so application design must prioritize compact schemas, indexes only where justified, bounded retention, and careful connection pooling.

## 7.2 Schemas

```text
ID_SCHEMA
PORTFOLIO_SCHEMA
PUBLISHING_SCHEMA
MEDIA_SCHEMA
ANALYTICS_SCHEMA
```

Each service owns its schema.

Cross-schema writes are prohibited.

Cross-service reads should occur through service APIs or materialized read models rather than direct table access.

## 7.3 Database credentials

Create one database user per schema.

Credentials live in OCI Vault.

Never commit passwords into SQL migrations, Terraform variables, Helm values, or GitHub Actions YAML.

Avoid SQL examples that contain real-looking static passwords. Use placeholders such as `${DB_PASSWORD}`.

## 7.4 Connection pooling

The Go application uses `database/sql` with deliberately small pools because the database is resource constrained.

Example:

```go
db.SetMaxOpenConns(5)
db.SetMaxIdleConns(2)
db.SetConnMaxLifetime(15 * time.Minute)
```

The exact pool limits must be configured per service and load-tested rather than copied blindly.

### 7.4a Global connection budget

One Always Free Autonomous Database has a small session ceiling shared by ALL consumers. The sum of every pool must stay under a fixed budget or the database will refuse connections at the worst possible moment.

Canonical budget (total ≤ 40 sessions, rest reserved for admin/retry headroom):

```text
identity        MaxOpenConns 4
portfolio       MaxOpenConns 4
publishing      MaxOpenConns 4
media           MaxOpenConns 4
analytics       MaxOpenConns 4
edge-gateway    MaxOpenConns 0 (no direct DB access; stateless)
web-bff         MaxOpenConns 0 (no direct DB access; via service APIs + Valkey)
keycloak        max-pool-size 10 (Quarkus datasource setting)
migration jobs  MaxOpenConns 2 each, run serially, never in parallel
------------------------------------------------
TOTAL                              ~32 peak
```

Rules: no service other than the five listed plus Keycloak may open a database connection. Migration Jobs run one at a time (CI `needs:` chain or serial `kubectl apply` + `wait`). If a new consumer is added, this table is revised first and some other pool is reduced.

### 7.4b Oracle connectivity: driver, wallet, TLS

Autonomous Database enforces mutual TLS; every Go service connects with an Oracle wallet, not a bare password + hostname.

- Driver: `go-ora` (pure Go, no Oracle Instant Client needed, keeps distroless/ARM64 images small). Do NOT use `godror` (requires C client libraries, breaks minimal images).
- Each service pod mounts the wallet from a read-only Kubernetes Secret (`oracle-wallet`, synced from OCI Vault) at `/wallet`, with `TNS_ADMIN=/wallet`.
- Required env vars per service: `DATABASE_USER`, `DATABASE_PASSWORD` (Vault-synced Secret), `DATABASE_CONNECT_STRING` (the `_high`/`_low` TNS alias; default `_low` on free tier to limit DB CPU), `TNS_ADMIN=/wallet`.
- Wallet password (if the wallet is password-protected) is a separate Vault secret, never the same value as a DB user password.
- Local development uses the `gvenzl/oracle-free:slim` container (multi-arch amd64+arm64, maintained — XE images are x86_64-only and deprecated upstream) WITHOUT a wallet (config switch `DB_WALLET_ENABLED=false`); default PDB service is `FREEPDB1`. Wallet code paths are covered by a unit test that asserts `TNS_ADMIN` is set whenever `APP_ENV=production`.

### 7.4c Migration runner (canonical)

Migrations are embedded in each service binary (`go:embed db/migrations/<service>`) using the service's OWN minimal migrator (`internal/migrate/`, ~80 lines, implemented locally per `docs/specs/migrations.md` — goose and golang-migrate have NO Oracle dialect, so they are not used). The binary has two subcommands: `serve` and `migrate` (`migrate up|status`). No separate migrator image exists. No shared migrator package exists (§0.1-17).

CI deploys schema changes as a Kubernetes `Job` per service (`infra/kubernetes/base/jobs/migrate-<service>.yaml`), applied and awaited BEFORE the new Deployment rolls out:

```bash
kubectl apply -f infra/kubernetes/base/jobs/migrate-<service>.yaml -n apps
kubectl wait --for=condition=complete job/migrate-<service> -n apps --timeout=300s
```

Jobs run serially. Down-migrations NEVER run in production — not via binary, not by hand; rollbacks are forward-fix migrations (see Runbook C). Down files exist solely for local dev/test teardown.

## 7.5 Migration tool

There is no third-party migration tool: pressly/goose and golang-migrate support Postgres/MySQL/SQLite/MSSQL and others, but neither ships an Oracle dialect (verified against their dialect registries — do not reintroduce them on a hunch). Each service implements `docs/specs/migrations.md` instead:

- file pairs `NNNN_name.up.sql` / `NNNN_name.down.sql` (plain Oracle DDL/DML only);
- splitter rule: one statement per `;` at line end — enforced by a CI grep gate rejecting `BEGIN`, `DECLARE`, `CREATE TRIGGER`, `CREATE PROCEDURE`, `CREATE PACKAGE` in migration files (keeps the splitter safe by construction);
- version table `schema_version(version NUMBER PK, name, applied_at, checksum)` with SHA256 per file — editing an applied migration fails loudly instead of drifting silently;
- `up` applies pending files in order (second run = no-op); `status` lists applied/pending.

Migration rules:

1. Every schema change is committed.
2. `up` files must be re-runnable-safe in the only sense that matters: never edit an applied file — ship a new one.
3. Destructive migrations use a staged expand/migrate/contract approach.
4. Application code must remain compatible during rolling deployment.
5. Migration order is explicit (sequential `NNNN`).
6. CI applies migrations twice against a disposable `oracle-free` database (second run must be a no-op) before production.

---

# 8. Messaging architecture

## 8.1 Transport decision

**OCI Queue is the transport — managed, canonical, no fallback.** Operator-confirmed free tier (first ~1M API calls/month free, re-verified in Phase 5 and recorded in ADR-009) covers this workload with two orders of magnitude of headroom: the entire portfolio event volume (CRUD, publishing, media, beacons-aggregated, purge fan-out) is estimated at well under 50k Queue API calls/month even with dispatcher batching disabled. The estimate, the re-verification query, and a spend alarm (any Queue spend pages) are binding parts of this decision — the $0 target is guarded, not assumed.

Rules:

- One queue per event category (`walfa-identity-events`, `walfa-portfolio-events`, `walfa-publishing-events`, `walfa-media-events`, `walfa-analytics-events`) + ONE dead-letter queue (`walfa-dlq`), all created by Terraform (`queue.tf`). No channels in `free` (explicitly out of scope — competing-consumer complexity with one consumer group per category).
- Services authenticate with the sanctioned machine-user API key (§4.2, exception 3), never with human credentials, never with keys baked into images.
- Dispatcher batching is MANDATORY (PutMessages batches, long-poll GetMessages) to keep API-call volume flat, not just for latency.
- No second transport exists. NATS is not deployed, not evaluated, not kept "just in case".

## 8.1a Event envelope: frozen SPEC, per-service implementation (no shared library)

The event envelope is defined ONCE as JSON Schema in `docs/specs/event-envelope.v1.json` (fields: `event_id, occurred_at, aggregate_type, aggregate_id, entity_version, event_type, payload`; queue placement `walfa-<category>-events`, `event_type` pattern `^[a-z]+\.[a-z-]+\.v1$`). Each service implements its own envelope validation, Queue publisher (oci-go-sdk, batched PutMessages), and Queue consumer (long-poll GetMessages, DeleteMessages after commit) against that spec. No service imports envelope/transport code from another service (§0.1-17). Changing the envelope requires a version bump (`v2`), an ADR, and coordinated per-service PRs — never a silent field addition.

## 8.2 Transactional outbox

Every service that emits integration events owns an `event_outbox` table.

```sql
CREATE TABLE event_outbox (
    id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    event_id VARCHAR2(36) NOT NULL,
    queue_name VARCHAR2(128) NOT NULL,
    occurred_at TIMESTAMP WITH TIME ZONE NOT NULL,
    aggregate_type VARCHAR2(64) NOT NULL,
    aggregate_id VARCHAR2(128) NOT NULL,
    entity_version NUMBER NOT NULL,
    event_type VARCHAR2(128) NOT NULL,
    payload CLOB NOT NULL,
    attempt_count NUMBER DEFAULT 0 NOT NULL,
    next_attempt_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    published_at TIMESTAMP WITH TIME ZONE NULL,
    last_error VARCHAR2(2000) NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT uq_event_outbox_event_id UNIQUE (event_id)
);
```

Dispatcher behavior:

1. select a bounded batch;
2. lock rows with `SKIP LOCKED`;
3. publish the messages;
4. mark only successfully published events;
5. increment attempts on failures;
6. exponential backoff with jitter;
7. alert on persistent backlog;
8. never delete an event merely because one delivery attempt failed.

## 8.3 Consumer semantics

Consumers must be at-least-once safe.

Each consumer stores a durable event-processing key such as:

```text
consumer_name + event_id
```

or uses a domain-specific idempotency table.

Handlers must be safe to execute more than once.

---

# 9. Identity architecture — self-hosted OIDC only

## 9.1 Canonical provider

**Keycloak is the default self-hosted OIDC provider.**

Deploy it as a separate platform workload in the OKE cluster, with its own database schema/database user.

Keycloak provides:

- OIDC authorization code flow;
- user authentication;
- MFA capabilities;
- identity/account administration;
- signing keys and JWKS publication;
- session/logout endpoints.

WALFA does not implement password storage.

## 9.2 Dex

Dex is optional and only used when there is a concrete requirement to broker another upstream identity provider.

Dex is not required merely because the application uses OIDC.

Do not deploy both Keycloak and Dex by default.

## 9.3 WALFA identity boundary

```text
Browser
  |
  v
Keycloak
  |
  | authorization code / OIDC
  v
edge-gateway
  |
  v
identity service
```

`identity` stores WALFA-specific records, not passwords.

Example fields:

```text
user_id
subject
issuer
email
email_verified
display_name
status
created_at
updated_at
last_seen_at
```

The stable principal key is `(issuer, subject)`, not email.

## 9.4 Token validation

The gateway validates:

- issuer;
- audience;
- expiration;
- not-before if present;
- signature algorithm against an explicit allow-list;
- signature using the provider's JWKS;
- required claims.

Never accept an arbitrary `alg` from the token header.

Never trust `X-Authenticated-*` headers supplied by a client.

## 9.5 Session model

Prefer a server-side session model where practical:

```text
browser
  -> secure HttpOnly SameSite cookie
  -> gateway
  -> server-side session record/cache
  -> validated OIDC principal
```

Avoid storing bearer access tokens in browser localStorage.

## 9.6 Logout

Implement:

- local WALFA session invalidation;
- OIDC provider logout where available;
- refresh-token revocation where applicable;
- cookie deletion;
- session rotation after login.

## 9.7 MFA

MFA is configured at the identity-provider layer, not reimplemented in WALFA.

Use WebAuthn/FIDO2 or authenticator-based MFA according to the Keycloak capabilities selected for the deployment.

## 9.8 Post-quantum note

Post-quantum cryptography is a future-compatibility concern only.

Requirements:

- avoid hard-wiring cryptographic primitives throughout application code;
- use standard OIDC/JWS libraries;
- keep algorithm allow-lists centralized;
- use modern TLS;
- document key-rotation procedures;
- maintain an upgrade path for future PQ-capable TLS/signature algorithms.

Do **not** build a custom PQ authentication protocol.

Do **not** claim the application is end-to-end post-quantum secure.

---

# 10. OCI Vault and secrets

Every secret has exactly ONE home. Vault holds OCI-side secrets; GitHub holds CI-only credentials; the cluster holds short-lived rendered copies. Nothing lives in two places except the Cloudflare token (CI input → rendered cluster Secret, both from the same GitHub secret).

| Secret | Home | Created in | Consumed by |
|---|---|---|---|
| `db-identity-password` | Vault | Phase 9 (placeholder) → Phase 10 (real) | identity via rendered K8s Secret |
| `db-portfolio-password` | Vault | Phase 9 → Phase 10 | portfolio |
| `db-publishing-password` | Vault | Phase 9 → Phase 10 | publishing |
| `db-media-password` | Vault | Phase 9 → Phase 10 | media |
| `db-analytics-password` | Vault | Phase 9 → Phase 10 | analytics |
| `wallet-password` | Vault | Phase 9 | all DB services (`oracle-wallet` Secret) |
| `keycloak-admin` | Vault | Phase 9 | Keycloak StatefulSet only |
| `oidc-client-secret` | Vault | Phase 9 | edge-gateway only |
| `session-secret` | Vault | Phase 9 | edge-gateway only |
| `valkey-password` | Vault | Phase 9 | all Valkey clients |
| `par-issuer-key` | Vault (CONDITIONAL) | Phase 11, ONLY if ADR-010 chose media Option A | media only |
| `queue-client-key` | Vault | Phase 13 (human-created key pair; Terraform owns user/group/policy only) | all emitting/consuming services (`/.oci/` mount) |
| `CLOUDFLARE_API_TOKEN` | GitHub secrets (+ local env) | Phase 3 | Terraform DNS + cert-manager Secret render |
| `OCIR_TOKEN` (+ user) | GitHub secrets only | Phase 7 | `build-publish.yml` docker login only |

11 Vault secrets (+1 conditional `par-issuer-key`). The OCIR and Cloudflare tokens are NEVER in Vault (Vault holds OCI-side secrets; these authenticate TO external systems FROM CI) — but the Queue client key IS in Vault: it authenticates cluster workloads TO OCI and is rendered into pods like any workload secret.

Secrets are created in Terraform only when the secret value can be supplied securely. Terraform state can contain sensitive resource metadata or secret values depending on the resource/provider behavior, so avoid putting plaintext secret values into `terraform.tfvars`.

Prefer:

```text
human/CI secret input
      |
      v
OCI Vault secret
      |
      v
Kubernetes secret synchronization
```

For the free profile, use External Secrets only after validating its memory footprint. A lighter alternative is a small bootstrap/init mechanism that retrieves secrets and writes them into Kubernetes Secrets during deployment. Choose the simpler option that satisfies least privilege and rotation.

---

# 11. Kubernetes architecture

## 11.1 OKE cluster

Target (adopted applied provisioning, ADR-019):

- OKE Basic cluster (`walfa-free`, v1.36.1);
- two-node ARM64 A1 pool (4 OCPU / 24 GB total, 1 node pool × 2 nodes each 2 OCPU/12 GB, OL9, boot 50 GB each);
- VCN-native CNI (NOT flannel — flannel cannot enforce NetworkPolicy);
- PUBLIC Kubernetes API endpoint (adopted): access via short-lived kubeconfigs (`oci ce cluster create-kubeconfig`), cluster RBAC locked down, no static credentials; CIDR restriction applied if the module version supports it (checked in Phase 6, recorded in ADR-015; otherwise tracked as a hardening follow-up, never as silent exposure);
- private worker nodes; public exposure of workloads ONLY through the OCI Load Balancer;
- no NodePort internet exposure;
- namespaces separated by platform/application responsibility.

Known VCN-native caveat (recorded, not blocking): source client IP may arrive as the node IP on some LB paths — the gateway therefore keys rate limits on `X-Forwarded-For` (set by Cloudflare) with peer-IP fallback, and Phase 24 proves two distinct clients are limited independently. If the proof fails, the fix is Proxy Protocol/ingress tuning, never removing rate limits.

## 11.2 Node resource budgeting

The PAYG-max A1 free envelope provides 4 OCPU / 24 GB RAM across 2 nodes. Every workload needs explicit CPU/memory requests and limits. With 2 replicas of each stateless service and soft pod anti-affinity, the Kubernetes scheduler spreads replicas across both nodes — placement is scheduler-determined, not pinned to a specific node.

Start with (per-pod requests; totals must fit 24 GB across both nodes with ≥ 20 % headroom):

```text
system / kube components     protected baseline (~2–3 GB per node)
ingress                       150-250m / 256-512Mi    (2 replicas)
keycloak                      250-500m / 1-1.5Gi      (1 replica — sticky-session safety; DB-backed recovery)
edge-gateway                  100-200m / 256-512Mi    (2 replicas)
web-bff                       100-200m / 256-512Mi    (2 replicas)
identity                      100-200m / 256-512Mi    (2 replicas)
portfolio                    100-200m / 256-512Mi    (2 replicas)
publishing                   100-200m / 256-512Mi    (2 replicas)
media                        100-200m / 256-512Mi    (2 replicas)
analytics                    100-200m / 256-512Mi    (2 replicas)
valkey                       100-200m / 256Mi-1Gi     (1 replica — persistence via AOF on PVC)
(no message-transport workload exists — Queue is managed)
```

These are starting budgets, not contractual values. The real values must be measured with load tests and reduced until the cluster remains stable.

## 11.3 Namespaces

```text
platform
apps
observability
```

Use Kubernetes NetworkPolicies as a REQUIRED control (enforced: VCN-native CNI, §11.1). Default-deny per namespace; explicit allow-lists per workload. A cluster state where policies exist but are not enforced (e.g. flannel CNI) fails the Phase 8 gate.

## 11.4 Ingress

The public path is:

```text
Internet
  -> OCI Flexible Load Balancer :443 (TCP passthrough, single instance owned
     by the ingress-nginx LoadBalancer Service, see §5.4)
  -> ingress-nginx :443 (TLS termination)
  -> application service :80 (ClusterIP, private)
```

TLS terminates at ingress-nginx using certificates issued automatically by cert-manager (ACME/Let's Encrypt via DNS-01 against Cloudflare, no inbound HTTP dependency). Do NOT use OCI Certificate Service for application TLS: it adds manual issuance/renewal work and a second source of truth for certificates. The LB passes TCP through so certificate issuance and renewal are fully automatic. Internal traffic remains private inside the VCN.

cert-manager requirements: install upstream manifests at `v1.21.1` (per versions table §30.1b), create a `cloudflare-api-token-secret` Secret in the cert-manager namespace (DNS-edit-only token from §5.4 `dns`), then create TWO DNS-01 ClusterIssuers — `letsencrypt-staging` first, `letsencrypt-prod` after staging verifies:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata: { name: letsencrypt-prod }
spec:
  acme:
    email: <acme-email-from-env>
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef: { name: le-prod-account-key }
    solvers:
    - dns01:
        cloudflare:
          apiTokenSecretRef: { name: cloudflare-api-token-secret, key: api-token }
```

Annotate each `Ingress` with `cert-manager.io/cluster-issuer: letsencrypt-prod`. DNS-01 is canonical (not HTTP-01): it is unaffected by Cloudflare proxying, needs no ingress-reachability chicken-and-egg, and supports wildcards later. Renewal is automatic; Phase 25 proves it by forcing re-issuance against staging first (canary host `tls-test`). Verify Full (strict): direct-to-origin `curl --resolve app.<domain>:443:<LB-IP> https://app.<domain>/` must present a valid LE cert, not just the Cloudflare edge cert.

Oracle's current Always Free load balancer provides one Flexible Load Balancer fixed at 10 Mbps, and OKE supports using an OCI load balancer for Kubernetes services.

## 11.5 Health endpoints

Every HTTP service exposes:

```text
GET /health/live
GET /health/ready
```

Readiness must fail when the service cannot perform required work safely.

Liveness must not depend on upstream databases unless the service would otherwise deadlock permanently.

## 11.6 Platform stateful workload: Valkey (messaging is managed — §8.1)

Valkey appears in the architecture diagram and resource budget but had no specification. This section is its specification. It is single-instance on the free profile (not HA — see §2.3) and lives in the `platform` namespace with explicit requests/limits. There is NO messaging workload in the cluster: OCI Queue is a managed service (queues + DLQ in Terraform, §8.1), so nothing JetStream/streaming is ever deployed.

### Valkey (cache + rate-limit counters + server-side sessions)

- Image: `valkey/valkey:9.1.1` (per versions table §30.1b; digest recorded at scaffold), ARM64-capable.
- Topology: 1 replica `StatefulSet` with AOF persistence on a single 10 GB PVC (`valkey-data`, the only PVC in the system). AOF ensures sessions and cached data survive restarts without a full resync.
- Memory: `--maxmemory 512mb --maxmemory-policy allkeys-lru`, container resources 256Mi request / 1Gi limit.
- Auth: `requirepass` from Vault-synced Secret; every client connects with `VALKEY_PASSWORD`. No unauthenticated Valkey Service is ever exposed, even inside the cluster (bind to ClusterIP + password).
- Key namespaces (mandatory prefixes, all with TTLs — no immortal keys):
  ```text
  sess:<session-id>        server-side session record, TTL = session idle timeout
  ratelimit:<scope>:<key>  fixed-window counters, TTL = window length
  bff:public:<route>       web-bff cached aggregates, TTL <= 300s
  ```
- Eviction/rotation: LRU handles overflow; session invalidation on logout is an explicit `DEL`.
- Degradation: Valkey persistence (AOF) means a restart replays the append-only log and recovers sessions/cache — users are NOT logged out. If the PVC is lost (node + storage failure), Valkey starts empty and sessions must be re-established; Keycloak's OIDC tokens remain valid so re-authentication is transparent for active browser sessions.

## 11.7 Block-volume budget (binding)

The 200 GB aggregate Block Volume allowance is shared. Binding allocation (adopted applied provisioning):

```text
OKE worker boot volumes   2 x 50GB   100 GB  (A1 nodes, 2-node pool)
Bastion host boot volume  1 x 47GB    47 GB  (E2.1.Micro, §2.2 — the only extra VM)
Valkey AOF PVC            1 x 10GB    10 GB  (valkey-data, §11.6 — the only PVC)
container image/logs headroom          ~20 GB observed, not provisioned
------------------------------------------------
TOTAL committed                        ~157 GB of 200 GB
```

One PVC exists (Valkey AOF data, 10 GB — §11.6). No additional PVC and no additional boot volume may be created without revising this table. Keycloak and all Go services are diskless (emptyDir only for temp/scratch).

---

# 12. Gateway security model

The gateway is the trust boundary.

For every external request:

1. strip client-supplied identity headers;
2. attach a request ID if absent;
3. validate origin/CSRF where needed;
4. enforce request body and header limits;
5. apply rate limiting;
6. perform OIDC/session checks;
7. attach server-generated caller context;
8. route to internal services.

Example internal context:

```http
X-Request-Id: 018fa2b1-7a6c-7f33-8a21-4f51e06497f1
X-Trace-Id: 4bf92f3577b34da6a3ce929d0e0e4736
X-Authenticated-User-Id: 018fa2b1-9b88-7f33-8a21-4f51e06497f2
X-Authenticated-User-Email: user@example.com
X-Service-Identity: edge-gateway
```

Downstream services must only accept trusted context from authenticated internal network paths. Where stronger service identity is available, use mTLS or workload identity instead of IP-only trust.

---

# 13. Media and Object Storage

The media service controls metadata and authorization; clients upload directly to a private OCI Object Storage bucket using short-lived pre-authenticated requests or an equivalent constrained upload mechanism.

```text
client
  -> media API: request upload
  -> media validates mime/size/name
  -> media creates metadata record
  -> media issues constrained upload authorization
  -> client uploads directly to Object Storage
  -> media finalizes metadata after validation
```

Rules (adopted bucket access `ObjectRead` — reads are public by design, writes are gated):

- bucket access is `ObjectRead`: any holder of an exact object key can GET it; LIST is denied anonymously; PUT/DELETE always require auth (PAR or service credentials);
- object keys are generated server-side (unguessable: UUID + content hash — the key IS the read protection);
- user-supplied path traversal is impossible;
- MIME/type is verified from file content, not only extension;
- SVG is sanitized or rejected according to the application requirement;
- maximum object size is enforced;
- unused objects are cleaned after a grace period;
- object ownership is explicit in `MEDIA_SCHEMA`.

Do NOT "harden" the bucket to `NoPublicAccess` without an ADR: public reads are what let Cloudflare cache media and keep pods out of the hot path. Truly non-public content does not belong in this bucket.

Upload authorization decision (must be recorded in an ADR in Phase 11; LLM must not invent a third option):

- **Option A (default): direct upload via pre-authenticated requests (PARs).** The media service holds the sanctioned PAR-issuer API key from §4.2, creates one PAR per approved upload (single object, 15-minute expiry, server-generated object key), and the client PUTs bytes directly to Object Storage. Least cluster bandwidth, one extra credential to rotate.
- **Option B: proxied upload through the media service.** No OCI credential in the service; the service streams bytes to Object Storage itself. Simpler IAM, but every byte transits the media pod (memory limits + 10 Mbps ingress budget suffer).

Do not implement both. PARs are per-upload, never per-user or long-lived.

Always Free Object Storage currently has a combined free allowance; the exact allowance differs by free-account state, so the deployment should enforce a configurable storage budget rather than assuming unlimited 10 GB of Standard storage. Oracle currently documents 20 GB combined for an Always Free-only account and different Standard/Infrequent/Archive allocations for paid/trial accounts.

---

# 14. Analytics

Analytics ingestion must be deliberately cheap.

Beacon intake is exactly ONE endpoint owned by the analytics service and routed via the gateway: `POST /api/v1/beacon`. The gateway does rate-limiting and forwarding only — no intake logic, no separate beacon path.

Do not create an unbounded event log.

Event fields:

```text
event_id
occurred_at
session_id or anonymous_id
route
event_type
metadata_json
source
user_id nullable
```

Retention is explicit.

Aggregations are materialized into compact rollup tables.

Raw analytics records are purged according to the documented retention policy.

Deletion requests must propagate to analytics data.

---

# 15. Public web and SEO

`web-bff` is responsible for server-composed public data required by the Nuxt application.

It also owns generated:

- sitemap;
- robots/ads.txt as applicable;
- cacheable public data;
- canonical URL helpers.

The Nuxt SPA must not call multiple internal services directly from arbitrary browser code.

Preferred:

```text
Browser -> edge-gateway -> web-bff
```

for public pages.

Authenticated mutation requests may route to the owning service through the gateway.

---

# 16. Docker and image standards

All services must build as multi-platform images:

```text
linux/arm64
linux/amd64
```

Production OKE uses ARM64.

GitHub Actions uses Docker Buildx.

Tagging convention:

```text
<registry>/<repo>/<service>:sha-<git-sha>
<registry>/<repo>/<service>:release-<version>
```

Never deploy `:latest` in production.

Each build publishes an immutable SHA tag.

Images should use minimal runtime bases and run as non-root where practical.

Container requirements:

- read-only root filesystem where possible;
- no privileged containers;
- drop Linux capabilities by default;
- explicit writable temp directory only when necessary;
- no embedded secrets;
- version metadata compiled into binaries.

---

# 17. GitHub Actions CI/CD

## 17.1 Workflow separation

```text
.github/workflows/
├── ci.yml
├── security.yml
├── terraform-plan.yml
├── terraform-apply.yml
├── build-publish.yml
├── deploy-prod.yml
└── release.yml
```

## 17.2 Pull request CI

Every pull request runs:

1. formatting;
2. Go tests;
3. race tests where appropriate;
4. static analysis;
5. frontend lint/typecheck/test;
6. migration validation;
7. Docker build smoke test;
8. Terraform `fmt`/`validate`;
9. Kubernetes manifest validation;
10. dependency vulnerability scan;
11. secret scan.

No production credentials are available to pull-request workflows from forks.

## 17.3 Terraform workflow

Plan workflow:

```text
PR
 -> fmt
 -> validate
 -> init
 -> plan
 -> upload plan artifact / comment summary
```

Apply workflow:

```text
merge to main
 -> protected environment approval if configured
 -> OIDC auth to OCI
 -> terraform apply approved plan
```

Never run uncontrolled `terraform apply -auto-approve` directly from arbitrary branches.

## 17.4 Build workflow

```text
checkout
 -> tests
 -> docker buildx
 -> linux/amd64 + linux/arm64
 -> vulnerability scan
 -> push to OCIR
 -> record image digest
```

The deployment references the immutable digest.

## 17.5 Deployment workflow

```text
image digest available
 -> OIDC authentication
 -> obtain OKE credentials (public endpoint + short-lived token via `oci ce cluster create-kubeconfig`; no tunnel needed)
 -> apply migrate-<service> Jobs SERIALLY, wait for completion (schema first)
 -> validate manifests
 -> apply Kubernetes manifests
 -> wait for rollout
 -> smoke tests
 -> record release metadata
```

Migrations ALWAYS run before the new application revision (expand/migrate/contract, §7.5). A deploy workflow that rolls out code before its migration Job completes is a failed deploy, even if pods go green.

Oracle documents GitHub Actions OIDC access to OKE specifically to avoid long-lived credentials.

The cluster API endpoint is PUBLIC (adopted, ADR-019): CI and operators connect directly with short-lived kubeconfigs. DB tunnels still ride the bastion host (`terraform output ssh_to_bastion`). Never reintroduce tunnel-based K8s access without an ADR.

---

# 18. Kubernetes deployment strategy

Use Kustomize or Helm. Do not mix templating systems without a concrete reason.

Canonical choice: **Kustomize** because the free/scale differences are primarily resource values, replica counts, hostnames, and environment-specific references.

```text
infra/kubernetes/base/
  namespace.yaml
  serviceaccounts/
  deployments/        # per-service Deployments (+ edge-gateway, web-bff)
  services/           # per-service ClusterIP Services
  configmaps/
  secrets/            # *.tmpl.yaml ONLY (REDACTED-BY-CI placeholders, values
                      # rendered by CI from Vault — never real values in git)
  jobs/               # migrate-<service> Jobs, transport selftest
  networkpolicies/
  ingress/            # Ingress objects incl. tls-test (staging issuer)
  keycloak/           # platform StatefulSet + Service
  valkey/             # platform StatefulSet + Service (no messaging workload:
                      # OCI Queue is managed, §8.1)

infra/kubernetes/overlays/prod/      # image digests, hostnames, free-capacity values
infra/kubernetes/overlays/scale/    # README only (future, unappliable)
```

Do not put secret values in Git. Reference Kubernetes Secrets generated/synced from OCI Vault.

---

# 19. Observability

The free profile CANNOT run kube-prometheus-stack, Grafana, Loki, or Tempo: together they need 2+ GB RAM the cluster does not have. Canonical free observability is OCI-native plus stdout:

- Logs: structured JSON to stdout on every service; collected by the OKE log integration into an OCI Log Group (created by the `observability` Terraform module, 30-day retention). No in-cluster log aggregator.
- Metrics: every service exposes Prometheus-format `/metrics`; collection is OCI Monitoring custom metrics pushed by a single tiny exporter OR scraped only during load tests by an ephemeral (non-permanent) Prometheus. No permanent Prometheus on free.
- Alarms (OCI Monitoring, in `observability` module): outbox backlog age, 5xx rate, LB 10 Mbps saturation, DB CPU > 80%, node memory pressure, certificate expiry < 21 days, monthly-spend/budget alert at $0 threshold (any paid usage pages).
- Tracing: trace IDs propagated and logged; no collector/agent on free. Full OTel collection is a `scale`-profile upgrade.

Required signals:

### Metrics

- HTTP request count;
- latency;
- error rate;
- active requests;
- database latency;
- database pool utilization;
- queue depth/oldest message age;
- outbox backlog;
- consumer retries;
- media upload failures;
- authentication failures;
- cache hit rate;
- pod restarts;
- node memory pressure.

### Logs

Structured JSON logs containing:

```text
timestamp
level
service
request_id
trace_id
user_id nullable
operation
error
```

Never log:

- access tokens;
- refresh tokens;
- passwords;
- database credentials;
- session cookies;
- full sensitive request bodies.

### Tracing

Use OpenTelemetry-compatible tracing IDs.

`trace_id` is propagated internally, but incoming client-provided tracing identifiers must be validated and bounded.

---

# 20. Security baseline

## 20.1 Network

Use private subnets for workers and databases (module-managed).

Internet-facing, exactly: the OCI Load Balancer (workload traffic) + the OKE API endpoint (control plane, RBAC-guarded, short-lived kubeconfigs) + SSH to the bastion host (operator CIDR only). Nothing else gets a public IP.

Use NSGs (module-managed, supplemented only where a workload needs narrower rules).

Restrict egress where practical.

## 20.2 Kubernetes

- Pod Security Admission at the strongest feasible level.
- Non-root containers.
- Read-only filesystems where possible.
- Minimal Linux capabilities.
- NetworkPolicies.
- Separate service accounts.
- No default service-account token mounting unless needed.
- Resource requests and limits on every production workload.

## 20.3 IAM

Use least privilege for:

- Terraform CI;
- deploy CI;
- media service;
- any OCI API-calling workload;
- operator access.

Separate planning from applying infrastructure where practical.

## 20.4 TLS

TLS 1.2+ at minimum, with TLS 1.3 preferred.

Two TLS hops, both validated: Cloudflare edge (Cloudflare-managed edge cert) → origin, where TLS terminates at ingress-nginx with cert-manager ACME certificates (DNS-01 via Cloudflare, §11.4). The OCI Load Balancer is TCP passthrough and never terminates TLS. Cloudflare SSL mode is Full (strict) — never Flexible (which would leave edge-to-origin unencrypted).

Sensitive backend connections use TLS/mTLS where the service supports it.

## 20.5 Post-quantum note

Use contemporary maintained libraries and maintain crypto agility.

No custom cryptography.

No custom key exchange.

No claim of PQ-complete security.

Reassess PQ-capable TLS and signature options when the chosen OIDC/database/client stack provides production-ready support.

---

# 21. Testing architecture

Every service includes:

```text
unit tests
integration tests
contract tests
migration tests
security tests
```

The repository includes NO shared test helpers. Each service owns its test helpers under its own module (`services/<svc>/internal/testhelper/` or `*_test.go` files): fake OIDC issuer, disposable-schema helpers, fixture builders. Duplication across services is accepted and expected (§0.1-17); what must stay identical is BEHAVIOR, verified by each service's conformance checklist in `docs/specs/`.

## 21.1 Unit testing

Focus on domain logic and failure cases.

## 21.2 Integration testing

Run each service against disposable test dependencies.

For Oracle-specific SQL, CI needs either an approved Oracle-compatible environment or a dedicated integration environment. Do not claim PostgreSQL integration tests validate Oracle SQL semantics.

## 21.3 Contract testing

HTTP API schemas and event envelopes are versioned.

Breaking changes require explicit version changes.

## 21.4 End-to-end testing

Test:

- login;
- logout;
- session expiration;
- portfolio CRUD;
- publishing;
- media upload;
- public rendering;
- analytics ingestion;
- deletion/privacy flows;
- rate limiting;
- cache invalidation.

---

# 22. Environment variables

Configuration is injected through environment variables or mounted config.

Example:

```text
APP_ENV                    # local | free | scale
LOG_LEVEL
HTTP_ADDR
DB_WALLET_ENABLED          # false locally, true in production
TNS_ADMIN                  # /wallet in production
DATABASE_USER
DATABASE_PASSWORD
DATABASE_CONNECT_STRING    # TNS alias (_low on free); plain DSN only when DB_WALLET_ENABLED=false
DB_WALLET_PASSWORD         # if the wallet file itself is password-protected; separate secret
OIDC_ISSUER_URL
OIDC_CLIENT_ID
OIDC_CLIENT_SECRET
OIDC_AUDIENCE
SESSION_SECRET
OBJECT_STORAGE_NAMESPACE
OBJECT_STORAGE_BUCKET
OCI_CONFIG_FILE            # /.oci/config in pods (queue-client key mount, §4.2-3)
OCI_QUEUE_PREFIX           # walfa (services resolve <prefix>-<category>-events by display name at startup)
VALKEY_ADDR
VALKEY_PASSWORD
```

Do not put secret defaults into the application.

Fail fast when required production configuration is absent.

---

# 23. Migration and rollout model

The migration is decomposed into buildable phases. The BINDING step-by-step execution order — with exact commands, files, and per-phase verification — is `WALFA_PHASES.md` (Phases 0–25 (plus 25b)). If this section and that file ever disagree, the file governs and this section is patched to match.

Promotion from one phase to the next requires passing its validation gate.

## Old v4.0 summaries → binding phases

The original summaries below used a different numbering and built services before Docker/CI. They are SUPERSEDED by the mapping table; do not execute them literally.

| Original summary intent | Binding phase now | Gate (intent unchanged) |
|---|---|---|
| 0 — Repository + decision freeze | Phase 0, plus `docs/specs/` in Phase 2, ADR-017/018 | builds; no placeholders; no hosted-IdP refs |
| 1 — OCI account/operator bootstrap | Phase 3 (adds Cloudflare zone + token, ADR-012/017) | `region-subscription`, `limits`, bucket, `dig NS` |
| 2 — Terraform foundation (was one mega-phase) | SPLIT: Phase 4 (adopt root + remote state + CIDR fix), Phase 5 (add DB/Vault/Queue/DNS/alarms), Phase 6 (CNI switch + verify) | `fmt`/`validate`/`plan` per phase; re-plan empty; adopted infra untouched |

| 3 — OKE platform baseline | Phase 8 (adds single-LB tripwire, cert-manager DNS-01 staging, `tls-test` canary) | cluster healthy; internal reachability; staging TLS terminates |
| 4 — Vault + secret delivery | Phase 9 (binding secret table §10; CI-rendered Secrets, no External Secrets) | nothing in logs; least-privilege Secrets; rotation drilled |
| 5 — Database init | Phase 10 (wallet + `go-ora`, migrate-Job pattern, §7.4a budget) | migrations pass; per-schema isolation (ORA-00942 proven) |
| 6 — Identity provider | Phase 11 (realm-as-code, MFA, recovery; closes ADR-010) | code flow works; bad tokens rejected; rotation works |
| 7 — Event transport | Phase 13 (Queue access + SDK conformance + 4 gates; queues built in Phase 5) | round-trip, redelivery, duplicate, DLQ gates |
| 8–12 — services identity→analytics | Phases 14–18 (self-contained modules, spec-implemented per §0.1-17/ADR-018) | per-service gates in phases file |

| 13 — edge-gateway | Phase 19 (built AFTER the services it protects) | spoof headers blocked; 401/429/413 proven |
| 14 — web-bff | Phase 20 (adds precise invalidation, stale-serving, warm hook) | survives downstream restart; invalidation correct |
| 15 — Nuxt application | Phase 21 (gateway-only, no localStorage tokens, E2E) | browser E2E suite passes |
| 16 — Docker and OCIR | Phase 22 (Dockerfiles written in 14–18, built/pushed here) | ARM64 runs on OKE; digests pinned; no CRITICAL |
| 17 — GitHub Actions | Phase 7 (OIDC skeleton) + Phase 23 (full 7 workflows) | no long-lived OCI secret (OCIR token excepted) |
| 18 — staging-like validation | Phase 24 (smoke, k6 ≤8 Mbps, chaos set incl. node-drain, `VALIDATION.md`) | stable at load; runbooks executable |
| 19 — Migration (old conditional) | DELETED — greenfield build, no prior system, nothing to migrate or cut over | n/a |
| 20 — Hardening | Phase 25, now final (includes 25b handoff + `v1.0.0-free` tag) | DR rehearsed with numbers; $0 proven; §31 signed |
| 21 — Decommission legacy (old conditional) | DELETED — same reason | n/a |

Binding rules that moved with the renumbering:

- Greenfield fact: no legacy system exists and none is assumed. Any task, script, ADR, or directory referencing legacy data, migration scope, cutover, or decommissioning is an error — do not create it, do not "preserve the option".
- Dockerfiles are written alongside each service (Phases 14–18) but built, scanned, and pushed centrally in Phase 22. CI exists from Phase 0/7 and is completed in Phase 23; nothing deploys before Phase 24.

---

# 24. Migration verification framework

Every promotion has automated gates.

| Area | Example test | Acceptance |
|---|---|---|
| Terraform | `terraform validate` | pass |
| OCI budget | resource/quota query | within free profile |
| OKE | node status | Ready |
| Database | connection + migration status | pass |
| Identity | OIDC authorization-code flow | pass |
| Queue | publish/consume | pass |
| Outbox | backlog test | drains |
| Secrets | secret sync | current |
| Ingress | HTTPS smoke test | 2xx where expected |
| Security | secret/dep/container scan | policy threshold |
| Event replay | outbox drain + consumer redelivery after outage | zero loss, backlog drains |
| Media | sample download | hash match |
| SEO | sitemap/canonical/OG | valid |

---

# 25. Operational runbooks

## Runbook A — OKE rollout failure

```bash
kubectl rollout status deployment/<name> -n apps
kubectl describe deployment/<name> -n apps
kubectl get pods -n apps -o wide
kubectl logs deployment/<name> -n apps --tail=200
```

Actions:

1. identify failed readiness/liveness;
2. inspect image digest;
3. inspect secret/config availability;
4. rollback if application regression;
5. record incident.

## Runbook B — Outbox backlog

```sql
SELECT id, event_id, event_type, attempt_count, last_error
FROM event_outbox
WHERE published_at IS NULL
ORDER BY id DESC
FETCH FIRST 50 ROWS ONLY;
```

Check:

- transport availability;
- IAM/access;
- database locks;
- consumer backlog;
- poison events.

## Runbook C — Database migration failure

No third-party CLI is used (no Oracle dialect exists). Diagnose and fix through the service binary itself:

```bash
kubectl -n apps run migrate-debug --rm -i --restart=Never --image=<ocir>/<service>@<digest> \
  --env-from=secret/<service>-db -- ./app migrate status
# inspect which version failed and why, then EITHER fix-forward:
kubectl -n apps apply -f infra/kubernetes/base/jobs/migrate-<service>.yaml -n apps   # after merging the forward-fix migration
kubectl -n apps wait --for=condition=complete job/migrate-<service> -n apps --timeout=300s
```

Rules: down-migrations NEVER run in production (the binary refuses non-local `down` — `APP_ENV` guard). A failed `up` file may leave partial objects (Oracle DDL auto-commits): the forward-fix migration must be written against the ACTUAL partial state, verified first on disposable `oracle-free`. Checksum mismatches (`schema_version` vs file) mean someone edited an applied migration — revert the edit, ship a new file.

## Runbook D — OIDC outage

Expected behavior:

- existing valid sessions continue until their expiration policy;
- new login attempts fail closed;
- application does not bypass authentication;
- operator can reach Keycloak through private management access.

## Runbook E — Object Storage orphan cleanup

1. identify candidates older than grace period;
2. verify domain references;
3. mark cleanup intent;
4. delete object;
5. delete metadata only after successful object deletion;
6. emit audit event.

---

# 26. Disaster recovery

The free profile does not promise zero-downtime disaster recovery.

Recovery priorities:

1. infrastructure recreation from Terraform;
2. database restore/recovery;
3. object storage restoration;
4. Keycloak configuration restore;
5. Kubernetes deployment;
6. event replay/reconciliation;
7. DNS/ingress restoration.

The repository must contain:

```text
docs/runbooks/disaster-recovery.md
scripts/restore-db.sh            # thin wrapper around OCI ADB restore APIs
scripts/restore-object-storage.sh # thin wrapper around versioned-bucket restore
scripts/reconcile-events.sh      # outbox/Queue replay + reconciliation
```

These scripts wrap OCI-native restore (Autonomous Database automatic backups, versioned Object Storage buckets, realm JSON re-import) — they are NOT custom dump/restore tools. `expdp`/manual SQL dumps are forbidden as the restore story.

Run a restore rehearsal before declaring the system production-ready.

---

# 27. Cost-control policy

The project has a strict zero-cost target for the canonical free profile.

Terraform should create resource guards/quotas where OCI supports them.

At every deployment:

```text
verify home region
verify Always Free resource class
verify current quotas
verify block storage total
verify load balancer size
verify database free tier
verify object-storage budget
verify no paid-only feature enabled
```

If a requested feature is not available without cost in the free profile, the implementation LLM must stop and present the trade-off instead of silently provisioning a paid resource.

---

# 28. Scale profile

The `scale` profile exists only for future growth. The free profile already consumes the full PAYG-max A1 envelope (4 OCPU / 24 GB across 2 worker nodes), so any further A1 compute beyond the current 2 nodes requires paid capacity. State upgrades that are already in the free build (2 replicas for stateless services, 2 worker nodes, Valkey persistence) are not scale-profile items.

Potential upgrades (all require paid capacity or architectural changes beyond free):

- paid A1 compute beyond the 4 OCPU / 24 GB PAYG-max envelope;
- AMD E3/E4 compute or additional ADs;
- higher load balancer bandwidth;
- larger database;
- managed queue or higher-capacity queue configuration;
- replicated Valkey (sentinel or cluster);
- externalized Keycloak database;
- multi-AD/region strategy;
- advanced observability.

Do not implement these in the free build merely because they appear in this section.

---

# 29. Architecture decisions to preserve

### ADR-000 — Initial decision scaffold

Reason: pinned versions, toolchain, and repo layout recorded at project start so every later phase has a fixed baseline.

### ADR-001 — Terraform is infrastructure source of truth

Reason: reproducibility, reviewability, and drift control.

### ADR-002 — OCI CLI is operator tooling

Reason: interactive authentication and troubleshooting are different responsibilities from declarative infrastructure.

### ADR-003 — Self-hosted OIDC

Reason: no SaaS identity dependency and full operational control.

Canonical provider: Keycloak.

### ADR-004 — Local WALFA identity model

Reason: external identity subject and application user record are separate concerns.

### ADR-005 — Transactional outbox

Reason: prevents domain writes from succeeding while event publication silently fails.

### ADR-006 — ARM64-first production images

Reason: Always Free OKE capacity is based on Ampere A1.

### ADR-007 — Free profile is not HA

Reason: free-tier resource limits do not justify an HA claim.

### ADR-008 — Message transport is abstracted

Reason: the event contract is small and frozen, so per-service implementation from spec is cheap and independently deployable — but the TRANSPORT itself is one managed service, not a per-service choice. OCI Queue is canonical because the operator-confirmed free tier covers the workload with 100x headroom, guarded by a spend alarm. NATS or any self-hosted bus would trade a solved problem (managed queues + DLQ + IAM) for cluster memory, disk, and operations the free profile does not have.

### ADR-009 — OCI Queue is the canonical message transport

Reason: operator-confirmed free tier covers the workload with 100× headroom, guarded by a spend alarm; no self-hosted bus on free.

### ADR-010 — Media uploads via pre-authenticated requests (Option A)

Reason: direct-to-bucket PARs keep bytes off the cluster while the media service retains authorization control.

### ADR-012 — Cloudflare zone and API token are human-created

Reason: Terraform manages DNS records only via a least-privilege token; the zone/account itself is a one-time human action.

### ADR-013 — OKE Kubernetes version selection

Reason: adopted v1.36.1 (newest OKE-supported at apply time); re-verify `oci ce cluster-options` before any upgrade.

### ADR-014 — GitHub OIDC dynamic group rule

Reason: replaced instance-matching rule with repo-claim rule so GitHub Actions workflows authenticate via OIDC, not compute identity.

### ADR-015 — OCI LB annotation keys and platform add-on versions

Reason: ingress-nginx OCI LB annotation keys, cert-manager DNS-01 configuration, and metrics-server version recorded at scaffold to prevent silent drift.

### ADR-016 — Two validated TLS hops (Cloudflare edge → cert-manager origin)

Reason: Cloudflare SSL mode pinned to Full (strict); origin certificates issued by cert-manager via ACME DNS-01 against Cloudflare, never Flexible.

### ADR-017 — Cloudflare is the canonical DNS provider

Reason: the project already standardizes on Cloudflare for DNS. This removes all OCI DNS zones from scope, gives DDoS-absorbing proxied records in front of the single free LB, and provides the API surface cert-manager needs for ACME DNS-01 (which works through proxying, unlike HTTP-01's reachability assumptions). Terraform manages records via the least-privilege Cloudflare provider token; the zone/account itself is human-created and never Terraform-managed. Consequences: one extra token to rotate (90 days, same rhythm as the OCIR token), Cloudflare SSL mode pinned to Full (strict), optional origin-range lockdown recorded as periodic maintenance.

### ADR-018 — No shared service libraries

Reason: shared packages become coupling magnets — one change ripples into seven deployments, versioning gets negotiated instead of specified, and a "small shared helper" grows into a framework. WALFA's services share NOTHING at the code level. The contract surface is small and frozen (event envelope, outbox behavior, HTTP conventions, key/subject layouts), so per-service implementation from spec is cheap and independently deployable. Consequences: accepted duplication of small stable code; every spec ships a conformance checklist; envelope changes are explicit versioned events (ADR + coordinated PRs); CI rejects cross-service imports.

### ADR-019 — Adopt applied infra provisioning as canonical (reality over greenfield purity)

Reason: `infra-new/` was already applied (OKE + VCN + bastion host + OCIR + bucket + IP + tags + logs + state), so the plan's greenfield Terraform layout (hand-rolled network, `modules/` split, `free` env, private API, flannel, Bastion-service, `portfolio_governance` tags) would have fought reality on every apply — duplicate resources, tag ENUM violations, unenforced NetworkPolicies. The plan now adopts: module-managed network, one bastion host, PUBLIC API endpoint (guarded), VCN-native CNI (switched pre-workload while recreation is free), `walfa` tag namespace, `prod` environment name, `walfa/frontend` repo name, `ObjectRead` media bucket, reserved-IP reuse. What was broken in the applied state gets fixed, not excused: dynamic-group rule replaced (Phase 7), bastion CIDRs tightened (Phase 4), CNI switched (Phase 6). Consequences: flat single-root Terraform; `infra-new/` relocated to `infra/terraform/` with state migrated to the S3 backend; no parallel network/identity/tag systems ever.

---

# 30. LLM implementation instructions

An LLM given this document must behave as an implementation engineer.

## 30.1 It must

- inspect the repository before generating duplicate files;
- follow the directory layout;
- implement in phase order;
- keep code compiling at every phase;
- add tests with implementation;
- produce migrations with schema changes;
- update Terraform when infrastructure changes;
- update Kubernetes overlays when deployment requirements change;
- update GitHub Actions when CI/CD requirements change;
- use placeholders for secrets;
- document assumptions in ADRs;
- preserve the free resource budget;
- stop and surface a cost violation instead of creating a paid resource silently.

## 30.1a Go service standards (binding — prevents 7 divergent codebases)

- Go toolchain pinned to the exact version in `docs/versions.md` (`1.27.0` baseline) across `go.work` and `ci.yml` (dependabot updates all three — table, workspace, CI — in the same PR).
- SEPARATE Go modules, one per service: `github.com/<org>/walfa/services/<name>`, all listed in the root `go.work` (workspace = shared toolchain only, never shared code). No `packages/` tree exists. A service importing ANY other `walfa/services/<other>` path fails CI (enforced by the `no-cross-import` job).
- HTTP: standard library `net/http` + `chi` router only. No gin/echo/fiber.
- Logging: `log/slog` JSON handler with the §19 field names. No other logger.
- Config: env vars only (§22), loaded once at startup into a typed struct, `log.Fatal` on missing required values in production.
- OIDC/JWT: `github.com/coreos/go-oidc` + `github.com/golang-jwt/jwt` (or current maintained equivalents recorded in ADR); algorithm allow-list `RS256, ES256` written EXPLICITLY in each service that validates tokens (values from `docs/specs/http-conventions.md` — same values, local code, never imported).
- Oracle: `go-ora` (§7.4b). Migrations: each service's OWN minimal migrator (`internal/migrate/`, spec `docs/specs/migrations.md`) embedded in the binary with `serve`/`migrate` subcommands (§7.4c). No goose/golang-migrate (no Oracle dialect exists).
- Every service binary exposes `GET /health/live`, `GET /health/ready`, `GET /metrics` on the main port; probe timings are set in Kustomize base, not in code.
- Behaviors that LOOK shared (event envelope, outbox dispatch, HTTP error shape, pagination, request-ID middleware, Valkey key layout, OCI Queue naming/visibility/DLQ conventions, fake OIDC issuer) are implemented INDEPENDENTLY per service from the frozen specs in `docs/specs/`. Each service ships the spec's conformance checklist ticked off by its own tests. Copying is the mechanism; the spec is the contract; conformance tests are the proof.
- OCI Queue access: `oci-go-sdk` queue client only, standard file-auth from the `/.oci/` Secret mount (`OCI_CONFIG_FILE`). No other OCI SDK surface in services.
- Valkey access: `valkey-io/valkey-go` client only, thin per-service wrapper (~30 lines) over the documented key layout. No other Redis/Valkey client.

## 30.1b Version pinning policy (binding — vague versions are a defect)

Every version below is EXACT and was verified on 2026-09-14. Floating tags (`:latest`, `:slim` without digest, `:26`, `:8`, `controller-vX.Y.Z` unresolved) and EOL majors (Nuxt 3 — EOL 2026-07-31) are forbidden in committed code. `docs/versions.md` (created in Phase 0 from this table) is the working copy; scaffold fills in actual digests/dates and ADR-000 records them.

| Component | Pinned baseline (2026-09-14) | Track policy | Where pinned |
|---|---|---|---|
| Go toolchain | `1.27.0` | latest stable (Go supports N, N-1); bump quarterly | `go.work`, `ci.yml`, Dockerfiles |
| Keycloak | `26.7.3` | latest stable patch on 26.x; PATCH REVIEW MONTHLY (CVE history is active); never an EOL minor | compose, StatefulSet + digest |
| Valkey | `9.1.1` | latest stable minor (9.x supported to 2029; 9.1 moved Lua to a module — unused here) | compose, StatefulSet + digest |
| valkey-go | latest v1.x at scaffold | per-service `go.mod` + dependabot | each `services/*` |
| Nuxt | `4.5.2` | stable major 4 ONLY (v3 EOL — forbidden); v5 scheduled Q4 2026: adopt no earlier than 6 months after v5 GA + ADR | `package.json` + lockfile |
| Node | `24` LTS "Krypton" (Active LTS to 2028-04; 22 is maintenance-only) | Active LTS satisfying Nuxt `engines`; `.nvmrc` pinned | CI, web Dockerfile |
| Kubernetes | `v1.36.1` (applied; newest OKE-supported at apply time — re-verify `oci ce cluster-options` before any upgrade) | OKE lags upstream (upstream at 1.37 while OKE offered 1.36); ADR-013 | `oke` module |
| cert-manager | `v1.21.1` | latest stable (N+2 support window) | manifests URL |
| ingress-nginx | latest stable controller at scaffold | resolve version + manifest digest at scaffold, record in ADR-015 with the OCI LB annotation keys | manifests URL |
| metrics-server | latest stable at scaffold | record version in ADR-015 alongside ingress | manifests URL |
| OCI TF provider | `~> 9.0` (9.1.0 locked in adopted root) | latest major; lock file committed | `required_providers` + `.terraform.lock.hcl` |
| Cloudflare TF provider | `~> 5.0` (5.24.0 latest 2026-08-24) | latest major v5 ONLY (v4 resource names like `cloudflare_record` DO NOT EXIST in v5 — it is `cloudflare_dns_record`); lock file committed | `required_providers` + lock |
| TF registry modules | oke `5.5.1`, logging `0.4.0`, iam-dynamic-group `2.0.4` | exact `version =` (adopted applied versions; bumps via ADR) | `main.tf`, `logging.tf`, `services.tf` |
| Terraform CLI | `>= 1.16` (record exact at scaffold) | adopted `required_version`; CI uses same major | workflows, ADR-000 |
| oracle-free (dev DB) | `slim` track + digest at scaffold | dev-only; multi-arch (XE images are x86-only + deprecated — forbidden); re-pull quarterly | compose |
| go-ora v2, chi v5, go-oidc, oci-go-sdk | latest at scaffold | per-service `go.mod` + dependabot weekly | each `services/*` |
| Task runner | v3 latest stable at scaffold | exact CLI recorded in ADR-000; CI installs the pinned release (never `latest`); `make` must not exist in the repo | `Taskfile.yml`, workflows |
| golangci-lint, trivy, Playwright, k6, GH Actions | latest stable at scaffold | pinned SHAs/tags in workflows; dependabot | `.github/` |

Update engine: `.github/dependabot.yml` (gomod, npm, docker, terraform, github-actions — weekly) opens bump PRs; Phase 25 merges them and updates the table FIRST. Emergency: Keycloak/Go security releases are applied within 7 days, not batched into the quarter.

## 30.2 It must not

- reintroduce or introduce a hosted identity provider;
- build a custom password system;
- create a shared service library, shared Go package, or import code from another service (§0.1-17);
- replace Terraform with Pulumi/CDK/manual shell infrastructure;
- use VM/SSH deployment as the primary CI/CD path;
- put OCI private keys in GitHub repositories;
- put secrets in Git;
- deploy `latest` in production;
- use synchronous cross-service writes as a substitute for the outbox;
- claim the free profile is highly available;
- claim end-to-end PQ security;
- add unnecessary infrastructure because it is considered industry standard elsewhere.

## 30.3 First implementation task

Before writing application logic, execute `WALFA_PHASES.md` Phase 0 and commit (minimum):

```text
README.md
ARCHITECTURE.md
CONTRIBUTING.md
docs/adr/ADR-000 through ADR-010, ADR-017, ADR-018, ADR-019
docs/versions.md
infra/terraform/ (adopted flat root: backend migrated, lock committed)
infra/kubernetes/base/
infra/kubernetes/overlays/prod/
.github/workflows/ci.yml
Taskfile.yml
go.work
```

Then follow `WALFA_PHASES.md` in numeric order: Phase 3 (OCI account/quotas), then Phase 4 (Terraform network). No application logic before Phase 14.

---

# 31. Definition of done

The implementation is complete only when:

- the repository is reproducible from a clean checkout;
- Terraform can recreate OCI infrastructure;
- OKE runs the complete service set within the declared free budget;
- Keycloak performs authentication;
- no hosted identity dependency exists;
- database schemas are isolated;
- migrations are versioned and tested;
- events use the outbox pattern;
- consumers are idempotent;
- media is private and validated;
- GitHub Actions builds ARM64/AMD64 images;
- images are stored in OCIR;
- production deployment uses short-lived identity rather than long-lived credentials where supported;
- secrets are in OCI Vault;
- ingress is TLS protected;
- health checks and observability exist;
- rollback and restore procedures are documented and tested;
- the free profile does not silently consume paid resources;
- the project can be handed to another engineer or LLM without requiring undocumented context.

---

# 32. External references used for current OCI constraints

1. OCI Always Free resources and current compute/storage/load-balancer limits: https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier.htm
2. Always Free Autonomous AI Database restrictions: https://docs.oracle.com/en-us/iaas/autonomous-database-serverless/doc/always-free-autonomous-db.html
3. OKE Basic/Enhanced clusters and workload identity: https://docs.oracle.com/en-us/iaas/Content/ContEng/home.htm
4. Terraform provisioning of OKE: https://docs.oracle.com/en-us/iaas/developer-tutorials/tutorials/tf-oke/01-summary.htm
5. GitHub Actions OIDC access and private OKE reference architectures: https://docs.oracle.com/en-us/iaas/developer-tutorials/tutorials/github-actions-oke/01-summary.htm and https://docs.oracle.com/en-us/iaas/Content/ContEng/Tasks/contengprivate-cluster-bastion.htm
6. OKE Terraform registry module (pinned `oracle-terraform-modules/oke/oci` 5.5.1): https://registry.terraform.io/modules/oracle-terraform-modules/oke/oci

Always re-verify free-tier limits against source 1 before provisioning: the PAYG-max A1 envelope (4 OCPU / 24 GB, 2 nodes × 2 OCPU/12 GB) consumes the full free A1 allocation and leaves no remaining free compute for additional nodes. If documentation and tenancy quotas disagree, the LOWER value governs and the discrepancy is recorded in an ADR.

These references are for current platform verification. They do not override the architectural decisions in this document; they are the evidence for platform capabilities and limits.

---

# 33. Final implementation order

The binding order is `WALFA_PHASES.md` Phases 0–25 (plus 25b final handoff), summarized:

```text
0.  Repo scaffold + decision freeze (incl. ADR-000 through ADR-010, ADR-017, ADR-018, ADR-019)
1.  Local dev loop (compose: oracle-free, Valkey, Keycloak-dev — no Queue
    emulator exists; Queue is proven against the real tenancy in Phase 13/24,
    unit/integration tests use each service's own in-memory fake)
2.  Frozen specs (docs/specs/ — envelope, HTTP conventions, outbox,
    Valkey keys, Queue topology, conformance checklists). NO shared code.
3.  OCI account/operator bootstrap (region DECIDED ap-singapore-1,
    compartment reference, quotas, state bucket, Cloudflare zone + token)
4.  Adopt Terraform root + remote state + bastion CIDR fix (zero new infra)
5.  Terraform additions (ADB, Vault, Queue, DNS, alarms — adopted infra verified)
6.  OKE CNI switch flannel→vcn-native + verification (ADR-019)
7.  GitHub OIDC federation (FIX dynamic-group rule) + IAM + sanctioned tokens
8.  Kubernetes platform baseline (quotas, ingress, single LB,
    cert-manager DNS-01 staging)
9.  Vault values + CI-rendered secret delivery + rotation drill
10. Database init (users, schemas, wallet, migrate-Job pattern, budget)
11. Keycloak (realm-as-code, MFA, recovery) + close ADR-010
12. Valkey (auth, TTL namespaces, eviction proof, + persistence via AOF on PVC)
13. OCI Queue verification (access key, SDK conformance, 4 transport gates;
    queues built in Phase 5) + close ADR-009
14. Identity service      } each: migrations → self-contained code
15. Portfolio service     } (spec-implemented locally, no imports) →
16. Publishing service    } Dockerfile → manifests → migrate-Job → gate
17. Media service         }
18. Analytics service     } (owns POST /api/v1/beacon)
19. edge-gateway (trust boundary: strip → limit → validate → route)
20. web-bff (cache + invalidation + stale-serving + warm hook + SEO files)
21. Nuxt SPA (gateway-only, E2E suite)
22. Docker multi-arch + SBOM + scan + OCIR digest pinning
23. Full GitHub Actions CI/CD (serial migrations, rollback runbook)
24. Production validation on free capacity (smoke, k6, chaos incl. node-drain, wallet rehearsal, VALIDATION.md)
25. Hardening + DR rehearsal with numbers + $0 audit + §31 sign-off
25b. Final handoff (as-built docs, runbook index, `v1.0.0-free` tag)
```

No legacy migration or decommission phases exist: greenfield build, no prior system.

No phase should be skipped merely because later application code can be generated first. Infrastructure, identity, data ownership, deployment, and observability are intentionally established before the system becomes difficult to operate.

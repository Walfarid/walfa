# WALFA — Binding Build Phases (stupid-LLM-proof)

**Companion to:** `WALFA_BUILD_MASTER.md` (the *why* and the *rules*).
**This file is:** the *exact execution order* — what to do, in what order, with what commands, producing what files, verified how.
**Checklist translation:** `tasks/` holds one checkbox file per phase (`tasks/README.md` index, `tasks/phase-NN-name.md`). The files mirror this document task-by-task (`N.1`, `N.2`, … with `[ ]` items + `Verify` blocks). This file still governs on conflict.
**Authority rule:** if this file and the master plan disagree, **this file governs the work** and the master plan must be patched to match. Never silently follow the master plan against this file. Never silently follow this file against a non-negotiable rule in master §0.1 — stop and ask a human instead.

**Core design law (master §0.1-17, ADR-018): NO shared service code.** There is no `packages/` tree, no common library, no shared Go module. Each of the 7 services is a self-contained Go module. Compatibility comes from frozen SPEC documents (`docs/specs/`, written in Phase 2) + per-service conformance tests. Copying small frozen behaviors per service is the mechanism; the spec is the contract; conformance tests are the proof. A PR that adds a shared package or an import of another service fails review by definition.

---

## 0. How to execute these phases (read this first, LLM)

1. **Do phases strictly in numeric order.** A phase may start only when the previous phase's DONE WHEN checklist is fully true. No skipping, no "doing Phase 14 while Phase 6 is pending".
2. **One phase = one pull request.** Branch name `phase-N-short-name`. Merge only after VERIFY passes. Keep `main` green at all times.
3. **Workdir convention.** Repo root is `walfa/`. Every `command` block below assumes the stated `workdir`. Do not `cd` around it.
4. **Never commit secrets.** Before every commit, run `git status` and `git diff --cached --name-only`; if you see a password, token, wallet file (`.sso`, `.p12`, `cwallet.sso`, `ewallet.p12`), private key (`.pem`, `.key`), or `terraform.tfvars` with real values — STOP, remove, rotate if it ever left the machine.
5. **Cost tripwire (master §27).** Before creating ANY OCI resource, confirm it is Always Free class in the current tenancy. If Terraform plans a non-free shape, STOP, do not apply, and surface the trade-off to the human.
6. **Single-LB tripwire.** At the end of every infrastructure phase, exactly ONE load balancer may exist in the compartment. A second LB = stop immediately and delete the duplicate (after confirming which one ingress uses).
7. **Commands you may not invent alternatives to.** Use the exact CLIs pinned per phase (`oci`, `terraform`, `kubectl`, `go`, `docker buildx`, `gh`). Migrations run through the service binaries (`./app migrate`), never through a third-party migrator — none supports Oracle. Do not substitute Pulumi, CDK, Ansible, or shell-provisioned infrastructure.
8. **When stuck for >3 attempts on one step:** stop, record the blocker (command, full output, what you expected) in the PR description, and ask the human. Do not hack around a gate by weakening it.
9. **Record every real decision as an ADR** in `docs/adr/ADR-NNN-title.md` (context, options, decision, consequences). Guessing silently is forbidden.
10. **No cross-service imports, ever.** No Go file under `services/<a>/` may import `walfa/services/<b>`. No shared first-party packages exist. Third-party libraries (chi, go-ora, valkey-go, oci-go-sdk, go-oidc) are fine — they are external dependencies, not WALFA code.

**Environment variables the human must export once (never commit):**

```bash
export OCI_TENANCY_OCID="ocid1.tenancy.oc1..aaaa..."   # from OCI console
export OCI_REGION="ap-singapore-1"                     # home region, DECIDED (ADR-012) — never changed
export WALFA_DOMAIN="example.com"                      # domain the human owns; Cloudflare zone in Phase 3
export GITHUB_ORG_OR_USER="my-org-or-user"
```

---

## Phase 0 — Repository scaffold + decision freeze

**GOAL:** an empty-but-complete monorepo where every later phase has a place to put things.
**START ONLY WHEN:** nothing. This is first.
**BUILD** (workdir `walfa/`, create if missing):

1. Create the full directory tree from master §3 verbatim (every directory, even if empty — add `.gitkeep` where empty). Plus `docs/adr/`, `docs/specs/`, `docs/releases/`, `docs/validation/`, `docs/keycloak/`, `docs/runbooks/`.
2. Write `go.work` pinning the versions-table Go version (`go 1.27.0` — check `go version` at scaffold; if a newer stable exists, update the TABLE first, then pin exactly; record actuals in ADR-000). `go.work` is toolchain-only: each service becomes its own module later (`go.work use` lines added in Phases 14–19). It must NEVER `use` a shared WALFA library — none will exist.
3. Write root `Taskfile.yml` (go-task v3, CLI version pinned per versions table §30.1b and recorded in ADR-000) with at minimum these tasks (each must work or print a clear TODO-with-issue-link, never silently succeed while doing nothing): `fmt`, `lint`, `test`, `test-race`, `build` (loops over `services/*/`: `for m in services/*/; do (cd $m && go build ./...); done`), `docker-build`, `migrate-status`, `dev-up`, `dev-down`, `dev-logs`. Everything (docs, CI, humans) invokes `task <name>`; no `Makefile` may exist in the repo.
4. Write `.gitignore`: `*.tfvars`, `*.tfstate*`, `.terraform/`, `*.pem`, `*.key`, `*.sso`, `*.p12`, `cwallet.sso`, `ewallet.p12`, `tnsnames.ora`, `sqlnet.ora`, `.env`, `.env.*`, `node_modules/`, `dist/`, `.nuxt/`, `*.log`, `.DS_Store`.
5. Write `README.md` (what WALFA is, free-profile honesty: "not HA", self-contained-services law with ADR-018 link, links to master plan + this file), `ARCHITECTURE.md` (copy of master §1 diagram + bounded-context table), `CONTRIBUTING.md` (phase discipline, one-phase-per-PR, secret rules from §0 above, no-cross-import law), `docs/versions.md` (working copy of the master §30.1b versions table with scaffold actuals filled in: exact tags + image digests + provider versions).
6. Write ADRs: ADR-000 versions record (Go toolchain + every versions-table actual: tags, digests, provider versions); ADR-001..ADR-008 transcribed from master §29; ADR-009 transport = OCI Queue, canonical (operator-confirmed free tier; re-verified in Phase 5, spend alarm armed — closeout in Phase 13); ADR-010 media upload Option A/B (§13 decision, may stay "deferred to Phase 11" but the file must exist); ADR-017 Cloudflare DNS (details land in Phase 3); ADR-018 no shared service libraries (transcribe from master §29); ADR-019 adopt applied infra as canonical (transcribe from master §29). No legacy/migration ADR exists and none will: greenfield build, no prior system, no migration scope.
7. Create `.github/workflows/` with a placeholder `ci.yml` that installs the pinned task runner then runs `task fmt test` on `pull_request` (it will grow in Phase 23; it must be green NOW, even if minimal).
8. Branch protection (human clicks in GitHub if `gh` lacks permission; LLM verifies). Preferred method — JSON file, no fragile flags:
   ```bash
   cat > /tmp/branch-protection.json <<'EOF'
   {"required_status_checks": {"strict": true, "contexts": []},
    "enforce_admins": true,
    "required_pull_request_reviews": {"required_approving_review_count": 1},
    "restrictions": null}
   EOF
   gh api repos/$GITHUB_ORG_OR_USER/walfa/branches/main/protection -X PUT --input /tmp/branch-protection.json
   shred -u /tmp/branch-protection.json
   ```
   Fallback clicks: Settings → Branches → Add rule → `main` → Require PR (1 approval), Require status checks, no direct pushes.

**VERIFY:**

```bash
task fmt && task test && task build   # all must exit 0 (no services yet — loop no-ops cleanly)
git status --porcelain                 # must show only intended files
grep -rEi "auth0|clerk|cognito|firebase|supabase|kafka|rabbitmq|redis streams|temporal" --include="*.go" --include="*.md" --include="*.yml" --include="*.yaml" . | grep -vi "do not" || echo "CLEAN"
ls docs/adr/ | wc -l   # 000-010 + 017 + 018 + 019 = 14 files
```

Expected: all green; the grep prints CLEAN (no hosted-identity / banned-messaging references outside "do not" rules).
**DONE WHEN:** [ ] tree matches master §3 [ ] `go.work` pinned [ ] Taskfile tasks run [ ] 14 ADRs exist [ ] `main` branch protected [ ] no banned-provider references.
**DO NOT:** write any service logic, any Terraform, any K8s manifests, or any shared package. Scaffolding only.

---

## Phase 1 — Local dev loop (no cloud, no excuses later)

**GOAL:** any engineer/LLM can run the whole dependency set locally in one command.
**START ONLY WHEN:** Phase 0 done.
**BUILD** (workdir `walfa/`):

1. Write `scripts/dev-compose.yml` (docker compose, pinned minor versions, ALL ARM64+AMD64 images) with: `oracle` (`gvenzl/oracle-free:slim`, `ORACLE_PASSWORD=dev-only-not-secret`, PDB service `FREEPDB1`), `valkey` (`valkey/valkey:9.1.1`, password `dev-only`), `keycloak` (`quay.io/keycloak/keycloak:26.7.3` with `start-dev`, admin `admin/admin` — dev only, compose file states this loudly). All per versions table §30.1b; record image digests (`docker images --digests`) in ADR-000. No Queue container exists (OCI Queue has no local emulator — see step 4). (`oracle-xe` is x86_64-only and deprecated upstream — never use it.)
2. Wire `task dev-up` → `docker compose -f scripts/dev-compose.yml up -d`, `task dev-down` → `... down -v`, `task dev-logs` → `... logs -f`.
3. Write `scripts/dev-seed.sh`: waits for Oracle (`docker exec` health check loop, timeout 300s), prints connection summary (host/ports/users). Idempotent: safe to run twice.
4. Document in `CONTRIBUTING.md`: local ports table (Oracle 1521, Valkey 6379, Keycloak 8080), `DB_WALLET_ENABLED=false` locally, dev passwords are NOT secrets and must never be reused in production. Queue testing strategy (no emulator): unit/integration tests use each service's OWN in-memory fake of the Queue client; the real tenancy Queue is proven in Phase 13 (selftest) and Phase 24 (e2e + chaos).

**VERIFY:**

```bash
task dev-up && sleep 10
docker ps --format "{{.Names}} {{.Status}}" | grep -Ei "oracle|valkey|keycloak"   # 3 containers Up
scripts/dev-seed.sh && scripts/dev-seed.sh   # second run proves idempotence
task dev-down
```

**DONE WHEN:** [ ] `dev-up` → 3 healthy containers [ ] seed script idempotent [ ] ports documented [ ] Queue fake strategy documented [ ] nothing in this phase touches OCI.
**DO NOT:** use these dev passwords anywhere else; put real credentials in compose.

---

## Phase 2 — Frozen specs (documents, NOT code — there are no shared libraries)

**GOAL:** the single written contract every self-contained service implements independently. This phase produces ZERO Go code.
**START ONLY WHEN:** Phase 1 done.
**BUILD** (workdir `walfa/docs/specs/` — all files committed):

1. `event-envelope.v1.json` — JSON Schema (draft 2020-12): required `event_id` (uuid string), `occurred_at` (RFC3339), `aggregate_type`, `aggregate_id`, `entity_version` (integer ≥1), `event_type` (pattern `^[a-z]+\.[a-z-]+\.v1$`), `payload` (object). `additionalProperties: false`. Changing ANYTHING = `v2` + ADR + coordinated per-service PRs.
2. `http-conventions.md` — canonical error shape `{code,message,request_id}`; pagination (`page,page_size`, max 100, 422 on overflow); request-ID header `X-Request-Id` (generate-if-absent, propagate); mandatory endpoints `GET /health/live`, `GET /health/ready`, `GET /metrics`; JWT algorithm allow-list values `RS256, ES256` (each service hardcodes these SAME values locally — never imports them); security headers list (copied by edge-gateway).
3. `outbox.md` — the outbox contract: table DDL (master §8.2 verbatim), dispatcher algorithm (bounded batch → `SELECT ... FOR UPDATE SKIP LOCKED` → publish → mark-published → attempt++/exponential-backoff+jitter → alert threshold), idempotency rule (`consumer_name + event_id` key, handlers re-runnable), DLQ-forward rule (after N attempts, N=10 default). Each emitting service re-implements this locally.
4. `valkey-keys.md` — key namespaces + TTL discipline: `sess:<id>` (TTL = session idle timeout), `ratelimit:<scope>:<key>` (TTL = window), `bff:public:<route>` (TTL ≤300s). NO immortal keys. Auth mandatory. Each service writes its own ~30-line client to this layout.
5. `queue-topology.md` — one queue per category (`walfa-<category>-events`: identity, portfolio, publishing, media, analytics) + `walfa-dlq`; startup resolution by display name (OCIDs as fallback); batched PutMessages (mandatory batching); long-poll GetMessages + DeleteMessages-after-commit; visibility timeout 30s default; max-deliveries=10 → native DLQ routing; 64 KiB message-size discipline (payloads stay small domain events — oversized payload = design error, store a reference instead); per-service in-memory fake discipline for tests (fake implements the same three operations: put/get/delete, nothing more).
6. `conformance-checklist.md` — the tick-list EVERY service phase must satisfy with its OWN tests: envelope validates (good + 5 bad fixtures), outbox drains after consumer outage, duplicate delivery = zero state change, poison message → DLQ, error shape exact, pagination caps enforced, 401/429/413 behaviors (gateway), migration double-apply green.
7. `migrations.md` — the migration-file contract (master §7.5): `NNNN_name.up.sql` / `.down.sql` pairs, plain Oracle DDL/DML only, one statement per `;`-at-line-end, CI grep gate rejecting `BEGIN|DECLARE|CREATE TRIGGER|CREATE PROCEDURE|CREATE PACKAGE`, `schema_version` table + SHA256 checksum rule, `up`/`status` semantics (second `up` = no-op), down-files for local teardown ONLY.
8. `scripts/validate-envelope.py` (stdlib ONLY, no pip): loads `event-envelope.v1.json`, checks required fields/pattern on a `good` + `bad` fixture pair under `docs/specs/fixtures/`. Run in `ci.yml` placeholder.
9. Record ADR-009/ADR-010 status lines (still open, owners = Phase 13 / Phase 11).

**VERIFY:**

```bash
python3 scripts/validate-envelope.py   # GOOD passes, BAD fails, exit 0
python3 -c "import json; json.load(open('docs/specs/event-envelope.v1.json')); print('SCHEMA VALID JSON')"
grep -rn "package " docs/specs/ || echo "NO CODE IN SPECS"
find . -path ./node_modules -prune -o -name "*.go" -print | head -5  # expect NOTHING repo-wide
```

**DONE WHEN:** [ ] 7 spec docs + fixtures + validator committed [ ] validator green [ ] zero `.go` files exist anywhere [ ] ADR-009/010 ownership recorded.
**DO NOT:** write Go helpers, a shared module, a code generator, or "just one tiny shared package". Specs only.

---

## Phase 3 — OCI account + operator bootstrap (human-led, LLM-supervised)

**GOAL:** tenancy ready for Terraform; irreversible choices (region, compartment) made deliberately.
**START ONLY WHEN:** Phase 2 done. Human must be present (browser logins, domain DNS).
**BUILD:**

1. Install OCI CLI (`pip install oci-cli` or installer), then `oci session authenticate --region $OCI_REGION`. Verify: `oci iam region-subscription list` shows the home region.
2. **Home region is DECIDED: `ap-singapore-1`** (applied provisioning runs there; tenancy home region identical). Record in ADR-012 with the verification output. Never change after this point — the worker-image lookup OCID and all state are region-coupled.
3. Compartment: REFERENCE the existing WALFA compartment (already holds OKE, buckets, repos — do NOT create a second one); save its OCID into a LOCAL (gitignored) `scripts/local-env.sh` as `OCI_COMPARTMENT_OCID`. Also save the operator SSH PUBLIC key path (needed for bastion `ssh_public_key` on any re-apply).
4. Quota reality check (numbers override ALL documentation):
   ```bash
   oci limits value list --service-name compute --compartment-id $OCI_TENANCY_OCID | grep -i -A2 "ampere\|a1\|ocpu"
   oci limits value list --service-name database --compartment-id $OCI_TENANCY_OCID | grep -i -A2 "autonomous"
   ```
   Confirm: ≥4 A1 OCPUs + 24GB RAM available (2 nodes × 2 OCPU/12 GB); ≥1 Always Free Autonomous DB available. If lower → ADR + shrink budgets before continuing.
5. Create Terraform state bucket: `oci os bucket create --namespace $(oci os ns get --query data --raw-output) --name walfa-tfstate --compartment-id $OCI_COMPARTMENT_OCID --versioning true --object-events-enabled false`. Note: Terraform talks to OCI Object Storage via its **S3-compatible endpoint** (Phase 4 backend config) — install no extra tooling.
6. DNS (Cloudflare — canonical, ADR-017): human creates the Cloudflare account, adds `$WALFA_DOMAIN` as a zone, and changes the registrar's nameservers to the two Cloudflare-assigned nameservers. Verify: `dig NS $WALFA_DOMAIN` must return `*.ns.cloudflare.com`. Then create a least-privilege API token (Cloudflare dashboard → My Profile → API Tokens → "Edit zone DNS" template, scoped to ONLY this zone: permissions `Zone:DNS:Edit` + `Zone:Zone:Read`); save the token value into the password manager AND as LOCAL env `CLOUDFLARE_API_TOKEN` in `scripts/local-env.sh` (gitignored — `git check-ignore` it), plus `CLOUDFLARE_ZONE_ID` (from the zone's Overview page). Record everything in ADR-017. Terraform manages records from Phase 5; the zone/account itself is NEVER Terraform-managed.
7. Verify Vault + LB availability in region: `oci vault secret list --compartment-id $OCI_COMPARTMENT_OCID` (empty OK, API must respond); `oci lb load-balancer list --compartment-id $OCI_COMPARTMENT_OCID`.

**VERIFY:**

```bash
oci iam region-subscription list | grep -i "$OCI_REGION"
oci limits value list --service-name compute --compartment-id $OCI_TENANCY_OCID | grep -ci "ampere\|a1"  # >0
oci os bucket get --namespace $(oci os ns get --query data --raw-output) --name walfa-tfstate | grep -i versioning
dig +short NS $WALFA_DOMAIN | grep cloudflare
git check-ignore scripts/local-env.sh  # must print the path (ignored)
```

**DONE WHEN:** [ ] region recorded in ADR-012 [ ] compartment OCID + Cloudflare token in ignored `local-env.sh` [ ] quotas ≥ free-profile needs [ ] state bucket versioned [ ] `dig NS` shows Cloudflare.
**DO NOT:** create a second compartment/region/cluster "to try things". Adopted resources are referenced, never duplicated.

---

## Phase 4 — Adopt Terraform root + remote state (no new infrastructure)

**GOAL:** the applied `infra-new/` provisioning becomes `infra/terraform/`, state moves off the laptop, guardrails set. ZERO new OCI resources in this phase.
**START ONLY WHEN:** Phase 3 done.
**BUILD** (workdir repo root, then `walfa/infra/terraform/`):

1. Relocate: `git mv <old>/infra-new <repo>/walfa/infra/terraform/` (whole directory INCLUDING `terraform.tfstate` + `.terraform/` — state addresses are file-independent, so the move itself changes nothing). If relocation is impossible, mirror the tree exactly and say so in the PR.
2. S3-compatible backend: add `backend "s3"` block (bucket `walfa-tfstate`, key `prod/terraform.tfstate`, region `ap-singapore-1` endpoint override, all four `skip_*`/`use_path_style` flags). Credentials from env (`AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` = OCI customer secret keys — the ONE manual key pair, created once, stored in password manager, never in repo).
3. Migrate state: `terraform init -migrate-state` → `terraform plan -detailed-exitcode` MUST exit 0 (move + backend changed nothing). Only then shred local `terraform.tfstate*` copies (`shred -u`; they contain secrets).
4. Guardrails in `environments/prod/prod.tfvars`: `bastion_allowed_cidrs = ["<operator-ip>/32"]` (NEVER `0.0.0.0/0` in prod), operator `ssh_public_key`, `environment = "prod"`. Real `prod.tfvars` gitignored; commit `prod.tfvars.example` only.
5. `terraform fmt -recursive`, `terraform validate`. Commit `.terraform.lock.hcl` (OCI `~> 9.0` locked 9.1.0, Cloudflare `~> 5.0` per versions table). Tag namespace `walfa` is REFERENCED (import if needed — `terraform import oci_identity_tag_namespace.walfa <ocid>`), never recreated.
6. No change to create_bastion (module bastion host is retained, not debt; ADR-020 records retention + CIDR tightening).

**VERIFY:**

```bash
terraform fmt -check -recursive && terraform validate
terraform plan -detailed-exitcode   # expect 0: adoption changed nothing
git status --porcelain | grep -i "tfstate" || echo "NO STATE IN GIT"
oci bastion bastion list --compartment-id $OCI_COMPARTMENT_OCID 2>/dev/null; echo "(bastion SERVICE unused by design — host VM covers access)"
terraform output bastion_public_ip && ssh -o BatchMode=yes -o ConnectTimeout=10 opc@$(terraform output -raw bastion_public_ip) true && echo "BASTION SSH OK"
```

**DONE WHEN:** [ ] tree relocated [ ] remote state verified + local copies shredded [ ] plan empty [ ] no state in git [ ] bastion SSH works from operator CIDR [ ] LB count unchanged (1 reserved IP, 0 LBs — LB arrives Phase 8).
**DO NOT:** create/modify OCI resources here. Adoption only; changes are Phase 5+ with human-reviewed plans.

---

## Phase 5 — Terraform additions (DB, Vault, Queue, DNS, alarms — network/compute already exist)

**GOAL:** add ONLY what is missing to the adopted root. Network, bastion host, cluster, repos, bucket, IP, tags, flow logs already exist — verify, don't duplicate.
**START ONLY WHEN:** Phase 4 applied (remote state, empty plan).
**BUILD** (workdir `walfa/infra/terraform/` — flat root, new files alongside adopted ones):

1. `database.tf`: ONE Always Free Autonomous AI Database (fixed 1 CPU / 20 GB — NO tunable CPU/storage variables, master §5.4), private endpoint in the module-managed DB-capable subnet, `outputs` = connection strings + OCID only (no passwords; passwords are created in Phase 10 via admin SQL, stored straight to Vault).
2. `vault.tf`: Vault + encryption key + EMPTY secret shells (names only, master §10 table): 5× `db-<svc>-password`, `wallet-password`, `keycloak-admin`, `oidc-client-secret`, `session-secret`, `valkey-password` (values injected in Phase 9, never via tfvars). No OCIR/Cloudflare shells here — those tokens are GitHub-secrets-only by design.
3. Adopted bucket check (NO new bucket): `walfa-media` exists (`ObjectRead`, versioning ON — adopted, master §13). ADD lifecycle rules only: delete `tmp/uploads/*` after 7 days + purge noncurrent versions after 30 days. Adopted `walfa-tfstate` holds state (do not touch). Per-bucket budget in a `objectstorage.README`: media ≤ 15 GB, state ≤ 1 GB (fits §2.1 combined allowance).
4. Adopted repos check (NO new repos): 8 `walfa/*` repos exist (`edge-gateway web-bff identity portfolio publishing media analytics frontend` — note `frontend`). Output the `<region>.ocir.io/<namespace>/` prefix for Phase 22.
5. `dns.tf` (Cloudflare provider v5 `~> 5.0`, lock file committed — NO OCI DNS zones, master §0.1-16): `cloudflare_dns_record` resources (`app`, `auth`, `tls-test` → the ADOPTED reserved IP `walfa-ingress-ip`, `proxied = true`) with `zone_id = var.cloudflare_zone_id` (from env `CLOUDFLARE_ZONE_ID`), `var.cloudflare_api_token` (`sensitive = true`, env `CLOUDFLARE_API_TOKEN` only). v5 argument names verified against the pinned provider's registry docs NOW, recorded in file header. (No placeholder dance: the reserved IP already exists — read it via `terraform output public_ip_ingress`.)
6. `queue.tf` (REQUIRED, master §8.1): five category queues + `walfa-dlq` (visibility 30s, max-delivery 10 → DLQ, retention). Confirm exact `oci_queue_queue` attribute names against provider 9.1.0 registry docs NOW and record them in the file header — never guess attribute names. Outputs: queue OCIDs + display names. Re-verify the free tier in THIS phase: record the current pricing-page/tenancy result in ADR-009 (operator baseline: first ~1M API calls/month free) and confirm the $0 Queue spend alarm from step 7 covers any drift.
7. `observability.tf` (extends adopted `logging.tf`, does not replace it): Monitoring alarms: 5xx-rate, outbox-age (placeholder metric, wired Phase 13), DB-CPU>80%, node-memory-pressure, cert-expiry (wired Phase 8), budget alert $0 (ANY spend notifies — explicitly includes Queue spend AND flow-log ingestion). Alarms notify an email topic the human confirms NOW.
8. NO load-balancer file, NO bastion-service file, NO network file, NO second VCN (master §5.4: creating any of these is a defect).

**VERIFY:** `fmt -check`, `validate`, `plan` reviewed line-by-line by human (check: DB is Always Free class; only the 5 intended new-file resource sets; NO secret values in plan output; zero changes to adopted OKE/network/repos/bucket/IP), apply, re-plan empty. LB count still ZERO (LB arrives Phase 8).
**DONE WHEN:** [ ] ADB provisioned + private endpoint [ ] Vault + 10 empty secret shells [ ] lifecycles added to adopted buckets [ ] adopted repos/IP verified [ ] 3 Cloudflare records live on reserved IP [ ] 5 queues + DLQ provisioned [ ] Queue free tier re-verified + recorded in ADR-009 [ ] alarms (incl. Queue spend + flow logs) + budget alert confirmed by test email.
**DO NOT:** put any secret VALUE in `*.tfvars` (use `sensitive = true` vars fed from env/prompt only), create tunable DB sizing vars, recreate adopted resources, or create the LB.

---

## Phase 6 — OKE CNI switch + verification (cluster already exists)

**GOAL:** VCN-native CNI live on the adopted cluster; everything else verified untouched.
**START ONLY WHEN:** Phase 5 applied.
**BUILD** (workdir `walfa/infra/terraform/` — `main.tf` only):

1. Switch `cni_type` from `"flannel"` to `"vcn-native"` (master §11.1, ADR-019 — NOTHING enforces NetworkPolicy under flannel, and §20.2 + the Phase 19 bypass gate require enforcement). Expect cluster/node-pool REPLACEMENT in the plan: allowed ONLY because zero workloads are deployed (verify: `kubectl get deployments -A` empty before approving). Bastion host, VCN, repos, buckets, IP are untouched (plan must show no changes to them — if it does, STOP).
2. Keep: Basic, 2× A1 (2 OCPU/12 GB each, boot 50 GB, OL9, custom image ID via the `oke_worker` data source), public endpoint, `create_operator = false`, `v1.36.1` (ADR-013: adopted applied version; upgrades are deliberate PRs, never surprises). Check whether module 5.5.1 exposes API-endpoint CIDR restriction — if yes, set operator CIDR; if no, record the hardening follow-up in ADR-015 scope (RBAC + short-lived kubeconfigs are the guardrail meanwhile).
3. Kubeconfig (public endpoint, no tunnel): `oci ce cluster create-kubeconfig --cluster-id $(terraform output -raw oke_cluster_id) --file ~/.kube/walfa-prod --region ap-singapore-1` (region fixed — ADR-012). Write `docs/runbooks/cluster-access.md` (kubeconfig refresh; bastion-host SSH via `terraform output ssh_to_bastion`; DB tunnel via bastion host in Phase 10).

**VERIFY:**

```bash
kubectl --kubeconfig ~/.kube/walfa-prod get nodes   # exactly 2 nodes, Ready, v1.36.1
kubectl --kubeconfig ~/.kube/walfa-prod get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.labels.kubernetes\.io/arch}{"\t"}{.status.capacity.cpu}{"\t"}{.status.capacity.memory}{"\n"}{end}'  # both arm64 2 12Gi-ish
kubectl --kubeconfig ~/.kube/walfa-prod get pods -n kube-system -l k8s-app=kube-dns  # DNS healthy post-CNI-switch
oci lb load-balancer list --compartment-id $OCI_COMPARTMENT_OCID | grep -c ocid || echo "ZERO LB — CORRECT"
```

**DONE WHEN:** [ ] exactly 2 nodes Ready, both ARM64, 2 OCPU/12 GB each, v1.36.1 [ ] CNI is vcn-native (verify: no flannel DaemonSet, pod subnet exists) [ ] kubeconfig works with no tunnel [ ] adopted resources untouched [ ] LB count zero.
**DO NOT:** enable Enhanced, touch the bastion host, or approve a plan that replaces anything but the cluster/node-pool.

---

## Phase 7 — GitHub OIDC federation + IAM + the ONE sanctioned token

**GOAL:** CI deploys with short-lived identity; the OCIR token exception is caged.
**START ONLY WHEN:** Phase 6 done.
**BUILD:**

1. OCI IAM: the dynamic group `walfa-gha` EXISTS but its matching rule is broken (targets compute instances — useless for GitHub OIDC). REPLACE the rule with the repo-claim rule — exact GitHub OIDC subject `repo:$GITHUB_ORG_OR_USER/walfa:*` per Oracle's OIDC tutorial; record the rule verbatim in ADR-014. DELETE the commented-out `manage all-resources in tenancy` placeholder (replaced by the scoped policies below — it must never be uncommented).
2. IAM policies (least privilege, separate statements): `walfa-ci-plan` (inspect/read infra), `walfa-ci-apply` (manage VCN/OKE/DB-networking/Vault-secrets-use ONLY in WALFA compartment — no tenancy-wide rights), `walfa-ci-deploy` (use OKE cluster + read OCIR + use Vault secrets). Plan and apply are DIFFERENT principals (master §20.3).
3. GitHub: repo Environments `terraform-plan` (no approval), `terraform-apply` + `production` (required reviewers = human, no bypass). Store ONLY: `OCI_TENANCY_OCID`, `OCI_REGION`, `OCI_COMPARTMENT_OCID`, `OCIR_NAMESPACE`, `OCIR_TOKEN_USER`, `OCIR_TOKEN` (the sanctioned machine-user auth token from master §4.2 — created now, 90-day rotation reminder filed as a dated GitHub issue), plus `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ZONE_ID` (DNS-edit-only token from Phase 3 — used by Terraform DNS records AND the cert-manager DNS-01 Secret; same 90-day rotation rhythm, one combined reminder issue).
4. Workflows skeleton: extend `ci.yml`; add `terraform-plan.yml` (PR: fmt/validate/plan, post summary comment) and `terraform-apply.yml` (main + `production` approval: OIDC → apply saved plan artifact, NEVER re-plan-and-apply). Full build/deploy workflows arrive Phase 23 — these two must work NOW.

**VERIFY:** open a test PR touching a Terraform comment → plan workflow posts a plan summary with zero diff; push an empty commit to main → apply workflow waits for human approval (do NOT approve yet unless a change is pending); `oci iam policy list` shows the three scoped policies.
**DONE WHEN:** [ ] OIDC trust works (no API keys in GitHub except OCIR + Cloudflare tokens) [ ] plan/apply separation enforced [ ] rotation issue filed [ ] test PR proves the loop.
**DO NOT:** store OCI private keys/PEM in GitHub, grant tenancy-wide `manage all-resources`, or auto-approve applies.

---

## Phase 8 — Kubernetes platform baseline (namespaces → ingress → TLS)

**GOAL:** a private, policy-guarded cluster with working public HTTPS and ZERO apps.
**START ONLY WHEN:** Phase 7 done. (All `kubectl` here via the Phase 6 public-endpoint kubeconfig `~/.kube/walfa-prod` — no tunnel.)
**BUILD** (workdir `walfa/infra/kubernetes/`):

1. `base/`: namespaces `platform, apps, observability` (labels `pod-security.kubernetes.io/enforce=restricted`); `ResourceQuota` + `LimitRange` per namespace (LimitRange: defaultRequest `100m/128Mi`, defaultLimit `500m/512Mi` — every pod MUST still set explicit requests+limits, master §20.2); default-deny `NetworkPolicies` per namespace + explicit allow-list policies added alongside each workload later; dedicated `ServiceAccount`s (no default-SA automount: `automountServiceAccountToken: false` everywhere except where noted). PDB + anti-affinity expectation: every multi-replica Deployment (stateless services, gateway, bff) ships a `PodDisruptionBudget` with `minAvailable: 1` and a soft pod anti-affinity (`preferredDuringSchedulingIgnoredDuringExecution`) keyed on `app.kubernetes.io/name` to spread replicas across the 2 nodes; single-replica stateful workloads (Keycloak, Valkey) omit PDB (documented per workload).
2. metrics-server (OKE-required baseline) + verify `kubectl top nodes` works.
3. ingress-nginx: upstream manifests at the versions-table controller version (resolve exact tag + manifest digest at scaffold — `controller-vX.Y.Z` placeholders are forbidden in committed files), then patch its Service: `type: LoadBalancer` + OCI annotations (flexible shape, 10 Mbps, associated with the ADOPTED reserved IP `walfa-ingress-ip` — copy exact annotation keys from Oracle's OKE LB docs into ADR-015 ALONGSIDE the resolved version + digest; wrong keys silently create a DEFAULT-shape (paid) LB or a second IP). **Immediately run the single-LB tripwire** — count must go 0 → exactly 1, and the LB's IP must equal `terraform output public_ip_ingress`.
4. cert-manager: upstream manifests `v1.21.1` (per versions table) + `cloudflare-api-token-secret` Secret in the cert-manager namespace (rendered by CI from `CLOUDFLARE_API_TOKEN`, same template pattern as Phase 9) + `ClusterIssuer letsencrypt-staging` with DNS-01/Cloudflare solver (master §11.4, copy the YAML verbatim then substitute only the documented fields) + test Ingress `tls-test.$WALFA_DOMAIN` (backend: default-backend 404, annotated with the staging issuer) → staging cert issued (`kubectl describe certificate` READY True); then create `letsencrypt-prod` issuer. No prod certs until Phase 24 (staging proves the machinery without rate-limit risk). Set Cloudflare SSL mode to **Full (strict)** NOW (dashboard → SSL/TLS → Overview) — never Flexible. The `tls-test` host stays forever as the TLS canary.
5. DNS already points correctly IF Phase 5 wrote the reserved IP (it did — no placeholder dance; the IP predates the records). Verify `dig +short app.$WALFA_DOMAIN` == `terraform output -raw public_ip_ingress`; fix by Terraform change only if mismatched. Keep records proxied (orange-cloud) throughout — ACME DNS-01 is unaffected by proxying.
6. `overlays/prod/`: kustomization setting the free-capacity values + hostname; `overlays/scale/` exists but contains ONLY a `README.md` saying "future, do not apply".

**VERIFY:**

```bash
oci lb load-balancer list --compartment-id $OCI_COMPARTMENT_OCID | grep -c '"lifecycle-state": "ACTIVE"'  # exactly 1
curl -sk https://tls-test.$WALFA_DOMAIN/ -o /dev/null -w "%{http_code}\n"   # 404 from nginx (proves TLS+routing, no app needed)
kubectl get certificate -A -o jsonpath='{range .items[*]}{.metadata.name} {.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}'  # tls-test True
kubectl auth can-i --list --as=system:serviceaccount:apps:default -n apps | grep -i "create pods" || echo "DEFAULT-DENY OK"
```

**DONE WHEN:** [ ] exactly 1 LB (10 Mbps flexible) [ ] staging TLS terminates at ingress (canary green) [ ] quotas/policies enforced [ ] prod issuer exists but unused [ ] `scale/` unappliable by construction.
**DO NOT:** deploy apps/Keycloak yet, expose NodePorts, or accept a second LB "for testing".

---

## Phase 9 — Vault values + secret delivery (the day plaintext dies)

**GOAL:** every secret lives in exactly one home (master §10 table); pods receive only what they need; rotation proven BEFORE anything depends on it.
**START ONLY WHEN:** Phase 8 done.
**BUILD:**

1. Human generates (locally, `openssl rand -hex 32`, never in CI logs) and writes DIRECTLY to Vault via CLI (never via Terraform values): 5 DB passwords (placeholders NOW, rotated to real in Phase 10 after users exist), `wallet-password`, `keycloak-admin` (32+ chars), `oidc-client-secret`, `session-secret` (64 hex), `valkey-password`. (+ `par-issuer-key` ONLY if ADR-010 later chooses media Option A — not now.) Commands: `oci vault secrets secret create-base64 --secret-name db-identity-password ...` per secret; verify by LISTING only (never print payloads).
2. Delivery mechanism (binding, master §10): **CI-injected Kubernetes Secrets.** `deploy` workflows fetch secret payloads via OIDC-authenticated OCI CLI at deploy time and `kubectl apply` per-consumer `Secret` manifests rendered from redacted templates in `infra/kubernetes/base/secrets/*.tmpl.yaml` (placeholders `REDACTED-BY-CI`, `stringData`, one Secret per consumer: `identity-db`, `portfolio-db`, `publishing-db`, `media-db`, `analytics-db`, `keycloak-admin`, `oidc-client`, `valkey-auth`, `oracle-wallet`, `edge-gateway-session` (renders `session-secret` for edge-gateway)). No External Secrets Operator on free (memory + complexity). Rotation = new Vault value + redeploy (documented in `docs/runbooks/secret-rotation.md`).
3. Wallet secret: `oracle-wallet` Secret (cwallet.sso + tnsnames.ora + sqlnet.ora, Phase 10 fills real bytes) mounted read-only at `/wallet` with `TNS_ADMIN=/wallet` in the template Deployment spec used as the pattern for all DB services.
4. Rotation drill NOW (cheap, nothing live): rotate `valkey-password` placeholder → re-render → confirm new hash differs (`kubectl -n platform get secret valkey-auth -o jsonpath='{.data.password}'`), then document the exact 5-command rotation in the runbook.

**VERIFY:** `git log -p --all | grep -iE "BEGIN (RSA )?PRIVATE KEY|password\s*[:=]\s*['\"][^'\"]{4,}" || echo "NO LEAKS"`; `kubectl -n apps get secrets` shows per-service secrets with zero overlap (`identity-db` not mountable by portfolio — enforced by separate Secrets + runbook check); GitHub Actions deploy logs contain `***` redactions only.
**DONE WHEN:** [ ] 10 Vault secrets filled (DB placeholders noted) [ ] template Secrets render without values in git [ ] rotation drill recorded [ ] leak-scan clean.
**DO NOT:** commit wallet files, print secret payloads to logs, or share one Secret across services "for simplicity".

---

## Phase 10 — Database init (users, schemas, wallet, migration machinery)

**GOAL:** five isolated schemas + proven wallet connectivity + the canonical migrate-Job pattern.
**START ONLY WHEN:** Phase 9 done (wallet + password plumbing exists).
**BUILD:**

1. As ADB ADMIN from the operator laptop through a Bastion SSH tunnel to the DB private endpoint (`ssh -L 1522:<db-endpoint>:1522 <bastion>`, then `sqlplus admin/<pw>@localhost:1522/<service_name>` — the ONLY interactive ADMIN use; afterwards ADMIN lives in Vault, break-glass only): create users `ID_SVC, PORTFOLIO_SVC, PUBLISHING_SVC, MEDIA_SVC, ANALYTICS_SVC, KEYCLOAK` (identified by the Phase 9 Vault passwords — set via bind variables, never pasted into committed `.sql` files; committed scripts use `&1` substitution variables), each with `DEFAULT TABLESPACE DATA`, quota 3 GB each (6×3 = 18 GB of 20 GB — tight by design, headroom documented), `CREATE SESSION` + object privileges ONLY in its own schema. No `DBA`, no cross-schema grants (verify against `DBA_TAB_PRIVS` — expect zero cross grants).
2. Download the ADB wallet (OCI CLI over the same tunnel), split into the `oracle-wallet` K8s Secret (Phase 9 template) + full wallet ZIP into Vault as backup. Update `tnsnames.ora` alias choice: services use `<dbname>_low`.
3. `db/migrations/<service>/`: baseline `000001_init.up.sql` (+ `.down.sql` for local teardown) per service in `docs/specs/migrations.md` format — ONLY its tables + `event_outbox` (master §8.2 DDL verbatim) + indexes justified in comments. Validate NOW by applying with `sqlplus` against local `oracle-free` (`FREEPDB1`): every file applies clean, objects verified, then torn down with the `.down.sql`. CI `migration validation` job (full shape in Phase 23): forbidden-keyword grep + double-apply no-op test on disposable `oracle-free`.
4. Canonical migrate-Job manifests: write `infra/kubernetes/base/jobs/migrate-identity.yaml` ONCE (service image, `args: ["migrate","up"]`, `restartPolicy: Never`, `activeDeadlineSeconds: 300`, Vault-synced env) — render + dry-run clean NOW, but do NOT execute: the identity image does not exist until Phase 14, and the first LIVE Job run is Phase 14's gate. The other four Job manifests are copies in their service phases. Each service binary implements `migrate` itself with its OWN local migrator + embedded SQL (§7.4c) — no shared migrator, no third-party tool.
5. Record ACTUAL session counts under load later; for now enforce master §7.4a budget table as env defaults (`DB_MAX_OPEN_CONNS`) in each Job/Deployment template.
6. Backup proof: ADB auto-backups are ON by default — verify (`oci db autonomous-database get --query data.{...retention...}`), record restore-point procedure in `docs/runbooks/disaster-recovery.md` (automatic backups + wallet-in-Vault ARE the restore story; `scripts/restore-db.sh` wraps OCI restore APIs, never `expdp`).

**VERIFY:**

```bash
# per-service isolation: connect as PORTFOLIO_SVC, expect failure selecting ID schema
echo "SELECT COUNT(*) FROM ID_SVC.event_outbox;" | sqlplus portfolio_svc/<pw>@<tns>  # must ERROR ORA-00942
# baselines proven locally (no service binary exists yet — first live migrate-Job runs in Phase 14):
sqlplus id_svc/<pw>@localhost:1521/FREEPDB1 @db/migrations/identity/000001_init.up.sql  # clean apply, repeat per service
```

**DONE WHEN:** [ ] 6 users, quotas, zero cross-grants [ ] wallet Secret mounts + `_low` connects from a debug pod [ ] 5 baselines apply cleanly via sqlplus on oracle-free [ ] migrate-Job manifests render + dry-run clean (first LIVE run in Phase 14) [ ] budget table enforced as defaults [ ] backup/DR runbook written.
**DO NOT:** execute migrate-Jobs before their service image exists (Phase 14+), run Jobs in parallel ever, grant DBA, commit real passwords, or run down-migrations anywhere but disposable local oracle-free.

---

## Phase 11 — Keycloak (identity arrives before the apps that trust it)

**GOAL:** working OIDC provider with realm-as-code, MFA-ready, recoverable.
**START ONLY WHEN:** Phase 10 done (its schema/user/wallet exist).
**BUILD** (workdir `walfa/infra/kubernetes/base/keycloak/`):

1. `StatefulSet` (1 replica, `250m/768Mi` request/limit starting point inside master §11.2 band) + ClusterIP Service (NEVER LoadBalancer/NodePort — reached via ingress private route + admin via Bastion port-forward only). Env: `KC_DB=oracle`, `KC_DB_URL` (JDBC thin TNS descriptor), wallet via Java system properties `JAVA_OPTS_APPEND="-Doracle.net.tns_admin=/wallet -Doracle.net.wallet_location=(SOURCE=(METHOD=file)(METHOD_DATA=(DIRECTORY=/wallet)))"` with `/wallet` mounted from the `oracle-wallet` Secret, `KC_HOSTNAME=https://auth.$WALFA_DOMAIN`, `KC_PROXY=edge`, `--optimized --cache=local --http-enabled=false`, admin from Vault Secret. Image pinned `quay.io/keycloak/keycloak:26.7.3` exactly (per versions table; digest recorded in ADR-000; patch-review monthly).
2. `docs/keycloak/realm-walfa.json` IN GIT (realm-as-code: realm `walfa`, client `walfa-web` authorization-code + PKCE, redirect URIs `https://app.$WALFA_DOMAIN/*`, web origins, logout URLs, password policies if any local users for break-glass, WebAuthn policy per master §9.7). Imported at first boot (`--import-realm`), afterwards changed ONLY via re-import PRs — no click-ops (click-ops drift = re-import and diff).
3. JWKS/issuer sanity: `OIDC_ISSUER_URL=https://auth.$WALFA_DOMAIN/realms/walfa`; gateway will pin this exact string (Phase 19).
4. Break-glass: sealed admin-recovery procedure in `docs/runbooks/keycloak-recovery.md` (Vault admin password + `kubectl port-forward` + realm JSON re-import). MFA: enable WebAuthn/authenticator at realm level now (master §9.7), test with one human account.
5. ADR-010 resolved HERE if deferred: media PAR decision (master §13) must be closed by end of this phase — no later. (Option A creates the conditional `par-issuer-key` Vault secret via the Phase 9 procedure.)

**VERIFY:** authorization-code login in a browser directly against `https://auth.$WALFA_DOMAIN` (public ingress — no tunnel, no allow-list hack) succeeds; `curl` with a forged `alg:none` token against the future gateway stub fails (gateway arrives Phase 19, but record the negative test now); Keycloak pod `kill` → StatefulSet restarts → login still works (DB-backed sessions); realm JSON re-import is a no-op diff.
**DONE WHEN:** [ ] login/logout/refresh works [ ] realm fully in git [ ] MFA enabled [ ] recovery runbook tested [ ] resource usage observed (`kubectl top`) and inside budget [ ] ADR-010 closed.
**DO NOT:** deploy a second IdP (no Dex without an upstream-broker ADR), store users' passwords in WALFA, or expose the admin console publicly.

---

## Phase 12 — Valkey (small, authed, TTL-disciplined)

**GOAL:** the cache/session/rate-limit backbone with proof it degrades gracefully.
**START ONLY WHEN:** Phase 11 done.
**BUILD** (`infra/kubernetes/base/valkey/`): image `valkey/valkey:9.1.1` (+ digest in ADR-000); StatefulSet 1× (`100m/512Mi`, `--maxmemory 512mb --maxmemory-policy allkeys-lru`, `requirepass` from Secret, AOF persistence enabled (`appendonly yes`, `appendfsync everysec`) on a 10 GB PVC (`storageClassName` per OKE default; `volumeClaimTemplates` `10Gi`)), ClusterIP Service `valkey.platform.svc:6379`, NetworkPolicy allowing ONLY `apps` namespace clients. NO shared client wrapper: each service later writes its own thin wrapper over `valkey-go` strictly to `docs/specs/valkey-keys.md` (prefixes `sess:|ratelimit:|bff:public:`, mandatory TTL args — raw unprefixed key access is forbidden by review).

**VERIFY:** wrong password rejected; `allkeys-lru` eviction observed under fill test (mass SET with TTLs, then `INFO memory`); pod delete → data retained via AOF on PVC (`INFO persistence` confirms `aof_enabled:1`, `aof_rewrite_in_progress`/`aof_last_bgrewrite_status` clean after reload) → sessions SURVIVE (re-login NOT required — document recovery timeline in runbook); `kubectl top` inside budget.
**DONE WHEN:** [ ] auth enforced [ ] AOF persistence live on 10 GB PVC [ ] key-layout spec conformance proven by a throwaway client (deleted afterwards — it must NOT become a shared helper) [ ] eviction + restart behavior (pod delete → data retained, sessions survive) demonstrated and documented.
**DO NOT:** share Valkey across environments, store anything without a TTL, or keep the throwaway client around.

---

## Phase 13 — OCI Queue access + SDK conformance (the managed transport, proven)

**GOAL:** services authenticated to Queue + per-service SDK implementation pattern proven + all four transport gates green. Queues themselves were built in Phase 5.
**START ONLY WHEN:** Phase 12 done.
**BUILD:**

1. Access (human + Terraform): Terraform creates machine user `walfa-queue-client` + group + IAM policy (queue operations ONLY in WALFA compartment). Human creates the API key pair (`oci iam user api-key upload`), stores the private key in Vault as `queue-client-key` (master §10 table), and adds the `oci-queue-key` (K8s name; Vault name is `queue-client-key`) Secret template (`/.oci/` mount: `config` + `key.pem`, `OCI_CONFIG_FILE=/.oci/config`) to `infra/kubernetes/base/secrets/` following the Phase 9 pattern. Record in the §4.2-exception ADR with the rotation date (90 days).
2. Transport selftest Job `infra/kubernetes/base/jobs/transport-selftest.yaml` using the `oci-cli` image (shell + `oci queue` commands ONLY — no WALFA code): PutMessages batch of 100 → GetMessages long-poll → assert count + payload integrity → DeleteMessages → queue empty. Then visibility proof: put 1, get WITHOUT delete, wait > visibility timeout, get again → redelivered. This is infrastructure verification, not a shared library.
3. DLQ proof (once, recorded): create TEMPORARY queue `walfa-dlq-test` (max-delivery-count=2, short visibility) via CLI → publish 1 poison message → GetMessages repeatedly WITHOUT deleting → after 2 deliveries it routes to `walfa-dlq` → assert arrival → DELETE the temp queue. Log pasted into ADR-009.
4. Each FUTURE service (Phases 14–18) implements its own publisher/consumer with `oci-go-sdk` directly against `docs/specs/queue-topology.md` + `outbox.md` (batched PutMessages, long-poll GetMessages, DeleteMessages-after-commit, startup queue resolution by display name) and ticks the `conformance-checklist.md` transport rows with its own tests — using its OWN in-memory fake locally (fake implements put/get/delete only), proven against the real Queue here and in Phase 24. Write checklist sharpening HERE if the specs need it — not code.
5. ADR-009 closed: Queue canonical, 1M-free-tier re-verification result (Phase 5) + selftest/DLQ logs + API-call budget math (worst-case estimate vs 1M cap) + spend-alarm pointer. Wire the outbox-age metric hook expectation (counter/gauge emission point each service implements) for the Phase 5 alarm.

**VERIFY:**

```bash
kubectl -n apps apply -f infra/kubernetes/base/jobs/transport-selftest.yaml && kubectl -n apps wait --for=condition=complete job/transport-selftest --timeout=300s
kubectl -n apps logs job/transport-selftest | grep -E "ROUNDTRIP OK|REDELIVERY OK"
oci queue queue list --compartment-id $OCI_COMPARTMENT_OCID | grep -c walfa   # 6 (5 + dlq, temp deleted)
```

Expected: put→get→delete round-trip clean; visibility-timeout redelivery works; poison lands in `walfa-dlq`; temp queue gone. (Per-service duplicate-delivery proofs arrive with their own tests in Phases 14–18.)
**DONE WHEN:** [ ] selftest green against real Queue [ ] DLQ proven + temp queue deleted [ ] machine key in Vault + Secret template renders [ ] ADR-009 closed with budget math [ ] outbox-age alarm wired.
**DO NOT:** deploy NATS "to compare", share one OCI key across humans, bake the key into images, or write a shared Queue wrapper package.

---

## Service phases 14–18 — per-service build (same skeleton, separate code, zero sharing)

Every service phase executes THE SAME skeleton with different domain content — but each service is an INDEPENDENT Go module. Copying the skeleton shape is required; importing another service's code is forbidden (CI `no-cross-import` job fails the PR).

**Per-service skeleton:**

1. `db/migrations/<svc>/00000N_*.up.sql` (+ `.down.sql` for local teardown) in `docs/specs/migrations.md` format (expand/migrate/contract; checksum-recorded; forbidden-keyword grep green; double-apply no-op proven in CI).
2. `services/<svc>/` — NEW Go module (`go mod init github.com/<org>/walfa/services/<svc>`, added to `go.work`): `main.go` (`serve|migrate` subcommands), `config.go` (typed env, fail-fast), `domain/` (pure logic, >80% unit coverage), `store/` (Oracle SQL via `go-ora`, pool from §7.4a budget), `http/` (chi routes, error shape + pagination + request-ID implemented LOCALLY per `docs/specs/http-conventions.md`), `outbox.go` (emit + dispatch implemented LOCALLY per `docs/specs/outbox.md` + `event-envelope.v1.json`), `consumer.go` (if subscribing; idempotency via `consumer_name+event_id`), `internal/testhelper/` (OWN fake OIDC issuer, OWN fixtures — never imported by anyone else), `internal/migrate/` (OWN minimal migrator per `docs/specs/migrations.md` — never imported by anyone else), `*_test.go` (unit + integration + contract tests; `oracle-free`-backed, never Postgres). Tick EVERY row of `docs/specs/conformance-checklist.md` that applies.
3. `Dockerfile` (multi-stage, non-root, read-only FS, `linux/arm64+amd64`, no secrets) — final push happens Phase 22, but the file + local `docker buildx build --platform linux/arm64` smoke test happen HERE.
4. `infra/kubernetes/base/<svc>/`: Deployment (`replicas: 2`, requests/limits from master §11.2 band, `TNS_ADMIN=/wallet`, per-service Secret, probes: `liveness /health/live period 20s failureThreshold 3`, `readiness /health/ready period 10s failureThreshold 3` — slow-start-safe on A1; soft pod anti-affinity `preferredDuringSchedulingIgnoredDuringExecution` keyed on `app.kubernetes.io/name` to spread across the 2 nodes), `PodDisruptionBudget` `minAvailable: 1`, ClusterIP Service, migrate-Job (copy of Phase 10 pattern), NetworkPolicy (ingress ONLY from gateway + explicitly listed peers; egress to DB endpoint + OCI Queue API + Valkey as needed), HPA explicitly ABSENT on free (documented: replicas fixed at 2, master §2.3). Subscribing services label their Deployment `app.kubernetes.io/consumes-queues: "true"` (used by the Phase 24 consumer-pause chaos step).
5. Gate per service (below). Only then next service.

**Phase 14 — identity.** Principal `(issuer,subject)` (never email) + local profile + session tracking (Valkey `sess:`) + account purge (cascading delete emitting `user.purged.v1` → analytics/portfolio/publishing/media consume) + audit events. Gate: FIRST LIVE migrate-Job run (`migrate-identity` against ADB — `schema_version` row proves it) → login creates/loads user; logout kills session cluster-wide; purge verified across all five schemas (count queries zero).
**Phase 15 — portfolio.** Profile/experience/education/skills/projects CRUD + owner-only writes + optimistic concurrency (`entity_version` check on update, 409 on mismatch) + `portfolio.*.v1` outbox events. Gate: full CRUD suite + concurrent-edit 409 test + events observed via the service OWN in-memory Queue fake + outbox rows marked published; real-Queue proof lives in Phase 13 selftest and Phase 24 e2e.
**Phase 16 — publishing.** Articles/tags/guides/legal + state machine `draft→preview→published→unpublished` (illegal transitions 422 + tested transition matrix) + slug uniqueness + `publishing.*.v1` events. Gate: preview/publish/unpublish cycle + illegal-transition rejection + sitemap-relevant fields exposed for web-bff.
**Phase 17 — media.** Metadata schema + upload-authorization per ADR-010 (Option A default: PAR single-object/15-min/server-keyed; Option B: proxied stream) + MIME sniffing from bytes (`net/http.DetectContentType` + extension cross-check; SVG rejected unless sanitizer ADR'd) + size caps + orphan-cleanup CronJob (grace 24h, domain-reference check before delete, audit event) + checksum stored at finalize. Gate: PAR expiry enforced; anonymous LIST denied; GET with exact key works (ObjectRead by design); unauthenticated PUT/DELETE rejected; oversized/wrong-type rejected; orphan job dry-run lists exactly the fixtures' orphans.
**Phase 18 — analytics.** `POST /api/v1/beacon` handler (lightweight: validate → insert raw → 204, p95 <100ms local) + rollup worker (minute→hour→day materialization) + retention purge CronJob (raw rows deleted per policy, rollups kept) + `user.purged.v1` consumer deleting/analytics-scrubbing + privacy fields (no IP storage, `anonymous_id` or `session_id`, DNT respected). Gate: fixture beacons reconcile exactly with rollups; retention job deletes only expired rows; purge propagates (query zero).

---

## Phase 19 — edge-gateway (the trust boundary, built AFTER what it protects)

**GOAL:** every external byte inspected, stripped, limited, and attributed.
**START ONLY WHEN:** Phases 14–18 gates green.
**BUILD** (`services/edge-gateway/` — own module like all services — + `infra/kubernetes/base/edge-gateway/`): pipeline order EXACTLY as master §12 (strip client identity headers → request-ID → origin/CSRF → body/header limits → Valkey fixed-window rate limits per IP+route, beacon route stricter → OIDC/session check via pinned issuer + locally-hardcoded alg allow-list [`RS256, ES256`] + JWKS cache + OWN fake-OIDC issuer in its test files → server context injection `X-Request-Id/X-Trace-Id/X-Authenticated-User-Id/X-Service-Identity` → route). Security headers on all responses (`Strict-Transport-Security, X-Content-Type-Options, Referer-Policy, frame-ancestors 'none'`); `/health/*` unauthenticated, everything else default-deny with explicit public-route allow-list (`GET` public reads, beacon POST, login callbacks).

**VERIFY:** unauthenticated mutation → 401; forged `X-Authenticated-User-Id` from client → stripped/ignored (test asserts downstream sees server value); rate burst → 429 with `Retry-After`; `alg:none` JWT → 401; oversized body → 413; downstream services' NetworkPolicies REJECT direct calls bypassing gateway (curl from debug pod → timeout).
**DONE WHEN:** [ ] all negative tests green [ ] bypass impossible at network layer [ ] public-route list reviewed by human.
**DO NOT:** add business logic, DB access, "temporary" unauthenticated admin routes, or a shared auth middleware package.

---

## Phase 20 — web-bff (public reads, cached, invalidated)

**GOAL:** fast public pages that survive a downstream restart.
**START ONLY WHEN:** Phase 19 done.
**BUILD** (`services/web-bff/` — own module): aggregate endpoints (homepage, public profile, article render, sitemap.xml, robots.txt, ads.txt-if-needed, canonical-URL helpers) reading service APIs through the gateway + Valkey `bff:public:` cache (TTL ≤300s, own client per `valkey-keys.md`) + Queue invalidation consumer (own implementation per `queue-topology.md`; on `portfolio.*`/`publishing.*` events → precise key DEL, never flush-all) + stale-while-revalidate: serve stale cache when downstream is down (the gate below) with `Warning: 110` semantics logged + post-deploy warm hook `scripts/warm-bff.sh` (curls top routes to refill cache after each deploy; best-effort, logged, never blocking rollout).

**VERIFY:** stop portfolio Deployment → public pages still 200 from cache; publish event → cache key invalidated within 10s (test asserts fresh content post-event); sitemap validates (submit to a validator, check canonical/OG tags); cold start with empty cache → correct (slow) render, no 500s; `warm-bff.sh` fills cache (hit-rate rises on second pass).
**DONE WHEN:** [ ] stale-serving proven [ ] invalidation precise [ ] SEO artifacts valid [ ] warm hook committed.
**DO NOT:** give web-bff write endpoints, direct DB access, immortal cache keys, or a shared caching library.

---

## Phase 21 — Nuxt SPA (the only thing users see)

**GOAL:** complete, accessible, SEO-correct UI that talks ONLY to the gateway.
**START ONLY WHEN:** Phase 20 done.
**BUILD** (`apps/web/`, Nuxt 4 pinned exact + lockfile committed, Node 24 LTS with `.nvmrc`, SPA mode (`ssr: false`, static, gateway-only), app code under `app/` per Nuxt 4 defaults): routes (home, portfolio, articles, guides, media views, login/logout callbacks, account/purge settings, error pages 404/500/offline), auth flow via Keycloak authorization-code (tokens in HttpOnly SameSite cookies via gateway session — NEVER localStorage, master §9.5), public pages fed by web-bff SSR (`Browser → gateway → web-bff`, master §15), mutations to owning services through gateway, meta/OG/canonical per route, sitemap wiring, axe-clean accessibility baseline + keyboard navigation + focus states, Playwright E2E suite (`apps/web/tests/e2e/`: login, logout, session-expiry, portfolio CRUD UI, publish flow, media upload, beacon fires, purge flow, rate-limit banner, offline/error states). (Nuxt 3 is EOL since 2026-07-31 — forbidden. Nuxt 5 ships ~Q4 2026: adopt no earlier than 6 months after GA, via ADR.)

**VERIFY:** `npm run lint && npm run typecheck && npm run test && npx playwright test` all green; Lighthouse (local): Performance ≥80 on free-shaped throttling, Accessibility ≥95, SEO 100 on public routes; no `fetch(` to any host except the gateway (grep test in CI).
**DONE WHEN:** [ ] E2E suite green [ ] no direct service calls from browser [ ] no tokens in localStorage (assert via test) [ ] a11y/SEO bars met.
**DO NOT:** call OCI Queue/Valkey/DB from frontend, embed secrets in public runtime config, or bypass the gateway "for speed".

---

## Phase 22 — Docker multi-arch + OCIR (one pipeline, eight images)

**GOAL:** every service ships as a pinned, scanned, SBOM'd ARM64+AMD64 image.
**START ONLY WHEN:** Phase 21 done (all Dockerfiles exist from Phases 14–21).
**BUILD:**

1. Harden each Dockerfile to master §16 (multi-stage, `CGO_ENABLED=0 go-ora`, non-root `USER 65532`, read-only FS + `TMPDIR` writable mount, `ARG GIT_SHA/VERSION` baked as version metadata, `.dockerignore` excluding `.git, *.md, db/seeds, wallet files`).
2. Local proof per image: `docker buildx build --platform linux/arm64 -t walfa/<svc>:test --load .` then `docker run --rm walfa/<svc>:test ./app --help` shows `serve|migrate` + version. ARM64 must RUN (QEMU-slow is fine; "builds" is not proof).
3. Push with BOTH tags (`sha-<git-sha>` immutable + `release-<version>`), `--sbom=true --provenance=true`, push SBOM to OCIR alongside; `trivy`/`grype` scan gates: CRITICAL = fail, HIGH = human waiver with expiry date or fail.
4. Record digests: `infra/kubernetes/overlays/prod/` patches pin `image: <ocir>/<svc>@sha256:<digest>` — overlays reference DIGESTS, never `:latest` or moving tags (master §16).

**VERIFY:** all 8 digests resolve (`docker buildx imagetools inspect <digest>`); `trivy` report attached to release; a `latest` tag exists NOWHERE (`grep -r ":latest" infra/ Dockerfile* services/*/Dockerfile apps/web/Dockerfile* || echo CLEAN`).
**DONE WHEN:** [ ] 8 digest-pinned images in OCIR [ ] SBOM+provenance present [ ] scan policy enforced [ ] no `latest`.
**DO NOT:** push from laptops as routine (CI does it Phase 23+; this phase's pushes are the bootstrap exception, logged), bake secrets into layers (scan layers with `dive` if unsure).

---

## Phase 23 — GitHub Actions full CI/CD (the machine that ships)

**GOAL:** every merge path automated, gated, and credential-clean.
**START ONLY WHEN:** Phase 22 done.
**BUILD** (`.github/workflows/`, OIDC-first per Phase 7):

1. `ci.yml` (PR): install the pinned task runner FIRST (per versions table — every later step calls `task`, never bare tools); per-service-module loop (fmt/vet/test/race for each `services/*`), `golangci-lint` per module, **no-cross-import job** (for each `services/<s>`: `grep -rn "walfa/services/" services/<s> --include="*.go" | grep -v "walfa/services/<s>"` must be EMPTY — fails the PR otherwise), `no-shared-package` job (`test ! -d packages` — the directory must never come back), frontend lint/typecheck/test, migration validation (forbidden-keyword grep + double-apply no-op on disposable `oracle-free`, per service), `docker buildx` smoke (no push), `terraform fmt -check`+`validate`, `kustomize build overlays/prod | kubeconform` on manifests, `python3 scripts/validate-envelope.py` spec check, `trivy` fs+config scan, `gitleaks` secret scan, commitlint (conventional commits — required by `release.yml`). `.github/dependabot.yml` (ecosystems: gomod, npm, docker, terraform, github-actions — weekly): the update engine for `docs/versions.md`; bump PRs update the TABLE first, code second. Fork PRs get ZERO OCI credentials (assert with a job that fails if secrets are reachable — negative test).
2. `security.yml` (weekly + PR-touching-deps): `govulncheck` per module, `npm audit`, image CVE rescan of in-use digests, license check (deny AGPL-incompatible surprises — record policy in ADR-016).
3. `terraform-plan.yml` / `terraform-apply.yml`: as Phase 7, plus drift-detection schedule (nightly plan on main, alert-on-diff, never auto-apply).
4. `build-publish.yml` (main): test → buildx ARM64+AMD64 → scan → push OCIR (sanctioned token ONLY here) → SBOM/provenance → output digest manifest artifact.
5. `deploy-prod.yml` (`production` environment, human approval): OIDC → public-endpoint kubeconfig (`oci ce cluster create-kubeconfig`, short-lived) → render secrets from Vault (Phase 9 templates) → `kubectl apply` migrate-Jobs **SERIALLY** + `wait` each (Phase 10 pattern; any Job failure ABORTS before app rollout) → `kustomize build overlays/prod | kubectl apply -f -` → `rollout status` per Deployment → `scripts/warm-bff.sh` (best-effort) → smoke suite → release metadata (digests, migration versions, actor) committed to `docs/releases/`.
6. `release.yml` (tag `v*`): changelog from conventional commits, GitHub Release with digest table + SBOM links + rollback pointer (previous tag's digests + forward-fix note — down-migrations never run in production, master Runbook C).
7. Rollback runbook `docs/runbooks/rollback.md`: exact commands (re-apply prior release dir, `rollout undo` semantics, migration forward-fix procedure, LB/DNS untouched).

**VERIFY:** a no-op PR is fully green; a deliberately-broken migration PR fails at the migration job (test with fixture); a deliberately cross-importing PR fails at `no-cross-import` (test with fixture); fork-PR simulation shows no credential access; `deploy-prod.yml` dry-run passes; approval gate blocks unapproved runs.
**DONE WHEN:** [ ] all 7 workflows green on fixture PRs + dry-runs per VERIFY [ ] serial-migration ordering proven [ ] cross-import guard proven with fixture [ ] rollback doc executable (walk it once against staging state) [ ] zero long-lived creds except OCIR + Cloudflare tokens.
**DO NOT:** `apply -auto-approve` from branches, re-plan inside apply (apply the saved plan artifact), or let forks reach Vault/OCIR.

---

## Phase 24 — Production validation on free capacity (prove it survives reality)

**GOAL:** the whole stack, deployed by CI, stable under load and failure.
**START ONLY WHEN:** Phase 23 done. Human on standby (may need console clicks).
**BUILD (execute, in order):**

1. Full `deploy-prod.yml` run to production: all migrate-Jobs → all Deployments → ingress routes → FIRST prod certs from `letsencrypt-prod` (DNS-01 against Cloudflare; staging proven Phase 8). Confirm Full (strict): `curl --resolve app.$WALFA_DOMAIN:443:<LB-IP> https://app.$WALFA_DOMAIN/` presents a valid LE origin cert (not just the Cloudflare edge cert).
2. Smoke suite (automated script `scripts/smoke-prod.sh`, committed): HTTPS 200s, login→CRUD→logout, beacon 204, sitemap valid, `/metrics` reachable internally only.
3. Load test within free physics: `k6` script (`scripts/load-prod.js`, committed) capped at 8 Mbps / 50 VUs — assert p95 latency + zero 5xx + LB NOT saturated + `kubectl top` headroom ≥20% memory (baseline: 24 GB total across 2 nodes; ≥20% = ≥4.8 GB free under load). If headroom fails, shed load FIRST from analytics workers/retention frequency (record in ADR), never by silently raising limits past §11.2 bands without re-budgeting §11.7.
4. Connection audit: sum of live Oracle sessions vs §7.4a budget (`SELECT COUNT(*) ... GROUP BY username`); Keycloak pool + all services must fit ≤40.
5. Chaos set (one at a time, record recovery time each): delete one app pod; delete Valkey pod (sessions survive via AOF persistence on PVC — verify `INFO persistence` post-reload); restart Keycloak (existing sessions continue per Runbook D, new logins pause); **node-drain test** (`kubectl drain <node> --ignore-daemonsets --delete-emptydir-data` → stateless Deployments (replicas 2 with PDB minAvailable 1) stay up on the surviving node → `kubectl uncordon <node>` → pods reschedule back → record recovery time + zero-downtime proof); stop Queue consumers 60s (`kubectl scale deploy -n apps -l app.kubernetes.io/consumes-queues --replicas=0`; outbox backlog grows → alarm fires → scale back, drains with zero loss); fill media tmp (lifecycle purges in 7d — simulate with short-prefix test rule, then delete it).
6. Wallet-rotation rehearsal (re-download wallet, update Secret, rolling restart, zero-downtime proof).
7. Rate-limit independence proof (master §11.1 caveat): two distinct clients (different X-Forwarded-For) burst concurrently; assert each is limited independently; record result in VALIDATION.md.

**VERIFY:** all six steps produce committed logs under `docs/validation/prod-YYYY-MM-DD/`; every runbook referenced executed at least once with real commands pasted; ALL §24-table gates (master §24) ticked off in a `VALIDATION.md` checklist.
**DONE WHEN:** [ ] stable at target load with headroom [ ] chaos recoveries timed + documented [ ] sessions ≤ budget [ ] prod TLS live + renewal calendar entry filed [ ] validation pack committed.
**DO NOT:** "temporarily" raise limits/quotas to pass load tests, skip the wallet rehearsal, or declare victory with staging certs.

---

## Phase 25 — Hardening + DR rehearsal + cost audit (production-ready stamp)

**GOAL:** attacked, restored, and audited — then (and only then) production.
**START ONLY WHEN:** Phase 24 validation pack merged.
**BUILD:**

1. Security sweep: `trivy` image rescan (zero CRITICAL), `govulncheck` (per module) + `npm audit` clean-or-waiver, `gitleaks` full-history scan, CIS-lite K8s review (read-only FS, non-root, no privileged, capabilities dropped — assert via `kubectl` query script `scripts/assert-podsecurity.sh`, committed), dependency updates merged (Go + npm + action pins + K8s manifest pins).
2. Renewal/rotation proofs: force staging re-issue (cert-manager; `tls-test` canary first), rotate ONE non-DB secret end-to-end via Phase 9 runbook, rotate OCIR + Cloudflare tokens if >60 days old.
3. DR rehearsal (the real one): record RTO/RPO achieved for (a) full Terraform recreate into a scratch compartment state (`plan` from empty state — do NOT destroy prod; prove recreatability without touching prod), (b) ADB point-in-time restore procedure walked through to the "ready to restore" step with console screenshots/CLI transcript, (c) Keycloak realm re-import from git onto a scratch namespace, (d) outbox replay against Queue (publish backlog fixture, watch drain). Results + timings → `docs/runbooks/disaster-recovery.md` (replace aspirational text with measured numbers).
4. Cost/quota audit: re-run Phase 3 quota queries (A1: 4 OCPU / 24 GB — fully used across 2 nodes), LB count = 1, block storage ~157 GB of 200 GB free budget (50 GB × 2 boot + 10 GB Valkey PVC + overhead), object-storage bytes vs budgets, confirm $0 spend + budget alarm armed; ANY deviation = stop + ADR.
5. `docs/runbooks/` final pass: every runbook (A–E + rollback + recovery + rotation + cluster-access) executable verbatim — LLM re-runs each command block in order as the test.

**VERIFY:** `scripts/assert-podsecurity.sh` exit 0; DR timings recorded (not "TBD"); cost audit shows $0 with evidence pasted; human signs `VALIDATION.md` + Definition-of-Done checklist (master §31, every bullet initialed).
**DONE WHEN:** [ ] scans clean [ ] DR rehearsed with numbers [ ] $0 proven [ ] all runbooks executable [ ] master §31 fully checked [ ] as-built docs merged [ ] `v1.0.0-free` tagged.
**DO NOT:** skip DR "because ADB auto-backups exist" (unproven restores don't exist), accept HIGH/CRITICAL waivers without expiry dates, run chaos against prod data without a fresh restore point, or start `scale/` work in this phase (scale is a new project with its own phases, master §28).

---

## Phase 25b — Final handoff (part of Phase 25, same PR or immediate follow-up)

**GOAL:** the repo explains itself to a stranger; the release is tagged.
**BUILD:** final `ARCHITECTURE.md` refresh (as-built: versions, digests, quotas observed), `docs/runbooks/` index page, close rotation-reminder issues or re-date them, tag `v1.0.0-free`.

**VERIFY:** repo-freshness test — a second LLM (or human) follows Phases 3–8 notes to reproduce staging understanding without asking questions; file the friction found as issues. Then `git tag v1.0.0-free && git push origin v1.0.0-free`.
**DONE WHEN:** [ ] freshness test passed [ ] tag pushed.

---

## Deleted: legacy migration phases (greenfield build — no prior system exists)

Phases 26 (legacy migration + cutover) and 27 (decommission legacy) previously lived here as conditional phases. They are DELETED, not skipped: there is no legacy system, no data to migrate, no cutover, no decommission. Any future reference to legacy migration, `docs/migration/`, `scripts/migrate-legacy/`, or ADR-011 is an error — do not recreate them.

---

## Coverage checklist (phase → master section, for reviewers)

| Master § | Covered in phases |
|---|---|
| §0 rules (incl. -17 no shared code), §30 LLM instructions | §0 of this file (rule 10) + per-phase DO NOT |
| §1 architecture/bounded contexts, §1.1–1.2 | 2 (specs), 14–21 (self-contained services) |
| §2 free envelope, §27 cost, §6 tags | 3, 4, 5, 6, 8, 25 |
| §3 repo layout (no packages/, docs/specs/) | 0 |
| §4 auth model (CLI/OIDC/workload-id + 3 sanctioned exceptions) | 3, 6, 7, 9, 23 |
| §5 Terraform, state backend, modules (LB-single, Cloudflare dns, conditional queue) | 4, 5, 6 |
| §7 DB (budget 7.4a, wallet 7.4b, runner 7.4c, minimigrate 7.5) | 1 (oracle-free), 2 (migrations spec), 10, 14–18, 23 |
| §8 messaging (envelope SPEC 8.1a, OCI Queue canonical, native DLQ, idempotency) | 2 (specs), 5 (queues), 13, 14–18, 24 |
| §9 identity (Keycloak-only, sessions, MFA) | 11, 14, 19, 21 |
| §10 secrets table (10 Vault shells in Phase 5 + queue-client-key in Phase 13 (+1 conditional par-issuer-key)) | 3, 5, 7, 9, 23, 24, 25 |
| §11 K8s (single node, ingress/TLS, Valkey-only 11.6, block budget 11.7) | 6, 8, 12 |
| §12 gateway model | 19 |
| §13 media (+PAR decision) | 11 (ADR deadline), 17 |
| §14 analytics (owns POST /api/v1/beacon) | 18 |
| §15 web/SEO | 20, 21 |
| §16 Docker/images | 14–18 (files), 22 |
| §17–18 CI/CD + Kustomize strategy | 7, 8, 22, 23 |
| §19 observability (OCI-native lightweight) | 5 (alarms), 8, 13, 24 |
| §20 security baseline + §30.1a separate-module standards + §30.1b versions | 0 (versions.md), 2, 4 (lock), 6 (ADR-013), 8 (ADR-015), 11, 19, 21, 22, 23 (dependabot), 25 |
| §21 testing (XE-not-Postgres, per-service helpers) | 1, 2, 13–18, 21, 24 |
| §22 env vars (wallet/VALKEY/OCI-config added, no transport switch var) | 9, 10, 13, 14–18 |
| §23 mapping table | this file (binding) |
| §24 verification framework | 13, 23, 24, 25 (`VALIDATION.md`) |
| §25 runbooks A–E, §26 DR (OCI-native scripts), §31 done | 8, 10, 11, 13, 23, 24, 25 |
| §28 scale | explicitly deferred (8, 27) |
| §29 ADRs (+000, 009–018 new) | 0, 2, 3, 6, 7, 8, 11, 13, 23 |
| §32 references (real URLs) | 3, 4, 6, 8 |

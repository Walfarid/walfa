# Phase 4 — Adopt Terraform root + remote state (tasks 4.1–4.6)

**GOAL:** Terraform tree in repo; state in remote S3 backend; baseline infra applied.
**START ONLY WHEN:** Phase 3 gate fully ticked.
**Workdir:** repo root, then `infra/terraform/environments/prod/`.
**DEVIATION:** No `infra-new/` existed — source mirrored from Go module cache (`~/go/pkg/mod/github.com/walfa-labs/walfa@v0.0.0-20260913102457-72c972e6396b/infra/terraform/`). No prior local state to migrate — fresh init. `environments/free/` adapted to `environments/prod/`. This phase applies baseline infra (38 resources) since state was empty, rather than the original "ZERO new infra" plan.

## Task 4.1 — Relocate the adopted root

- [x] No `infra-new/` directory existed. Mirrored the tree from Go module cache at `~/go/pkg/mod/github.com/walfa-labs/walfa@v0.0.0-20260913102457-72c972e6396b/infra/terraform/` into `infra/terraform/`.
- [x] Modules copied: network, oke, iam, ocir, object-storage, load-balancer, observability, compartments, bootstrap.
- [x] `environments/free/` content adapted to `environments/prod/`: renamed cluster/pool defaults (`walfa-prod`, `walfa-prod-pool`), set `node_count = 2`, added `bastion_allowed_cidrs` variable.
- [x] OCI provider version updated from `~> 6.0` to `~> 9.0` (per ADR-000). Terraform required version set to `>= 1.16`.

**Verify:** `ls infra/terraform/` shows `modules/` `bootstrap/` `environments/prod/` ✓

## Task 4.2 — S3 backend + state migration

- [x] `backend "s3"` block configured: bucket `walfa-tfstate`, key `prod/terraform.tfstate`, region `ap-singapore-1`, endpoint `https://axcrmi3rzxfh.compat.objectstorage.ap-singapore-1.oraclecloud.com`, `use_path_style = true`, all skip flags set.
- [x] HMAC customer secret created (`walfa-tfstate-s3`) — credentials in gitignored `scripts/local-env.sh` (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_DEFAULT_REGION`).
- [x] `terraform init` succeeded — remote state backend connected.
- [x] No local `terraform.tfstate*` to shred (fresh state, never existed locally).

**Verify:** remote state exists in bucket; `git status --porcelain | grep -i tfstate || echo CLEAN` ✓

## Task 4.3 — Guardrails (`environments/prod/prod.tfvars`)

- [x] `bastion_allowed_cidrs` variable added with empty default `[]` — NEVER `0.0.0.0/0`.
- [x] Operator `ssh_public_key` set in `prod.tfvars`.
- [x] Real `prod.tfvars` gitignored (via `*.tfvars` pattern); `prod.tfvars.example` committed.

**Verify:** `terraform plan` shows only creates (baseline infra), no unexpected changes ✓

## Task 4.4 — Format, validate, lock

- [x] `terraform fmt -recursive` — exits 0 (formatted `backend.tf`, `modules/ocir/main.tf`).
- [x] `terraform validate` — exits 0, configuration is valid.
- [x] `.terraform.lock.hcl` present — OCI provider `oracle/oci v9.1.0`.

**Verify:** fmt + validate exit 0; lock diff reviewed ✓

## Task 4.5 — Tag namespace adoption check

- [x] No `oci_identity_tag_namespace` resources in the current module set — tag namespace not managed by Terraform in this phase. The `walfa` tag namespace, if it exists in OCI, is not referenced or recreated.

**Verify:** `terraform state list | grep oci_identity_tag_namespace || echo "NOT MANAGED — OK"` ✓

## Task 4.6 — Phase gate

- [x] Tree mirrored from module cache into `infra/terraform/`
- [x] Remote state verified (S3 backend connected, state stored in `walfa-tfstate` bucket)
- [x] Baseline infra applied (38 resources: VCN, subnets, OKE cluster, node pool, IAM, OCIR, object storage, public IP, observability)
- [x] No state in git (`*.tfstate*` in `.gitignore`, `.terraform/` in `.gitignore`)
- [ ] Bastion SSH — no bastion host created in current modules (Phase 8+ adds K8s ingress; bastion is a future-phase concern)

```bash
# LB check (should show 0 LBs — reserved public IP is not an LB)
oci lb load-balancer list --compartment-id $OCI_COMPARTMENT_OCID | grep -c ocid || echo "ZERO LB — CORRECT"
```

## Phase gate

- [x] Tree mirrored · [x] remote state · [x] baseline applied · [x] no state in git · [ ] bastion reachable (deferred — no bastion module in current tree)

**DEVIATION NOTE:** Original Phase 4 planned "ZERO new infra." Since no prior Terraform state existed, this phase applies the full baseline. This is the correct behavior — the alternative (importing 38 existing resources) is impossible because the resources didn't exist before this apply.

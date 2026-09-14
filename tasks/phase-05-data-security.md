# Phase 5 — Terraform additions (tasks 5.1–5.9). Network/compute already exist.

**GOAL:** add ONLY what is missing (DB, Vault, Queue, DNS, alarms). Verify adopted resources, never duplicate.
**START ONLY WHEN:** Phase 4 applied (remote state, empty plan).
**Workdir:** `walfa/infra/terraform/` (flat root — new `.tf` files alongside adopted ones, no modules/ split).

## Task 5.1 — `database.tf` (new file)

- [ ] ONE Always Free ADB (1 CPU / 20 GB, NO sizing variables), private endpoint, outputs = connection strings + OCID only. No passwords anywhere.

**Verify:** plan shows ONLY the new ADB; `grep -ri "cpu_core_count\|data_storage_size_in_tbs" database.tf || echo "NO TUNABLES"`.

## Task 5.2 — Vault shells (empty, names only)

- [ ] `vault.tf` (new file): Vault + key + 10 empty shells: 5× `db-<svc>-password`, `wallet-password`, `keycloak-admin`, `oidc-client-secret`, `session-secret`, `valkey-password`.
- [ ] No OCIR/Cloudflare shells (GitHub-only by design). No values via tfvars.

**Verify:** `terraform plan` output contains no secret VALUES (names only).

## Task 5.3 — Adopted buckets (lifecycles only, NO new buckets)

- [ ] VERIFY adopted `walfa-media` (`ObjectRead`, versioning ON) + `walfa-tfstate` (holds state — hands off). Add lifecycles ONLY: `tmp/uploads/*` delete after 7d; noncurrent versions purge after 30d.
- [ ] Create `objectstorage.README` with the per-bucket budgets (media ≤15 GB, state ≤1 GB).

**Verify:** plan shows lifecycle changes ONLY (zero bucket creates/replaces).

## Task 5.4 — Adopted OCIR repos (verify, NO new repos)

- [ ] VERIFY 8 adopted repos: `walfa/edge-gateway web-bff identity portfolio publishing media analytics frontend` (note `frontend`, not `web`).
- [ ] Output `<region>.ocir.io/<namespace>/` prefix for Phase 22.

**Verify:** `terraform output` shows the prefix; `oci artifacts container repository list` count = 8.

## Task 5.5 — `dns.tf` (new file, Cloudflare v5)

- [ ] `cloudflare_dns_record` (`app`, `auth`, `tls-test` → ADOPTED reserved IP from `terraform output public_ip_ingress`, `proxied = true`), `zone_id = var.cloudflare_zone_id` (env `CLOUDFLARE_ZONE_ID`).
- [ ] v5 argument names verified against pinned registry docs NOW, recorded in file header (v4 names like `cloudflare_record` DO NOT EXIST in v5).
- [ ] `var.cloudflare_api_token` sensitive, env-fed only.

**Verify:** `grep -ri "oci_dns\|oci_load_balancer" dns.tf || echo "CLEAN"`.

## Task 5.6 — `queue.tf` (new file, REQUIRED, master §8.1)

- [ ] 5 category queues + `walfa-dlq` (visibility 30s, max-delivery 10 → DLQ, retention).
- [ ] Confirm exact `oci_queue_queue` attribute names against provider 9.1.0 registry docs NOW; record in file header. Never guess attribute names.
- [ ] Outputs: queue OCIDs + display names.
- [ ] Re-verify the free tier NOW: record pricing-page/tenancy result in ADR-009 (baseline: first ~1M API calls/month free); confirm the $0 spend alarm (5.7) covers Queue drift.

**Verify:** `oci queue queue list --compartment-id $OCI_COMPARTMENT_OCID | grep -c walfa` → 6; ADR-009 has the re-verification note.

## Task 5.7 — `observability.tf` (extends adopted `logging.tf`)

- [ ] Alarms (adopted log group stays): 5xx, outbox-age placeholder, DB-CPU>80%, memory-pressure, cert-expiry, $0 budget explicitly incl. Queue spend + flow-log ingestion watch.
- [ ] Human confirms the alarm email NOW (test email received).

**Verify:** test email in inbox; topic subscription confirmed.

## Task 5.8 — Forbidden files check (NO LB / network / bastion-service files)

- [ ] No new file creates `oci_load_balancer`, VCN/subnets, or bastion-service resources. The LB is born in Phase 8 from ingress-nginx.

**Verify:** `grep -r "resource \"oci_load_balancer\|resource \"oci_core_vcn\|oci_bastion_bastion" *.tf || echo "CLEAN"`.

## Task 5.9 — Human-reviewed apply + gate

- [ ] Human reads FULL plan (free-class DB? only new-file resources? adopted infra untouched? no secret values?). Apply. Re-plan empty.
- [ ] LB count still ZERO.

```bash
terraform fmt -check -recursive && terraform validate
oci lb load-balancer list --compartment-id $OCI_COMPARTMENT_OCID | grep -c ocid || echo "ZERO LB — CORRECT"
```

## Phase gate

- [ ] ADB + private endpoint · [ ] 10 empty shells · [ ] lifecycles on adopted buckets · [ ] adopted repos/IP verified · [ ] 3 DNS records on reserved IP · [ ] 6 queues · [ ] Queue free tier re-verified + recorded in ADR-009 · [ ] alarms confirmed

**DO NOT:** put secret values in tfvars, add DB sizing vars, recreate adopted resources, or create the LB.

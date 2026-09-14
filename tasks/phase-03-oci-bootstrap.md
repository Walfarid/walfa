# Phase 3 — OCI account + operator bootstrap (tasks 3.1–3.8). Human-led.

**GOAL:** tenancy ready for Terraform; irreversible choices made deliberately.
**START ONLY WHEN:** Phase 2 gate fully ticked. Human present (browser, domain DNS).
**NOTE:** Adjusted for fresh build — adopted infra did not exist (all clusters DELETED). Created new compartment `walfa-build` instead of adopting.

## Task 3.1 — OCI CLI auth

- [x] OCI CLI already installed and authenticated (session token in `~/.oci/config`).
- [x] `oci iam region-subscription list` shows home region `ap-singapore-1`.

**Verify:** `oci iam region-subscription list --query 'data[?"is-home-region"]|[0]."region-name"' --raw-output` → `ap-singapore-1` ✓

## Task 3.2 — Home region (DECIDED: ap-singapore-1)

- [x] Recorded `ap-singapore-1` in ADR-012 with verification output.

**Verify:** ADR-012 exists at `docs/adr/ADR-012-home-region-compartment.md` ✓

## Task 3.3 — Compartment (CREATED: walfa-build)

- [x] Adopted compartments (`walfa.7esXGDUj`, `walfa-prod.*`) had all clusters DELETED, no VCNs, no buckets. Created new `walfa-build` compartment.
- [x] OCID `ocid1.compartment.oc1..aaaaaaaantbf7aqdtzvkjtsa3l2pgyjanqlvuw7j25al2swjslnzikcj2l7q` saved as `OCI_COMPARTMENT_OCID` in gitignored `scripts/local-env.sh`.

**Verify:** `git check-ignore scripts/local-env.sh` → prints path ✓ · `oci iam compartment get` → ACTIVE ✓

## Task 3.4 — Quota reality check

- [x] A1 OCPUs (AD): 250 available (need 4) ✓
- [x] A1 Memory (GB, AD): 1666 available (need 24) ✓
- [x] Always Free ADB: 2 available (need 1) ✓
- [x] Block storage: 200 GB free (need ~157) ✓

**Verify:** quotas recorded in ADR-012 ✓

## Task 3.5 — Terraform state bucket

- [x] Created `walfa-tfstate` with versioning `Enabled` in namespace `axcrmi3rzxfh`.

**Verify:** `oci os bucket get` → versioning: Enabled ✓

## Task 3.6 — Cloudflare zone + token (ADR-017)

- [x] Zone `walfa.my.id` already active on Cloudflare (Free plan).
- [x] NS verified: `mack.ns.cloudflare.com`, `paityn.ns.cloudflare.com` ✓
- [x] Zone ID `fb752569583dce974207ea9775dee126` saved to `scripts/local-env.sh`.
- [x] SSL mode set to `strict` (Full (strict)) via Cloudflare API ✓
- [ ] **PENDING:** `CLOUDFLARE_API_TOKEN` — human must create in Cloudflare dashboard (Zone:DNS:Edit + Zone:Zone:Read on `walfa.my.id` only). Instructions in ADR-017.

**Verify:** NS check via `cloudflare-dns.com` DNS-over-HTTPS → cloudflare nameservers ✓

## Task 3.7 — Vault + LB availability

- [x] `oci vault secret list` on new compartment responds (0 secrets — expected) ✓
- [x] LB service available (0 LBs — expected, LB arrives Phase 8)

**Verify:** both API calls respond without error ✓

## Task 3.8 — Phase gate

- [x] Region recorded in ADR-012
- [x] Compartment OCID + zone ID in gitignored local-env.sh
- [x] Quotas sufficient (massive margin on all resources)
- [x] State bucket versioned
- [x] Cloudflare NS verified, SSL set to strict
- [ ] `CLOUDFLARE_API_TOKEN` value pending (human manual step)

## Phase gate

All of 3.8 ticked except API token value (documented, instructions in ADR-017).

**DO NOT:** create a second compartment/region/cluster. Fresh resources are created in subsequent phases via Terraform.

# ADR-012 — Home region and compartment

**Status:** Accepted
**Date:** 2026-09-14
**Deciders:** platform-team

## Context
WALFA is a greenfield build on OCI Always Free. Home region must be decided and frozen before any provisioning begins — worker image OCIDs, all state, and all regional resources are coupled to it.

## Decision
- **Home region:** `ap-singapore-1`
- **Compartment:** `walfa-build` (fresh, created 2026-09-14)
- **Tenancy:** `ocid1.tenancy.oc1..aaaaaaaanqcah6dmgrdft7uduh2kmikqsi6fybhdq2derldpxbkupk4y4sga`
- **Compartment OCID:** `ocid1.compartment.oc1..aaaaaaaantbf7aqdtzvkjtsa3l2pgyjanqlvuw7j25al2swjslnzikcj2l7q`

## Verification (2026-09-14)

```
$ oci iam region-subscription list | grep home
  "region-name": "ap-singapore-1",
  "is-home-region": true,
```

## Quota confirmation

| Resource | Available | Required | Status |
|---|---:|---:|---|
| A1 OCPUs (AD) | 250 | 4 | OK |
| A1 Memory (GB, AD) | 1666 | 24 | OK |
| Always Free ADB | 2 | 1 | OK |
| Block storage (GB) | 200 | ~157 | OK |

## Consequences
Region is frozen. All Terraform, all image lookups, all state references use `ap-singapore-1`. The previous `infra-new/` compartments (`walfa-prod.*`, `walfa.7esXGDUj`) had all clusters deleted — the new `walfa-build` compartment is a clean slate.

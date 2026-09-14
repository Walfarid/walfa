# ADR-017 — Cloudflare is canonical DNS provider

**Status:** Accepted
**Date:** 2026-09-14
**Deciders:** platform-team

## Context
Standardizes on Cloudflare. Removes OCI DNS zones from scope. DDoS-absorbing proxied records in front of free LB. API surface for cert-manager ACME DNS-01 (works through proxying).

## Decision
Cloudflare canonical. Terraform manages records via provider v5 (~>5.0). Zone/account human-created, never Terraform-managed. Least-privilege API token (Zone:DNS:Edit + Zone:Zone:Read on one zone).

## Verified (2026-09-14)

- **Zone:** `walfa.my.id` (active, Free plan)
- **Zone ID:** `fb752569583dce974207ea9775dee126`
- **Account:** Walfa (`e0ae9812eb957f3c10890411396d2123`)
- **Nameservers:** `mack.ns.cloudflare.com`, `paityn.ns.cloudflare.com`
- **Registrar:** pt web media technology indone (id: 1)
- **Original nameservers (pre-Cloudflare):** ns1.dns-parking.com, ns2.dns-parking.com
- **SSL mode:** Must be set to Full (strict) — TODO: verify in Cloudflare dashboard

## Token status

API token (`CLOUDFLARE_API_TOKEN`) must be created manually in Cloudflare dashboard:
1. Cloudflare dashboard → My Profile → API Tokens
2. "Create Token" → "Edit zone DNS" template
3. Permissions: `Zone:DNS:Edit` + `Zone:Zone:Read`
4. Zone Resources: Include → Specific zone → `walfa.my.id`
5. Save token value to `scripts/local-env.sh` as `CLOUDFLARE_API_TOKEN`

## Consequences
One extra token to rotate (90 days). SSL mode Full (strict). Optional origin-range lockdown as periodic maintenance. No OCI DNS zones.

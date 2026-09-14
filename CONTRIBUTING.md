# Contributing to WALFA

## Phase discipline

- Phases execute in **strict numeric order**. A phase may start only when the previous phase's DONE WHEN checklist is fully true.
- One phase = one pull request. Branch name: `phase-N-short-name`.
- Merge only after VERIFY passes. Keep `main` green at all times.

## Secret rules

Never commit secrets. The `.gitignore` excludes: `*.tfvars`, `*.tfstate*`, `.terraform/`, `*.pem`, `*.key`, `*.sso`, `*.p12`, `cwallet.sso`, `ewallet.p12`, `tnsnames.ora`, `sqlnet.ora`, `.env`, `.env.*`.

Before every commit, run `git status` and `git diff --cached --name-only`; if you see a password, token, wallet file, private key, or `terraform.tfvars` with real values — stop, remove, rotate if it ever left the machine.

## No cross-import law

No Go file under `services/<a>/` may import `walfa/services/<b>`. No shared first-party packages exist. Third-party libraries (chi, go-ora, valkey-go, oci-go-sdk, go-oidc) are fine. CI enforces this with the `no-cross-import` job.

## Local development

```bash
task dev-up      # starts Oracle (1521), Valkey (6379), Keycloak (8080)
task dev-down    # stops and removes volumes
task dev-logs    # follows container logs
```

Dev passwords are NOT secrets and must **never** be reused in production.

## Queue testing strategy

No local queue emulator exists (OCI Queue has none). Unit and integration tests use each service's **own** in-memory fake of the Queue client. The real tenancy Queue is proven in Phase 13 (selftest) and Phase 24 (e2e + chaos).

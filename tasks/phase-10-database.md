# Phase 10 — Database init (tasks 10.1–10.7)

**GOAL:** five isolated schemas + wallet connectivity + canonical migrate-Job pattern.
**START ONLY WHEN:** Phase 9 done.

## Task 10.1 — Six users via bastion-host tunnel (ONLY interactive ADMIN use)

- [ ] Tunnel via the adopted host: `ssh -L 1522:<db-endpoint>:1522 -i <key> opc@$(terraform output -raw bastion_public_ip)` (or `terraform output ssh_to_bastion`); then `sqlplus admin/<pw>@localhost:1522/<service>`.
- [ ] Create `ID_SVC PORTFOLIO_SVC PUBLISHING_SVC MEDIA_SVC ANALYTICS_SVC KEYCLOAK` via committed script with `&1` substitution vars (passwords via bind vars, never in files).
- [ ] Each: `DEFAULT TABLESPACE DATA`, quota 3 GB (6×3=18 of 20 GB — tight by design), `CREATE SESSION` + own-schema objects ONLY. No DBA.
- [ ] Afterwards ADMIN password lives in Vault, break-glass only.

**Verify:** `SELECT grantee, privilege FROM DBA_TAB_PRIVS WHERE grantee IN (...)` shows zero cross-schema grants.

## Task 10.2 — Wallet distribution

- [ ] Download wallet over the tunnel → split into `oracle-wallet` K8s Secret + full ZIP into Vault backup.
- [ ] `tnsnames.ora`: services use `<dbname>_low`.

**Verify:** debug pod mounts `/wallet`, `TNS_ADMIN=/wallet`, connects via `_low` alias.

## Task 10.3 — Baseline migrations, proven via sqlplus (no binary exists yet)

- [ ] `db/migrations/<service>/000001_init.up.sql` (+ `.down.sql` for local teardown) each: own tables + `event_outbox` (master §8.2 DDL verbatim) + justified indexes, in `docs/specs/migrations.md` format. No goose (no Oracle dialect), no PL/SQL (grep gate green).
- [ ] Apply each with `sqlplus <svc>/<pw>@localhost:1521/FREEPDB1 @000001_init.up.sql` on local oracle-free → clean; verify objects; tear down with `.down.sql`.
- [ ] CI job SHAPE defined (full wiring Phase 23): forbidden-keyword grep + double-apply no-op on disposable oracle-free.

**Verify:** 5/5 apply clean + 5/5 teardown clean; `grep -rEi "^\s*(BEGIN|DECLARE|CREATE +(OR REPLACE +)?(TRIGGER|PROCEDURE|PACKAGE))" db/migrations/ || echo "NO PLSQL"`.

## Task 10.4 — Migrate-Job manifests (write now, FIRST RUN in Phase 14)

- [ ] `infra/kubernetes/base/jobs/migrate-identity.yaml`: service image, `args: ["migrate","up"]`, `restartPolicy: Never`, `activeDeadlineSeconds: 300`, Vault-synced env. Render + dry-run clean. DO NOT APPLY: no image exists yet.
- [ ] Each binary will implement `migrate` itself (OWN local migrator + embedded SQL). No shared migrator, no third-party tool.

**Verify:** `kubectl apply --dry-run=client -f infra/kubernetes/base/jobs/migrate-identity.yaml` exits 0; `kubectl -n apps get job migrate-identity 2>&1 | grep -i notfound` (proves it was NOT run).

## Task 10.5 — Connection budget defaults

- [ ] `DB_MAX_OPEN_CONNS` defaults per master §7.4a in every Job/Deployment template (total ≤40).

**Verify:** sum of defaults + keycloak pool ≤ 32 (headroom kept).

## Task 10.6 — Backup proof + DR runbook start

- [ ] ADB auto-backups ON verified (`oci db autonomous-database get` retention).
- [ ] `docs/runbooks/disaster-recovery.md`: restore-point procedure (auto-backups + wallet-in-Vault; `restore-db.sh` wraps OCI APIs, never `expdp`).

**Verify:** retention output pasted into the runbook.

## Task 10.7 — Phase gate (isolation proof)

```bash
echo "SELECT COUNT(*) FROM ID_SVC.event_outbox;" | sqlplus portfolio_svc/<pw>@<tns>  # must ERROR ORA-00942
```

## Phase gate

- [ ] 6 users, quotas, zero cross-grants · [ ] wallet connects · [ ] 5 baselines apply via sqlplus · [ ] Job manifests dry-run clean, NOT executed · [ ] budget defaults · [ ] DR runbook started

**DO NOT:** execute migrate-Jobs before their image exists, run Jobs in parallel ever, grant DBA, commit passwords, or run down-migrations anywhere but local oracle-free.

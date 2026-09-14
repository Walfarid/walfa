# Migration Contract (Frozen Spec v1)

Each WALFA service implements its own minimal migrator. No third-party tool (goose and golang-migrate have no Oracle dialect).

## File format

Pairs: `NNNN_name.up.sql` / `NNNN_name.down.sql` (NNNN = zero-padded sequential integer, e.g. `000001_init`).

- `.up.sql`: plain Oracle DDL/DML only. One statement per `;`-at-line-end.
- `.down.sql`: exists for local dev/test teardown ONLY. Never runs in production.

## Forbidden constructs (CI grep gate)

Migration files must NOT contain: `BEGIN`, `DECLARE`, `CREATE TRIGGER`, `CREATE PROCEDURE`, `CREATE PACKAGE`. These would break the simple `;`-at-line-end splitter.

## Version tracking

Table `schema_version`:

```sql
CREATE TABLE schema_version (
    version NUMBER PRIMARY KEY,
    name VARCHAR2(256) NOT NULL,
    applied_at TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    checksum VARCHAR2(64) NOT NULL
);
```

Each applied file records its version (the NNNN integer), name, timestamp, and SHA256 checksum of the file content. Editing an applied migration fails loudly (checksum mismatch).

## Semantics

- `up`: apply all pending files in order. Second run = no-op (all files already applied).
- `status`: list applied/pending files with versions.
- `down`: local-only teardown. Refuses if `APP_ENV=production`.

## Rules

1. Every schema change is committed to source control.
2. Never edit an applied file — ship a new one.
3. Destructive changes use expand/migrate/contract pattern.
4. Application code remains compatible during rolling deployment.
5. CI applies migrations twice against disposable `oracle-free` (second run must be no-op).

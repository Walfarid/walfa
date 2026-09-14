# Phase 25 + 25b — Hardening, DR, cost audit, handoff (tasks 25.1–25.7)

**GOAL:** attacked, restored, audited — then production. Final phase. No Phase 26 exists.
**START ONLY WHEN:** Phase 24 validation pack merged.

## Task 25.1 — Security sweep + assert script

- [ ] `trivy` rescan: zero CRITICAL. `govulncheck` per module + `npm audit`: clean or dated waivers.
- [ ] `gitleaks` full history. Dependency updates merged (Go, npm, actions, manifest pins).
- [ ] `scripts/assert-podsecurity.sh` (committed): read-only FS, non-root, no privileged, dropped caps — queried live.

**Verify:** `scripts/assert-podsecurity.sh` exit 0; reports attached.

## Task 25.2 — Renewal/rotation proofs

- [ ] Force staging re-issue via `tls-test` canary (cert-manager).
- [ ] Rotate ONE non-DB secret end-to-end via rotation runbook.
- [ ] Rotate OCIR + Cloudflare tokens if >60 days old.

**Verify:** new cert READY True; rotation log pasted.

## Task 25.3 — DR rehearsal (record RTO/RPO numbers, not TBD)

- [ ] (a) Terraform recreate `plan` from empty state into scratch — do NOT touch prod.
- [ ] (b) ADB point-in-time restore walked to "ready to restore" (screenshots/transcript).
- [ ] (c) Realm re-import from git onto scratch namespace.
- [ ] (d) Outbox replay against Queue (backlog fixture drains; DLQ inspected, empty).
- [ ] Numbers → `docs/runbooks/disaster-recovery.md` (replace aspirations).

**Verify:** four timings in the runbook.

## Task 25.4 — Cost/quota audit ($0 with evidence)

- [ ] Re-run Phase 3 quota queries; A1 flexible instance 4 OCPU / 24 GB fully used; block storage ~157 / 200 GB; LB count = 1; object bytes vs budgets; spend $0 + budget alarm armed.
- [ ] ANY deviation → STOP + ADR.

**Verify:** evidence pasted; `oci lb load-balancer list | grep -c ACTIVE` → 1.

## Task 25.5 — Runbook final pass

- [ ] Every runbook (A–E + rollback + recovery + rotation + cluster-access) re-run verbatim, in order, by the LLM.

**Verify:** each runbook's commands executed with outputs sane.

## Task 25.6 — 25b handoff + tag

- [ ] `ARCHITECTURE.md` as-built refresh (versions, digests, quotas). `docs/runbooks/` index. Rotation issues closed/re-dated.
- [ ] Freshness test: second LLM/human follows Phases 3–8 cold; friction filed as issues.
- [ ] `git tag v1.0.0-free && git push origin v1.0.0-free`.

**Verify:** tag exists on remote; freshness issues filed (or explicit none-found note).

## Task 25.7 — Phase gate (human sign-off)

- [ ] Human initials `VALIDATION.md` + every master §31 bullet.

## Phase gate

- [ ] Scans clean · [ ] DR numbered · [ ] $0 proven · [ ] runbooks executable · [ ] §31 signed · [ ] as-built merged · [ ] tag pushed

**DO NOT:** skip DR, accept undated waivers, chaos prod data without a restore point, or start `scale/` (new project, master §28).

# Phase 22 — Docker multi-arch + OCIR (tasks 22.1–22.5)

**GOAL:** 8 pinned, scanned, SBOM'd ARM64+AMD64 images.
**START ONLY WHEN:** Phase 21 done (all Dockerfiles exist).

## Task 22.1 — Harden all 8 Dockerfiles

- [ ] Per service + frontend (OCIR repo is `walfa/frontend`): multi-stage, `CGO_ENABLED=0`, non-root `USER 65532`, read-only FS + writable `TMPDIR`, `ARG GIT_SHA/VERSION` baked in, `.dockerignore` excluding `.git *.md db/seeds wallet files`.

**Verify:** checklist per Dockerfile (8 ticks, one per file).

## Task 22.2 — ARM64 RUN proof (builds ≠ proof)

- [ ] Per image: `docker buildx build --platform linux/arm64 -t walfa/<svc>:test --load .` then `docker run --rm walfa/<svc>:test ./app --help` shows `serve|migrate` + version. QEMU-slow is fine.

**Verify:** 8 run outputs saved (paste into PR).

## Task 22.3 — Push + SBOM + scan

- [ ] Push BOTH tags (`sha-<git-sha>` immutable + `release-<version>`), `--sbom=true --provenance=true`, SBOM alongside.
- [ ] `trivy`/`grype`: CRITICAL = fail; HIGH = human waiver with expiry or fail. (Bootstrap pushes from laptop logged; CI takes over in Phase 23.)

**Verify:** scan reports attached; zero unwaived CRITICAL/HIGH.

## Task 22.4 — Digest pins in overlay

- [ ] `infra/kubernetes/overlays/prod/`: `image: <ocir>/<svc>@sha256:<digest>` for all 8. No `:latest`, no moving tags.

**Verify:**
```bash
docker buildx imagetools inspect <each digest>   # all 8 resolve
grep -r ":latest" infra/ Dockerfile* services/*/Dockerfile apps/web/Dockerfile* || echo CLEAN
```

## Task 22.5 — Phase gate

- [ ] 8 digests resolve · [ ] SBOM+provenance present · [ ] scans enforced · [ ] no `latest`.

## Phase gate

All of 22.5 ticked.

**DO NOT:** push routinely from laptops after this, or bake secrets into layers (`dive` if unsure).

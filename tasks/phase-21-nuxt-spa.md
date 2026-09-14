# Phase 21 — Nuxt SPA (tasks 21.0–21.5)

**GOAL:** complete, accessible, SEO-correct UI talking ONLY to the gateway.
**START ONLY WHEN:** Phase 20 done. **Workdir:** `walfa/apps/web/` (Nuxt 4 exact + lockfile, Node 24 LTS + `.nvmrc`, SPA mode (ssr:false, static, gateway-only), app code under `app/`).

## Task 21.0 — Versions first (Nuxt 3 is EOL — forbidden)

- [ ] `package.json`: `nuxt` exact `4.5.2` (per versions table); lockfile committed; `.nvmrc` = Node 24 LTS; `node --version` + `npm --version` satisfy Nuxt `engines`.
- [ ] No `nuxt@3`, no `^3`, no unpinned deps in `dependencies`.

**Verify:** `npm ls nuxt` shows single 4.5.2; `cat .nvmrc` → `24`; `node --version` → v24.x.

## Task 21.1 — Routes + states

- [ ] Home, portfolio, articles, guides, media views, login/logout callbacks, account/purge settings, 404/500/offline pages.

**Verify:** `npm run dev` serves all routes without console errors.

## Task 21.2 — Auth (no localStorage tokens, ever)

- [ ] Keycloak authorization-code flow; tokens in HttpOnly SameSite cookies via gateway session.
- [ ] Mutations to owning services through gateway; public pages via web-bff SSR.

**Verify:** login→logout cycle works; Application tab shows zero tokens (assert via test).

## Task 21.3 — Meta/SEO/a11y baseline

- [ ] Per-route meta/OG/canonical; sitemap wiring; axe-clean; keyboard navigation + focus states.

**Verify:** `npx axe` (or equivalent) clean on top routes.

## Task 21.4 — Playwright E2E suite

- [ ] `apps/web/tests/e2e/`: login, logout, session-expiry, portfolio CRUD UI, publish flow, media upload, beacon fires, purge flow, rate-limit banner, offline/error states.

**Verify:** `npx playwright test` fully green.

## Task 21.5 — Phase gate (bars + isolation)

```bash
npm run lint && npm run typecheck && npm run test && npx playwright test
grep -rn "fetch(" --include="*.ts" --include="*.vue" src/ | grep -v "$GATEWAY_HOST" || echo "GATEWAY ONLY"
```

- [ ] Lighthouse (throttled): Perf ≥80, A11y ≥95, SEO 100 on public routes.

## Phase gate

- [ ] E2E green · [ ] gateway-only traffic · [ ] no localStorage tokens · [ ] bars met

**DO NOT:** call OCI Queue/Valkey/DB from frontend, embed secrets in public config, or bypass the gateway.

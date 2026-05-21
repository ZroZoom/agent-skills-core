# Overlay: next-vercel

Stack-specific skills for projects built on **Next.js (App Router) + Vercel + Supabase (`@supabase/ssr`)**.

The base `.agent/skills/` are stack-agnostic (they were extracted from a Vite + React + Netlify codebase). This overlay adds or overrides the parts that differ on a Next.js / Vercel stack so you don't have to relearn them per project.

## What's inside

| Overlay skill | Relationship to base | Purpose |
|---|---|---|
| `frontend-next` | **companion** to base `frontend-system` | App Router patterns: Server vs Client Components, Server Actions, `next/image`, metadata, `next-intl`, client islands for heavy viz. |
| `supabase-ssr-next` | **companion** to base `supabase-admin` | `@supabase/ssr` cookie sessions: middleware refresh, server/client/route-handler clients, auth flows, guest mode. |
| `deploy-vercel` | **overrides** base `/deploy` command's hosting assumptions | Vercel deploy workflow: preview deploys per PR, env var scopes, Edge vs Node runtime, build/output settings. |
| `cost-check-vercel` | **overrides** base `cost-check`'s Netlify/SSL assumptions | Vercel cost model: bandwidth, function invocations, fluid compute, ISR/image-optimization units. |

The base skills stay generic. The overlay skills carry the same trigger phrases plus Next/Vercel-specific ones, so when both are active the model picks the stack-specific one for stack-specific work.

## How to activate

Copy the overlay skill directories into `.agent/skills/` so they register as active skills:

```bash
scripts/enable-overlay.sh next-vercel
```

This copies each `<skill>/SKILL.md` from `.agent/overlays/next-vercel/` into `.agent/skills/`. It is idempotent and refuses to clobber an existing skill of the same name unless you pass `--force`. After enabling, run your placeholder fill:

```bash
python3 scripts/fill-placeholders.py --interactive
```

To deactivate, delete the copied skill directories from `.agent/skills/` (the overlay source under `.agent/overlays/next-vercel/` is untouched).

> **Why copy, not symlink?** Some agent runtimes resolve skills by scanning real files under `.agent/skills/`. Copies are portable across Windows / WSL / macOS and survive `git archive`. The trade-off is that overlay updates must be re-applied — re-run `enable-overlay.sh --force` after pulling overlay changes.

## Placeholders this overlay adds

Add these to `.agent/context/project-ids.md` (the activation step and `fill-placeholders.py` know them):

| Placeholder | Meaning |
|---|---|
| `<VERCEL_PROJECT>` | Vercel project name (e.g. `fajnaszkola`) |
| `<VERCEL_ORG>` | Vercel team / org slug |
| `<VERCEL_PRODUCTION_URL>` | Production URL (e.g. `https://fajnaszkola.pl`) |

`<OWNER>/<REPO>`, `<SUPABASE_PROJECT_REF>`, and `<DOMAIN_PRIMARY>` are shared with the base template.

## Relationship to project specs

This overlay is the **operational layer** (how the agent works on the repo). It is intentionally separate from product architecture decisions (monorepo vs standalone, which `@zrozoom/*` packages to consume, etc.) — those belong in the project's own `docs/`. Per the Fajna Szkoła ADR-012, an overlay skill is repo tooling, **not** product code: do not import `.agent/` content into the Next.js app bundle.

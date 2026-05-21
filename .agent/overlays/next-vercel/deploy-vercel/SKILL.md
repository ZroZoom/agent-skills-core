---
name: deploy-vercel
description: "Vercel deployment workflow for Next.js (overrides the base /deploy command's hosting assumptions). Use for preview deploys per PR, environment variable scopes, Edge vs Node runtime, build settings, and production promotion. Triggers: vercel deploy, preview deployment, vercel env, edge runtime, promote to production, vercel.json, deploy Next.js."
---

# Deploy (Vercel)

Overrides the hosting-specific parts of the base `/deploy` command and `reporting-ops` demo/deploy checks for projects on Vercel. Release prep, version bumping, and changelog steps from the base flow still apply.

## Deploy model

- **Every PR gets a Preview Deployment** automatically (Vercel Git integration). Use the preview URL for QA and demo-readiness instead of a local build where possible.
- **Production deploys on merge to the production branch** (usually `main`). Do not deploy to production manually unless rolling back.
- **Promotion**: a preview can be promoted to production from the dashboard or `vercel promote <deployment-url>` — prefer merge-driven production deploys; reserve promotion for hotfix rollbacks.

## Environment variables

- Three scopes: **Production**, **Preview**, **Development**. Set each deliberately — a Preview pointing at the production Supabase project is a common, dangerous mistake.
- `NEXT_PUBLIC_*` vars are inlined into the client bundle at build time — only non-secret values. Secrets (`SUPABASE_SERVICE_ROLE_KEY`) are server-only env, never `NEXT_PUBLIC_*`.
- Pull envs locally with `vercel env pull .env.local` (gitignored). Never commit `.env*`.
- Changing an env var does **not** redeploy — trigger a new deploy for it to take effect.

## Runtime: Edge vs Node

- **Node runtime** (default) for most routes: full Node APIs, Supabase server client, larger deps.
- **Edge runtime** (`export const runtime = "edge"`) only for lightweight, latency-sensitive routes. Edge has no full Node API and a smaller package surface — verify `@supabase/ssr` and any deps run on Edge before choosing it.
- Don't default to Edge "for speed" — the Node runtime is the safe choice; opt into Edge per-route with a reason.

## Build & output

- Build command `next build`; framework preset auto-detected. Override in `vercel.json` only when necessary.
- `generateStaticParams` + ISR (`revalidate`) for content routes keeps build fast and serves static where possible.
- Watch the build log for the route table: confirm static (`○`/`●`) vs dynamic (`ƒ`) matches intent — an accidentally-dynamic lesson route hurts perf and cost.
- Keep `next build` warning-free on RSC boundaries; a Preview that builds is the gate.

## Domains

- Add `<VERCEL_PRODUCTION_URL>` domain in the Vercel project; point DNS per Vercel's instructions (A/CNAME). SSL is automatic (managed certs) — no manual cert renewal (unlike the base `cost-check` Netlify/`openssl` flow).
- Trilingual routes live under one domain via `app/[locale]/...`; no separate domain per language.

## Verification / post-deploy

- After production deploy: smoke-test the golden path on `<VERCEL_PRODUCTION_URL>` per the PR test plan.
- Check the Vercel deployment status (dashboard or `vercel ls`) shows `Ready`, not `Error`/`Building`.
- Confirm no preview-scoped secrets leaked to production and vice versa.
- Watch Core Web Vitals (Vercel Speed Insights) against the spec targets: LCP < 2.5s p75 mobile, INP < 200ms.

## Rollback

- `vercel rollback` (or promote a known-good previous production deployment from the dashboard). Faster than reverting + rebuilding for an urgent prod break — revert the commit afterward to keep `main` correct.

## Placeholders

`<VERCEL_PROJECT>`, `<VERCEL_ORG>`, `<VERCEL_PRODUCTION_URL>`, `<OWNER>/<REPO>`. See `.agent/context/project-ids.md`.

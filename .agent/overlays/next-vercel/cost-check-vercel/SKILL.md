---
name: cost-check-vercel
description: "Vercel cost and usage audit for Next.js (overrides the base cost-check Netlify/SSL assumptions). Use to audit bandwidth, function invocations/duration, fluid compute, ISR and image-optimization usage, and plan limits. Triggers: vercel cost, vercel usage, bandwidth, function invocations, image optimization cost, vercel plan limit, infra cost Next.js."
---

# Cost & Usage (Vercel)

Overrides the hosting-cost portion of the base `cost-check` / `reporting-ops` cost mode for projects on Vercel. The Supabase, domain-registrar, and API-cost (LLM rate-limit) portions of the base skill still apply unchanged. The big difference from the Netlify base: **Vercel has no managed-cert `openssl` expiry step** (certs are auto-managed) and the metered dimensions are different.

## What Vercel meters

| Dimension | What drives it | Watch for |
|---|---|---|
| **Fast Data Transfer (bandwidth)** | bytes served to clients | large unoptimized assets, no caching, hot static files |
| **Function invocations** | each Server Component data path, Route Handler, Server Action, middleware run | middleware running on every asset request (tighten the `matcher`) |
| **Function duration / compute** | CPU·time of server execution (fluid compute) | slow data fetches, missing ISR, N+1 Supabase queries |
| **Edge requests** | middleware + Edge routes | broad middleware matcher is the #1 surprise cost |
| **Image Optimization** | unique source images × transformations | per-request `next/image` on many distinct remote images |
| **ISR writes / reads** | revalidations + cache reads | very short `revalidate` windows on high-traffic routes |

## Audit workflow (read-only)

1. **Usage dashboard** — Vercel project → Usage. Note current-period bandwidth, invocations, compute, image optimizations vs the plan included amounts. Record the billing period and exact numbers (don't estimate).
2. **Middleware blast radius** — read `middleware.ts` `config.matcher`. A matcher that catches static assets multiplies Edge requests. Confirm it excludes `_next/static`, `_next/image`, and image extensions.

   ```bash
   rg -n "matcher" middleware.ts
   ```

3. **Dynamic vs static routes** — from the last `next build` route table, count `ƒ` (dynamic) routes that should be `●` (ISR) or `○` (static). Each needless dynamic route is per-request compute. Content/lesson routes should be static/ISR.
4. **Image optimization** — count distinct remote image hosts and high-cardinality galleries:

   ```bash
   rg -n "next/image|<Image" src | wc -l
   rg -n "remotePatterns" next.config.*
   ```

   High distinct-image counts × traffic = image-optimization cost. Pre-size assets or use `unoptimized` for already-optimized CDN images.
5. **Supabase / domains / API** — defer to base `cost-check`: Supabase plan & quota, registrar WHOIS expiry, LLM rate-limit presence. (Vercel SSL is auto-managed — skip the `openssl s_client` cert-expiry step from the base flow.)

## Report shape

```markdown
## Cost check (Vercel)

**Checked at:** YYYY-MM-DD HH:mm Europe/Warsaw
**Billing period:** YYYY-MM-DD – YYYY-MM-DD
**Verdict:** ok / watch / action needed

### Vercel usage vs plan
| Dimension | Used | Included | % |
|---|---|---|---|
| Bandwidth | ... | ... | ... |
| Invocations | ... | ... | ... |
| Compute | ... | ... | ... |
| Image opt | ... | ... | ... |

### Top cost drivers
- ...

### Supabase / domains / API
- (per base cost-check)

### Recommendations
- ...
```

## Thresholds

- Treat >80% of any included dimension mid-period as `watch`, >100% (overage) as `action needed`.
- A middleware matcher catching static assets is `action needed` regardless of current spend — it scales badly.

## Rules

- Read-only. Never change the Vercel plan, delete deployments, or alter env without explicit approval.
- Never print tokens, billing card details, or `SUPABASE_SERVICE_ROLE_KEY`.
- Report exact usage numbers and the billing period; do not estimate or extrapolate silently.

## Placeholders

`<VERCEL_PROJECT>`, `<VERCEL_ORG>`, `<SUPABASE_PROJECT_REF>`, `<DOMAIN_PRIMARY>`. See `.agent/context/project-ids.md`.

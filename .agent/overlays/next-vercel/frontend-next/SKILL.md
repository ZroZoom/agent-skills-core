---
name: frontend-next
description: "Next.js App Router UI/UX patterns (companion to frontend-system). Use for Server vs Client Components, Server Actions, data fetching, metadata/SEO, next/image, next-intl, and wrapping heavy client-only libraries as islands. Triggers: Next.js component, App Router, RSC, server action, use client, generateMetadata, next-intl, client island, Mafs/3D viewer in Next."
---

# Frontend (Next.js App Router)

Companion to the base `frontend-system` skill. The base covers generic UI/UX, Tailwind, accessibility, and component structure — all still apply. This file covers what is specific to Next.js App Router. When the two conflict on a Next.js project, this file wins.

## Server vs Client Components

- **Default to Server Components.** No `"use client"` unless the component needs state, effects, browser APIs, or event handlers.
- Add `"use client"` at the **leaf**, not the page. Push interactivity down so most of the tree stays server-rendered.
- Server Components can be `async` and `await` data directly — no `useEffect` + fetch. Pass plain data down to client children.
- A client component cannot import a server component as a child by value, but **can** receive one via `children`/props (the "client island wrapping server content" pattern).

## Client islands for heavy/browser-only libraries

Math/3D/chemistry viewers (Mafs, `@react-three/fiber`, 3dmol) are browser-only and heavy. Load them as islands:

```tsx
import dynamic from "next/dynamic";

const MoleculeViewer = dynamic(() => import("./MoleculeViewer"), {
  ssr: false,
  loading: () => <ViewerSkeleton />,
});
```

> **Next.js 15+**: `dynamic(..., { ssr: false })` is rejected when called from a Server Component. Put this `dynamic()` call inside a `"use client"` wrapper component and render that from the server page.

- `ssr: false` keeps them out of the server bundle and avoids hydration mismatches.
- Keep the island's data contract serializable (per `@zrozoom/ui-components` adapter types if the project consumes them).
- Lazy-load below the fold; render a skeleton sized to avoid layout shift (CLS).

## Data fetching

- Fetch in Server Components with `await`. Co-locate the fetch with the component that needs it.
- Control caching explicitly: `fetch(url, { next: { revalidate: 3600 } })` for ISR-style revalidation, `{ cache: "no-store" }` for always-fresh.
- For static content routes (lessons), prefer `generateStaticParams` + SSG/ISR over runtime fetching. Manifest-driven params keep build deterministic.

```tsx
export async function generateStaticParams() {
  return getStaticLessonParams(); // from your content registry
}
export const revalidate = 3600; // ISR window
```

## Server Actions (mutations)

- Use Server Actions for form/mutation flows instead of hand-rolled API routes when the caller is your own UI.
- Mark with `"use server"`; validate input at the top (Server Actions are a public endpoint — treat args as untrusted).
- Revalidate affected paths/tags after a write: `revalidatePath("/profil")` or `revalidateTag("progress")`.
- Never trust `userId` from the client — read it from the authenticated Supabase session server-side (see `supabase-ssr-next`).

## Metadata & SEO

- Export `metadata` (static) or `generateMetadata` (dynamic) per route. Set `title`, `description`, `openGraph`, `alternates.canonical`.
- For trilingual routes, set `alternates.languages` with the localized URLs.
- Use the file-based `app/sitemap.ts` and `app/robots.ts` rather than hand-maintained files.

## Images

- Use `next/image` with explicit `width`/`height` (or `fill` + sized container) to prevent CLS.
- Configure `remotePatterns` in `next.config` for Supabase Storage / CDN hosts — `next/image` blocks unconfigured remote hosts.
- Vercel image optimization is metered (see `cost-check-vercel`); prefer pre-sized assets and `sizes` hints for large galleries.

## i18n (next-intl)

- The base `@zrozoom/i18n` package (if consumed) provides locale types, slug maps, and `translatePath()`. The runtime adapter on Next is `next-intl`.
- Locale lives in the URL segment (`app/[locale]/...`). Use middleware for locale negotiation/redirect.
- Keep message catalogs out of the client bundle where possible — `next-intl` server components read messages server-side.
- All user-facing strings via the translation API; never hardcode. Trilingual (PL/EN/UK) from day 1 per project spec.

## Routing structure

- Route groups `(marketing)`, `(app)` to share layouts without affecting URLs.
- `loading.tsx` for Suspense boundaries, `error.tsx` for error boundaries, `not-found.tsx` for 404s — per segment.
- Co-locate route-only components under the segment; promote shared ones to `src/components/`.

## Verification on a Next project

- `next build` must pass (catches RSC/`"use client"` boundary errors that `tsc` alone misses).
- `next lint` (or the project's ESLint with `eslint-config-next`).
- Check the route in the browser: golden path + one error path. Server/Client boundary bugs and hydration mismatches only show at runtime.

## Placeholders

`<DOMAIN_PRIMARY>` (canonical/OG URLs), `<SUPABASE_PROJECT_REF>` (Storage `remotePatterns`). See `.agent/context/project-ids.md`.

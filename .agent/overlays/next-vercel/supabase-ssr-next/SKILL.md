---
name: supabase-ssr-next
description: "Supabase auth + data in Next.js App Router via @supabase/ssr (companion to supabase-admin). Use for cookie-based sessions, middleware token refresh, server/client/route-handler clients, getUser vs getSession, RLS-safe reads, and guest mode. Triggers: @supabase/ssr, createServerClient, createBrowserClient, supabase middleware, getUser, getSession, supabase auth Next.js, login/logout cookies."
---

# Supabase SSR (Next.js App Router)

Companion to the base `supabase-admin` skill (migrations, RLS, type sync — all still apply). This file covers how Supabase auth and data work in Next.js App Router with `@supabase/ssr`.

> **Verify the API against the installed `@supabase/ssr` version.** The cookie interface evolved from `get`/`set`/`remove` to `getAll`/`setAll`. The patterns below use the current `getAll`/`setAll` form. Do not use the deprecated `@supabase/auth-helpers-nextjs`.

## Three client factories — pick by context

| Context | Factory | Can write cookies? |
|---|---|---|
| Client Component (`"use client"`) | `createBrowserClient` | n/a (browser manages) |
| Server Component | `createServerClient` | **No** — read-only; `setAll` is a no-op |
| Route Handler / Server Action / middleware | `createServerClient` | **Yes** |

Centralize these in `src/lib/supabase/` (`client.ts`, `server.ts`, `middleware.ts`) so the cookie wiring lives in one place.

### Browser client

```ts
"use client";
import { createBrowserClient } from "@supabase/ssr";

export const supabase = createBrowserClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
);
```

### Server client (Server Components / Route Handlers / Actions)

> **Next.js 15+**: `cookies()` is async (`await cookies()`). On Next.js 14 and earlier it is synchronous — drop the `await` and make `createClient` non-async.

```ts
import { cookies } from "next/headers";
import { createServerClient } from "@supabase/ssr";

export async function createClient() {
  const cookieStore = await cookies();
  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll();
        },
        setAll(cookiesToSet) {
          try {
            cookiesToSet.forEach(({ name, value, options }) =>
              cookieStore.set(name, value, options),
            );
          } catch {
            // Called from a Server Component — cookies are read-only here.
            // Safe to ignore: middleware refreshes the session.
          }
        },
      },
    },
  );
}
```

## Middleware: refresh the session on every request

The token must be refreshed server-side or it expires mid-session. A `middleware.ts` at the project root runs `updateSession`, which re-reads cookies, calls `getUser()` (which refreshes), and writes refreshed cookies back onto the response.

```ts
// middleware.ts
import { type NextRequest } from "next/server";
import { updateSession } from "@/lib/supabase/middleware";

export async function middleware(request: NextRequest) {
  return updateSession(request);
}

export const config = {
  // Skip static assets and images; run on everything else.
  matcher: ["/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)"],
};
```

`updateSession` MUST: create a server client bound to the request/response cookies, call `await supabase.auth.getUser()`, and return the response with the refreshed cookies. Do not insert logic between client creation and `getUser()`.

## getUser vs getSession — security-critical

- **Server-side auth checks: always `supabase.auth.getUser()`.** It revalidates the JWT against the Supabase Auth server.
- **Never trust `getSession()` for authorization server-side** — it reads the cookie without verifying, so a forged cookie would pass. `getSession()` is fine for non-security UI hints.
- Gate protected routes/layouts on `getUser()`:

```tsx
const { data: { user } } = await supabase.auth.getUser();
if (!user) redirect("/login");
```

## RLS is the real boundary

- The anon key + cookie session is the standard client path; **RLS policies enforce access**, not the app code. See base `supabase-admin` for policy patterns and `is_admin()` helpers.
- Use the **service-role key only in trusted server contexts** (Route Handlers / Server Actions that genuinely need to bypass RLS) and **never** expose it to the browser or put it in `NEXT_PUBLIC_*`.
- Reads/writes of user progress go through RLS-scoped queries keyed on `auth.uid()`.

## Auth flows

- **Login**: email/password or magic link via `supabase.auth.signInWithPassword` / `signInWithOtp`. OAuth via `signInWithOAuth` with a `redirectTo` of your callback route handler.
- **Callback**: a Route Handler (`app/auth/callback/route.ts`) calls `exchangeCodeForSession(code)` then redirects.
- **Logout**: `supabase.auth.signOut()` in a Server Action or Route Handler, then `revalidatePath("/", "layout")` to clear cached user UI.

## Guest mode + deferred sync

Per project spec, guests can use lessons without an account; progress syncs after login:

- Store guest progress locally (localStorage/IndexedDB queue) — do **not** attempt anonymous writes that RLS will reject.
- On login, drain the local queue into RLS-scoped inserts. Resolve conflicts last-write-wins or merge per the progress schema.
- Keep the deterministic-checking and progress logic in shared packages (`@zrozoom/math-core`, `@zrozoom/supabase-client`) so guest and authed paths share one implementation.

## Verification

- `next build` (RSC/cookie boundary errors).
- Manual: log in, refresh, confirm session persists; hit a protected route as guest → redirect; log out → UI clears.
- Confirm no `SUPABASE_SERVICE_ROLE_KEY` appears in any `NEXT_PUBLIC_*` var or client bundle.

## Placeholders

`<SUPABASE_PROJECT_REF>`, `<OWNER>/<REPO>`, `<DOMAIN_PRIMARY>` (OAuth redirect allowlist). See `.agent/context/project-ids.md`. Env vars: `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` (server-only).

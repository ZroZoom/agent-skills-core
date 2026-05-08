---
name: supabase-admin
description: "Database and backend administrator. Use for migrations, RLS changes, Edge Functions, and type synchronization. Trigger when: add a table, change DB schema, new migration, RLS issue, dodaj tabelę, zmień schemat DB, nowa migracja, problem z RLS."
---

# 🗄️ Database Standards

## 1. Creating Migrations

Use the CLI to generate migration files:
`npx supabase migration new change_name`

**Migration checklist:**

- [ ] Table has a primary key (typically `UUID`).
- [ ] `ALTER TABLE ... ENABLE ROW LEVEL SECURITY;` (Mandatory!).
- [ ] Policies added for `anon` (if public) and `authenticated`.
- [ ] Migration was replayed locally or in a disposable preview/staging database before remote deploy.
- [ ] If local replay is temporarily blocked by baseline drift, document the alternative validation path in the PR.

### Local Supabase development

For Supabase projects, prefer a local stack or disposable preview database before pushing migrations to the remote project.

Recommended `package.json` scripts:

| Command | Purpose |
|---|---|
| `npm run db:start` | Start the local Supabase Docker stack |
| `npm run db:stop` | Stop the local stack |
| `npm run db:status` | Print local URLs and anon/service keys |
| `npm run db:reset` | Replay all migrations and seed data locally |
| `npm run db:diff` | Diff linked remote/staging schema against local migrations |
| `npm run update-types:local` | Generate TypeScript types from the local stack |

Use an `.env.local` override with only the local `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` values. Do not copy a full `.env.example` into `.env.local` if it contains placeholder production/staging variables; Vite gives `.env.local` high precedence and placeholders can silently override valid values.

If `db:reset` fails on a fresh local stack because the production schema predated migration tracking, capture the missing baseline in a dedicated migration or validate in a preview/staging project until the baseline is fixed. Do not link a local checkout to production just to test migrations.

## 2. Syncing with the Application

After every schema change, run:

1. `npm run update-types` (Generates `src/types/supabase.ts`).
2. If a table listed in `.agent/context/project-ids.md` → `Tables / collections that affect content layout` changed → run the regen script registered there (e.g. `npm run sync-metadata`).

## 3. Sensitive INSERTs (CRITICAL)

> [!CAUTION]
> **Never insert rows with a "published / approved" status from a migration unless that data has been reviewed.**
> Real incident: a migration that defaulted `status: 'approved'` published unverified content.

**Rule:**

- INSERTs from migrations into status-gated tables (e.g. `resources`, `posts`, `lessons`) → always use the safe default (`pending`, `draft`).
- Only exception: seed data for the local development database.

## 4. Helper Scripts

| Command | Description |
|---------|-------------|
| `npm run update-types` | Update TypeScript types from the remote/staging database |
| `npm run update-types:local` | Update TypeScript types from the local Supabase stack |
| `npm run db:start` | Start local Supabase stack (Docker) |
| `npm run db:reset` | Replay all migrations and seed data locally |
| `npm run db:stop` | Stop local Supabase stack |
| `<your sync command>` | Whatever your project uses to regenerate downstream artifacts after schema changes (register in `project-ids.md`) |

## 5. Security

- **RLS**: Supabase policies are critical. Every table must have RLS enabled.
- **Service Role Keys**: Only in Edge Functions/backend. **NEVER** on the frontend.
- **.env**: Secret files are ignored by Git.
- **Contributor ID**: Every resource must have an assigned author (`contributor_id`).

## 6. RLS Policies — Best Practices

- **Helpers**: Before writing a policy, check existing helpers (e.g. `grep -rE "is_admin|is_owner" supabase/migrations/`). Use centralized helper functions instead of inline `EXISTS (SELECT 1 FROM profiles ...)`.
- **Idempotency**: Always `DROP POLICY IF EXISTS "..."` before `CREATE POLICY` — a migration may be re-run from the SQL Editor.
- **Admin policies**: Every table with user data should have an admin SELECT policy (not just user-own). Without it, the admin panel shows 0 records.

## 7. SQL / Supabase Pitfalls (Lessons Learned)

- **`public.` prefix**: Always use `public.table_name` in migrations and RLS. Linux CI may have a different `search_path` than the local database — without the prefix: `relation does not exist` only in Actions.
- **TRIM() vs \r\n**: PostgreSQL `TRIM()` does NOT remove `\r\n` — only spaces. For Windows-sourced data: `REGEXP_REPLACE(col, E'[\\r\\n]', '', 'g')`.
- **`.in()` URL length**: Supabase REST API passes filters in the URL. >100 IDs → HTTP 400. Split `.in()` calls into batches of 50 IDs.
- **Timestamp collision**: Two migration files with the same timestamp → silent failure on `db push`. Rename + `supabase migration repair --status applied`.
- **Migration rename**: After renaming a file locally you MUST run `supabase migration repair --status reverted <old_timestamp>` on remote.
- **RLS UPDATE + FK**: `WITH CHECK` has no access to the `OLD` row. To control FK changes, use a `BEFORE UPDATE` trigger.
- **Supabase RPC types**: The CLI does NOT generate TypeScript for SQL functions. Maintain manual signatures and use `(client.rpc as any)` with eslint-disable + comment.

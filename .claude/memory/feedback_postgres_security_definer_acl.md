---
name: Postgres SECURITY DEFINER ACL full model
description: For SECURITY DEFINER privilege migrations, model search_path, PUBLIC grants, named roles, and fresh-database drift together
type: feedback
---

When changing `EXECUTE` privileges or `search_path` on a `SECURITY DEFINER` function, do not patch reviewer comments one by one. Map the full security model first.

The interacting pieces:

- `SET search_path = public` is not enough if `pg_temp` is implicitly searched first. Use an explicit safe order such as `public, pg_temp` when appropriate.
- PostgreSQL grants `EXECUTE` to `PUBLIC` by default. Revoking from only `anon` does not remove inherited PUBLIC access.
- Named-role grants can survive a PUBLIC revoke. Inspect `pg_proc.proacl` before assuming what remains.
- Fresh databases may differ from production if explicit grants came from old migrations rather than the original function creation.

**Why:** SECURITY DEFINER fixes often cycle through review rounds because each narrow fix exposes the next layer: PUBLIC inheritance, named-role grants, search_path shadowing, or fresh-DB drift.

**How to apply:**
- Query `pg_proc.proacl` and the function definition before writing the migration.
- Write down the target ACL after each statement.
- Decide whether defensive grants are needed for fresh databases.
- Check generated-type freshness hooks if your repo scans migrations for grant changes.

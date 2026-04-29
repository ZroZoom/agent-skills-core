# agent-skills-core

Project-agnostic Claude Code / multi-agent skills extracted from a real Next.js + Supabase production codebase. Drop this into any new repo as a starting `.agent/` directory.

## What's inside

17 universal skills, organized into four groups:

- **Engineering** (5): `code-quality`, `test-automation`, `test-manager`, `supabase-admin`, `frontend-system`
- **Repo & PM** (6): `repo-ops`, `backlog-triage`, `delegate`, `review-agent`, `release-notes`, `product-manager`
- **Ops & business** (4): `demo-check`, `cost-check`, `investor-report`, `growth-strategist`
- **Content** (2): `blog-editor`, `social-media`

See [`.agent/AGENTS.md`](./.agent/AGENTS.md) for the full index and trigger phrases.

## Quick start

1. Copy `.agent/` and `.claude/` (the latter you can build on top — this package only ships `.agent/`).
2. Search-and-replace placeholders across the directory:

   ```bash
   # GitHub coordinates
   rg -l "<OWNER>/<REPO>" .agent | xargs sed -i 's|<OWNER>/<REPO>|acme/widget|g'
   # Domains
   rg -l "<DOMAIN_PRIMARY>" .agent | xargs sed -i 's|<DOMAIN_PRIMARY>|acme.com|g'
   rg -l "<DOMAIN_SECONDARY>" .agent | xargs sed -i 's|<DOMAIN_SECONDARY>|acme.app|g'
   ```

   Other placeholders (`<SITE_NAME>`, `<SITE_ID>`, `<PRODUCT_STATS_FILE>`, `<DEMO_MILESTONE>`, `<STORAGE_BASE_URL>`) appear in only one or two files — fill them in inline.

3. Drop `supabase-admin` if you don't use Supabase, or rename to your data layer (Prisma, Drizzle, raw Postgres).

4. Drop or simplify the i18n section of `frontend-system` if your project is single-locale.

## Origin

Extracted and de-personalized from `ZroZoom/Szkola_Przyszlosci_AI` (an EdTech platform). The 4 education-specific skills (`content-architect`, `content-factory-onboarding`, `pedagogue`, `matura-matematyka-cke`) were intentionally left out — they don't generalize.

## License

Match the license of the parent project, or relicense as you wish — these are configuration files, not application code.

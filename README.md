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

1. Use this template (GitHub: "Use this template") or copy `.agent/`, `.claude/`, and `CLAUDE.md` into your repo.
2. **Fill in `.agent/context/project-ids.md`** — single source of truth for all GitHub Project / Jira / hosting / domain identifiers. Skills and slash commands resolve placeholders from this file at runtime.
3. Search-and-replace remaining `<OWNER>/<REPO>` and `<DOMAIN_*>` references:

   ```bash
   rg -l "<OWNER>/<REPO>" .agent .claude CLAUDE.md | xargs sed -i 's|<OWNER>/<REPO>|acme/widget|g'
   rg -l "<DOMAIN_PRIMARY>"   .agent .claude | xargs sed -i 's|<DOMAIN_PRIMARY>|acme.com|g'
   rg -l "<DOMAIN_SECONDARY>" .agent .claude | xargs sed -i 's|<DOMAIN_SECONDARY>|acme.app|g'
   ```

   Other placeholders (`<SITE_NAME>`, `<SITE_ID>`, `<PRODUCT_STATS_FILE>`, `<DEMO_MILESTONE>`, `<STORAGE_BASE_URL>`, `<JIRA_PROJECT_KEY>`, `<TESTER_ACCOUNT_ID>`) appear in only one or two files — fill them in inline.
4. Drop `supabase-admin` if you don't use Supabase, or rename to your data layer (Prisma, Drizzle, raw Postgres).
5. Drop or simplify the i18n section of `frontend-system` if your project is single-locale.
6. **Apply branch protection** to the new repo:

   ```bash
   ./scripts/apply-rulesets.sh                                # default (solo dev + bots)
   ./scripts/apply-rulesets.sh main-branch-protection-with-ci # stricter, with required CI checks
   ```

   See [`.github/rulesets/README.md`](./.github/rulesets/README.md) for what each ruleset enforces.

## Conventions enforced by this template

- **Single source of truth for IDs.** All GitHub Project / Jira / hosting IDs live in `.agent/context/project-ids.md`. If a placeholder is still `<...>`, the agent halts and asks instead of inventing one.
- **Bash safety.** Multi-step Bash snippets start with `set -euo pipefail` and quote variables.
- **Untrusted input.** Issue / PR titles and bodies are passed via `--body-file` or `-F field=@/tmp/file`, never via shell interpolation.
- **Skills > commands.** When a slash command and a skill both describe a workflow, the skill is authoritative — commands are thin runbooks that link into skills.

## Origin

Extracted and de-personalized from `ZroZoom/Szkola_Przyszlosci_AI` (an EdTech platform). The 4 education-specific skills (`content-architect`, `content-factory-onboarding`, `pedagogue`, `matura-matematyka-cke`) were intentionally left out — they don't generalize.

## License

Match the license of the parent project, or relicense as you wish — these are configuration files, not application code.

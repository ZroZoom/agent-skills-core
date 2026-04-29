# AGENTS.md — Documentation Index (core)

> Universal agent skills, project-agnostic. Scan this index, then load files on-demand.

## Skills (load on-demand)

### Engineering

| Skill | When to use | Path |
|-------|-------------|------|
| code-quality | ESLint / TypeScript fixes, refactor | `.agent/skills/code-quality/SKILL.md` |
| test-automation | Unit / E2E tests (Playwright + Vitest) | `.agent/skills/test-automation/SKILL.md` |
| test-manager | Manual QA, PR test plans, status tracking | `.agent/skills/test-manager/SKILL.md` |
| supabase-admin | DB migrations, RLS, type sync (drop if not on Supabase) | `.agent/skills/supabase-admin/SKILL.md` |
| frontend-system | UI components, Tailwind, i18n, a11y, SEO | `.agent/skills/frontend-system/SKILL.md` |

### Repo & PM

| Skill | When to use | Path |
|-------|-------------|------|
| repo-ops | Git Flow, Issues / PRs, Projects, sprint planning | `.agent/skills/repo-ops/SKILL.md` |
| backlog-triage | Prioritize issues without milestones (GitHub + Jira) | `.agent/skills/backlog-triage/SKILL.md` |
| delegate | GitHub issue → ready prompt for another AI agent | `.agent/skills/delegate/SKILL.md` |
| review-agent | Audit AI-generated PRs (Claude / Codex / Copilot) | `.agent/skills/review-agent/SKILL.md` |
| release-notes | Bilingual changelog from merged PRs | `.agent/skills/release-notes/SKILL.md` |
| product-manager | Release cycle, quality gates, blocker management | `.agent/skills/product-manager/SKILL.md` |

### Operations & business

| Skill | When to use | Path |
|-------|-------------|------|
| demo-check | Verify demo readiness, generate presenter script | `.agent/skills/demo-check/SKILL.md` |
| cost-check | Audit hosting / DB / domain / SSL / API cost risks | `.agent/skills/cost-check/SKILL.md` |
| investor-report | Stakeholder report (PDF-ready markdown) | `.agent/skills/investor-report/SKILL.md` |
| growth-strategist | SEO, landing page audits, meta optimization | `.agent/skills/growth-strategist/SKILL.md` |

### Content

| Skill | When to use | Path |
|-------|-------------|------|
| blog-editor | Articles, marketing copy, internal linking | `.agent/skills/blog-editor/SKILL.md` |
| social-media | LinkedIn / FB posts, YouTube descriptions | `.agent/skills/social-media/SKILL.md` |

## Placeholders to fill in per project

These tokens appear across the skills — search-and-replace before first use:

| Placeholder | Meaning |
|---|---|
| `<OWNER>/<REPO>` | GitHub repository (e.g. `acme/widget`) |
| `<DOMAIN_PRIMARY>` / `<DOMAIN_SECONDARY>` | Production domains |
| `<SITE_NAME>` / `<SITE_ID>` | Hosting site identifiers (Netlify / Vercel) |
| `<PRODUCT_STATS_FILE>` | Generated stats file used by `investor-report` |
| `<DEMO_MILESTONE>` | Default milestone used by `demo-check` |
| `<STORAGE_BASE_URL>` | Public base URL for the blog-images bucket |

## Conventions

- **Skills load on-demand.** Add only relevant skills to a session; do not load the whole catalogue.
- **No side effects without confirmation.** Skills must respect `--apply` / explicit user approval before mutating state.
- **Polish-first reports** are the project default — translate to English on request only.
- **Never paste secrets** (service-role keys, billing details, tokens) into output.

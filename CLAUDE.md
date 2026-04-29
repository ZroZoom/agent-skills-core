# CLAUDE.md

This file provides guidance to Claude Code (and other agents like Codex / Copilot) when working with code in this repository.

> **TEMPLATE.** Customize the `Tech Stack`, `Commands`, and `Architecture` sections for your project. The rules in `Git Rules`, `PR Management`, `Skills System`, `CI Monitoring`, and `Communication` are designed to be used as-is.

## Tech Stack

- **Runtime**: <e.g. Node 20, Python 3.12>
- **Frontend**: <e.g. React 19, TypeScript, Tailwind CSS, Vite>
- **Backend**: <e.g. Supabase / Postgres / Express>
- **Testing**: <e.g. Vitest (unit), Playwright (E2E)>
- **I18n** (if applicable): <list of locales, primary first>

## Commands

```bash
npm run dev              # Start dev server
npm run build            # Production build
npm run typecheck        # TypeScript check (MUST pass)
npm run lint             # ESLint check
npm run lint:fix         # Auto-fix lint issues
npm run test             # Run all unit tests
npx vitest run path/to/test.ts        # Single test file
npx vitest run --grep "test name"     # Tests matching pattern
npx playwright test e2e/file.spec.ts  # Single E2E test
npm run quality          # lint + typecheck combined
```

> Replace, add, or remove rows above to match your `package.json` / build system.

## Architecture

> Document the modules, routing, state management, and data layer of your project here. Keep this section short — link out to deeper docs in `.agent/context/` when needed.

## Verification After Changes

1. `npm run typecheck` — MUST pass
2. `npm run lint` — fix errors
3. `npm run build` — verify build works
4. `git status` after build — include all generated files in commit (or confirm none changed)

## Git Rules (CRITICAL)

> Full details: `.agent/skills/repo-ops/SKILL.md`

- **NEVER commit to `main`** — always use feature branches (`feature/*`, `fix/*`, `chore/*`)
- **NEVER use `git stash`** — ask the user: "Keep (WIP commit) or discard?"
- **Verify branch BEFORE EVERY commit**: `git branch --show-current` must NOT be `main` or `master`
- **Workflow**: `git checkout -b feature/x` → changes → `git push` → PR

> Some of these prohibitions can be enforced by hooks in `.claude/hookify.*.local.md` (only active when the [hookify](https://github.com/anthropics/claude-code-plugins/tree/main/hookify) Claude Code plugin is installed; plain `git`/shell invocations are unaffected). Disable a rule with `enabled: false` in its frontmatter.

**Session end checklist:**
1. Commit all changes (including any generated files your build emits)
2. `git push` the feature branch
3. Check PR status: `gh pr status` or `gh pr view`
4. `git checkout main && git pull` — leave repo on main with clean tree

## PR Management (CRITICAL)

> Full checklist: `.claude/commands/merge.md`

Manual merge checklist:

1. **Resolve ALL review conversations** — including bot reviews (Copilot, Gemini, etc.). Use the GraphQL `resolveReviewThread` mutation — replying is NOT enough.
2. **Verify CI is green** — `gh pr checks` must show all passing.
3. **Update branch** if behind main — use GitHub API `update-branch` or rebase locally.
4. **Merge**: `gh pr merge --squash --auto` (works with merge queues; `--admin` is forbidden — it bypasses protection).

If your repo has automated reviewers, wait ~2 min after each push before checking again. Unresolved conversations BLOCK merge — bot threads block just like human reviews.

## Type Safety

> Full details: `.agent/skills/code-quality/SKILL.md`

When a query/SDK doesn't compile — **FIRST regenerate types from your data layer** (e.g. `npm run update-types`, `prisma generate`, `openapi-typescript`). If a table/endpoint still doesn't exist (new migration pre-deploy), use a narrow `as any` cast with a `// TODO:` comment. **NEVER** use `as any` as a permanent fix — open an issue for cleanup.

**Hierarchy**: Type Safety (compiles) > ESLint score.

## Skills System

| Task                       | File                                       |
|----------------------------|--------------------------------------------|
| TypeScript / ESLint fixes  | `.agent/skills/code-quality/SKILL.md`      |
| UI components, styling     | `.agent/skills/frontend-system/SKILL.md`   |
| Git, Issues, PRs           | `.agent/skills/repo-ops/SKILL.md`          |
| Database migrations / RLS  | `.agent/skills/supabase-admin/SKILL.md`    |
| E2E / Unit tests           | `.agent/skills/test-automation/SKILL.md`   |
| Manual testing, PR testing | `.agent/skills/test-manager/SKILL.md`      |
| Backlog triage             | `.agent/skills/backlog-triage/SKILL.md` / `.claude/commands/triage.md` |
| Issue → agent prompt       | `.agent/skills/delegate/SKILL.md` / `.claude/commands/delegate.md` |
| AI-agent PR review         | `.agent/skills/review-agent/SKILL.md` / `.claude/commands/review-agent.md` |
| Release notes              | `.agent/skills/release-notes/SKILL.md` / `.claude/commands/release-notes.md` |
| Release management         | `.agent/skills/product-manager/SKILL.md`   |
| Demo readiness             | `.agent/skills/demo-check/SKILL.md` / `.claude/commands/demo-check.md` |
| Stakeholder report         | `.agent/skills/investor-report/SKILL.md` / `.claude/commands/investor-report.md` |
| Cost / domain monitoring   | `.agent/skills/cost-check/SKILL.md` / `.claude/commands/cost-check.md` |
| SEO, growth                | `.agent/skills/growth-strategist/SKILL.md` |
| Blog editing               | `.agent/skills/blog-editor/SKILL.md`       |
| Social media               | `.agent/skills/social-media/SKILL.md`      |

## Documentation Map

| Need                       | File                                   |
|----------------------------|----------------------------------------|
| Skills index               | `.agent/AGENTS.md`                     |
| Database / data context    | `.agent/context/database.md` *(create per project)* |
| Session learnings          | `.agent/SESSION_LEARNINGS.md` *(append over time)* |
| Cross-agent memory (SSOT)  | `.claude/memory/MEMORY.md` *(create per project)*  |
| Slash commands             | `.claude/commands/*.md`                |

## CI Monitoring

- Use `gh pr checks --watch` in background — **never poll manually in a loop**.
- Wait for background task notification instead of repeated `grep pending`.
- **CI job failed transiently?** (network timeout, API 500): `gh run rerun <run-id> --failed` — re-runs only failed jobs, no empty commit needed.
- **CI not triggering?** Sometimes the `pull_request` event doesn't fire. Fix: `gh pr close <N> && gh pr reopen <N>`. If still stuck, push an empty commit: `git commit --allow-empty -m "chore: trigger CI"`.

## Post-Merge Checklist

After merging any PR:
1. Close linked issues / tickets (GitHub, Jira, Linear)
2. Verify deploy succeeded (Netlify / Vercel / your hosting)
3. Smoke test on production per PR test plan
4. Clean up merged local branches
5. `git checkout main && git pull`

## Communication

- Default to the user's preferred language (configure per project — many teams default to English; some default to Polish).
- Be concise and specific. Surface uncertainty when present.
- When finding issues, ask before making changes: "Found X in Y files. Replace with Z?"
- For sensitive or irreversible actions (deploys, deletes, schema migrations), confirm with the user first.

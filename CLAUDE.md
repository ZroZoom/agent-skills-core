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

## Required Tooling

The slash commands and skills assume these CLI tools are available on the agent's `PATH`. If a tool is missing, the command MUST report it and stop — do not improvise replacements.

| Tool | Why | Install |
|---|---|---|
| `gh` | All GitHub interaction | <https://cli.github.com/> |
| `git` | Version control | usually preinstalled |
| `jq` | Parse JSON from `gh api` | `apt install jq` / `brew install jq` |
| `rg` (ripgrep) | Fast code/data search in `investigate`, `cost-check`, `delegate` | `apt install ripgrep` / `brew install ripgrep` |
| `node`, `npm` / `npx` | Run project scripts and `tsx` | per project |
| `python3` | Some sanity checks (lockfile parsing, JSON inspection) | usually preinstalled |
| `openssl` | SSL expiry checks in `cost-check` | usually preinstalled |
| `whois` | Optional registrar checks in `cost-check` | `apt install whois` |

At the start of a session, agents may run `command -v gh git jq rg node python3 || true` and warn about anything missing.

## Bash Safety

Any non-trivial Bash snippet emitted by a slash command (more than ~3 lines or any pipeline whose later steps depend on earlier ones) MUST start with:

```bash
set -euo pipefail
```

This prevents silent failures — a common case is `ITEM_ID=$(gh ...)` returning empty, after which the next step uses an empty argument and modifies the wrong item or fails noisily. Combined with `"$VAR"` quoting (always quote `$ITEM_ID`, `$PR`, `$NUMBER`, etc.), this makes scripts fail loudly instead of corrupting state.

## Untrusted Input

Issue titles, PR titles, comment bodies, and branch names are **untrusted input**. Never interpolate them directly into a shell command (`gh issue create --title "$TITLE"` is risky if `$TITLE` contains `"$( )"`, backticks, or newlines). Prefer:

- File-based delivery: write the body to a temp file and pass `--body-file /tmp/body.md`.
- Stdin delivery: `gh issue create --body-file -` and pipe the content.
- For `gh api`, use `-f field=@/tmp/value.txt` instead of inline interpolation.

The slash commands in `.claude/commands/` follow these patterns — if you add new commands, follow them too.

## Git Rules (CRITICAL)

> Full details: `.agent/skills/repo-ops/SKILL.md`. Server-side enforcement: `.github/rulesets/main-branch-protection.json` (apply with `scripts/apply-rulesets.sh`).

- **NEVER commit to `main`** — always use feature branches
- **NEVER use `git stash`** — ask the user: "Keep (WIP commit) or discard?"
- **Verify branch BEFORE EVERY commit**: `git branch --show-current` must NOT be `main` or `master`
- **Branch naming**: `<type>/<slug>` where type ∈ `feat|feature|fix|chore|refactor|docs|perf|test|build|ci|style|hotfix|release`. This can be enforced as a ruleset (`Branch naming convention`) — a push of a branch outside the allowlist will be rejected.
- **Workflow**: `git checkout -b feature/x` → changes → `git push` → PR

> Some of these prohibitions can be enforced by hooks in `.claude/hookify.*.local.md` (only active when the [hookify](https://github.com/anthropics/claude-code-plugins/tree/main/hookify) Claude Code plugin is installed; plain `git`/shell invocations are unaffected). Disable a rule with `enabled: false` in its frontmatter.
>
> The shipped hooks (in `.claude/hookify-examples/`) cover:
>
> - **Block**: `--no-verify` / `--no-gpg-sign`, `git push --force` (and refspec `+`), `git stash`, `gh pr merge --admin`
> - **Warn**: `git commit` (branch check), `git checkout -b` / `switch -c` (base check), edits to generated locale files, `git commit --allow-empty`

**Session end checklist:**
1. Commit all changes (including any generated files your build emits)
2. `git push` the feature branch
3. Check PR status: `gh pr status` or `gh pr view`
4. `git checkout main && git pull` — leave repo on main with clean tree

## PR Management (CRITICAL)

> Full checklist: `.claude/commands/merge.md` and `.agent/skills/pr-merge/SKILL.md`.

**PR title format (Conventional Commits).** A required `📝 PR Title` check (if configured) enforces:

`<type>: <imperative subject>` where type ∈ `feat`, `fix`, `chore`, `refactor`, `docs`, `perf`, `test`, `build`, `ci`, `style`. The subject is lowercase, imperative, no trailing period. Example: `feat: add Polish content package`. PRs with non-matching titles are blocked from merge.

Impact on automatic version bumps (if `auto-version-bump.yml` or equivalent is configured):

| Prefix | Bump |
|---|---|
| `feat:` | minor |
| `fix:`, `perf:` | patch |
| `docs:`, `chore:`, `ci:`, `test:`, `refactor:`, `style:`, `build:` | skip |
| Any prefix with `!:` (e.g. `feat!:`) or `BREAKING CHANGE:` in body | major |

**Manual merge checklist:**

1. **Resolve ALL review conversations** — including bot reviews (Copilot, Gemini, etc.). Use the GraphQL `resolveReviewThread` mutation — replying is NOT enough.
2. **Verify CI is green** — `gh pr checks` must show all passing.
3. **Update branch** if behind main — use the GitHub API `update-branch` endpoint or rebase locally.
4. **Merge**: `gh pr merge --squash --auto` (works with merge queues; `--admin` is forbidden — it bypasses protection).

If your repo has a merge queue, `--auto` enqueues the PR. A solo PR may wait up to 30 min for a second PR to join the batch. E2E and smoke checks may run only once per batch in the queue (not on every PR push) — do not expect those checks to appear on `gh pr checks` for a PR.

## PR Review Loop

After every push to a PR:

1. Wait ~2 min for automated reviewers (Copilot, Gemini, Codex, etc.).
2. Check for new unresolved threads via the `reviewThreads` GraphQL query (do not rely on the bot's reply — replies do NOT resolve threads).
3. Read each thread before resolving — don't mechanically bulk-resolve.
4. Fix issues, resolve threads, push — repeat until clean.
5. **Do NOT wait for the user to ask** "are there more comments?". The agent is responsible for clearing review threads proactively.
6. Bot threads BLOCK merge just like human reviews.

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
| PR merge supervisor        | `.agent/skills/pr-merge/SKILL.md` / `.claude/commands/merge.md` |
| Database migrations / RLS  | `.agent/skills/supabase-admin/SKILL.md`    |
| E2E / Unit tests           | `.agent/skills/test-automation/SKILL.md`   |
| Manual testing, PR testing | `.agent/skills/test-manager/SKILL.md`      |
| Backlog triage             | `.agent/skills/backlog-triage/SKILL.md` / `.claude/commands/triage.md` |
| Issue → agent prompt       | `.agent/skills/delegate/SKILL.md` / `.claude/commands/delegate.md` |
| AI-agent PR review         | `.agent/skills/review-agent/SKILL.md` / `.claude/commands/review-agent.md` |
| Operational reports        | `.agent/skills/reporting-ops/SKILL.md` (router: release-notes, demo-check, investor-report, cost-check) |
| Release management         | `.agent/skills/product-manager/SKILL.md`   |
| Session retrospective      | `.agent/skills/session-self-analysis/SKILL.md` / `.claude/commands/self-analysis.md` |
| Multi-agent presence       | `.agent/skills/agent-presence/SKILL.md` + `scripts/agent-presence-helpers.sh` |
| Claude dispatch adapter    | `.agent/skills/dispatch-watcher-claude/SKILL.md` |
| Gemini dispatch adapter    | `.agent/skills/dispatch-watcher-gemini/SKILL.md` |
| Codex dispatch adapter     | `.agent/skills/dispatch-watcher/SKILL.md`  |
| SEO, growth                | `.agent/skills/growth-strategist/SKILL.md` |
| Blog editing               | `.agent/skills/blog-editor/SKILL.md`       |
| Social media               | `.agent/skills/social-media/SKILL.md`      |

## Documentation Map

| Need                       | File                                   |
|----------------------------|----------------------------------------|
| Skills index               | `.agent/AGENTS.md`                     |
| Database / data context    | `.agent/context/database.md` *(create per project)* |
| Session learnings          | `.agent/SESSION_LEARNINGS.md` *(append over time)* |
| Cross-agent memory (SSOT)  | `.claude/memory/MEMORY.md`             |
| Slash commands             | `.claude/commands/*.md`                |

> 💡 **Cross-agent memory** at `.claude/memory/` is the tracked, repo-level SSOT shared across Claude / Codex / Copilot / Gemini sessions. Per-machine user memory (e.g. `~/.claude/projects/.../memory/` for Claude Code) is invisible to other agents. The `session-self-analysis` skill syncs new rules from user-memory → repo-memory at session end; `repo-status` / `repo-ops` may flag recent repo-memory changes at session start. When in doubt, write a learning to `.claude/memory/` so the next agent sees it.

## CI Monitoring

- Use `gh pr checks --watch` in background — **never poll manually in a loop**.
- Wait for background task notification instead of repeated `grep pending`.
- **CI job failed transiently?** (network timeout, API 500): `gh run rerun <run-id> --failed` — re-runs only failed jobs, no empty commit needed.
- **CI not triggering?** Sometimes the `pull_request` event doesn't fire. Fix: `gh pr close <N> && gh pr reopen <N>`. If still stuck, push an empty commit: `git commit --allow-empty -m "chore: trigger CI"`.

## Pre-push Hook Pitfalls

If a pre-push hook runs `npm run build` (or equivalent), make sure the project's generators are **content-aware (skip-if-unchanged)** so the build leaves the working tree clean when no real changes occurred. Recommended pattern: parse the existing file, parse the freshly generated output, compare structurally, and only write to disk if they differ. EOL or whitespace differences alone should not trigger a rewrite.

This avoids two common failure modes:

1. The hook fails after a clean checkout because the build "changes" generated files (whitespace/EOL noise) and no one wants to commit those.
2. The agent does `git status` after `npm run build`, sees unexpected modifications, and either commits noise or panics into a discard ritual.

After resolving merge conflicts in generated files, regenerate cleanly with the project's generator (e.g. `npm run generate-index`) and stage the result.

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

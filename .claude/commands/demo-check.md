# Demo Check

Verify demo readiness and produce a presenter script.

Load `.agent/skills/demo-check/SKILL.md` and follow it.

## Arguments

- Optional milestone, defaults to `<DEMO_MILESTONE>` (configure per project).
- Optional URL, defaults to local dev server or production if local is not running.
- Optional `--full` to include `npm run build`.

## Required flow

1. Fetch milestone issue status.
2. Check open PRs and CI/deploy signals.
3. Run `npm run typecheck` and `npm run lint`.
4. Verify landing, auth, and the project's critical feature paths.
5. Produce a Polish readiness report and click-by-click demo script.

Never claim a path is verified unless it was actually opened or covered by a passing test.

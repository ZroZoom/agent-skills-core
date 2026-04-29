# `.claude/` — Claude Code configuration

This directory is read first by Claude Code in the workspace root.

## Layout

```
.claude/
├── settings.json              # Permissions + hooks (typecheck after edit, block main commits)
├── commands/                  # 18 slash commands ready to use
└── hookify-examples/          # 8 sample hookify rules — copy to .claude/ root and enable
```

## Slash commands

Each `commands/<name>.md` defines a `/` command callable in Claude Code. Highlights:

| Command            | What it does                                                |
|--------------------|-------------------------------------------------------------|
| `/triage`          | Backlog triage across GitHub + Jira                         |
| `/delegate`        | Turn a GitHub issue into a ready prompt for another agent   |
| `/review`          | Full code review of the current PR                          |
| `/review-agent`    | Audit a PR produced by an AI agent (Claude/Codex/Copilot)   |
| `/merge`           | PR merge checklist (resolve threads → CI green → merge)     |
| `/release-notes`   | Bilingual changelog from merged PRs since last tag          |
| `/cost-check`      | Hosting + DB + domain + SSL audit                           |
| `/demo-check`      | Demo readiness verification + presenter script              |
| `/investor-report` | Stakeholder report (PDF-ready markdown)                     |
| `/deploy`          | Deployment checklist                                        |
| `/test`            | Unit + E2E test plan/run                                    |
| `/qa-handoff`      | Hand off a PR to QA via Jira ticket                         |
| `/fix-lint`        | Targeted lint fixes following code-quality skill            |
| `/investigate`     | Data-quality issue investigation                            |
| `/repo`            | Repository operations (Issues/PRs/labels/projects)          |
| `/project`         | GitHub Projects status update                               |
| `/status`          | Current project + Jira status report                        |
| `/self-analysis`   | End-of-session reflection: sync new rules to repo memory    |

## Hookify (optional)

If you install the [hookify](https://github.com/anthropics/claude-code-plugins/tree/main/hookify) plugin, copy any of the files under `hookify-examples/` to `.claude/` (drop the `-examples/` segment) and enable them by setting `enabled: true` in their frontmatter.

The bundled rules:

- **block-force-push** — refuses `git push --force` and refspec `+`
- **block-git-stash** — refuses `git stash` (forces WIP commit instead)
- **block-no-verify** — refuses `--no-verify` / `--no-gpg-sign`
- **block-pr-merge-admin** — refuses `gh pr merge --admin` (bypasses protection)
- **warn-checkout-new-branch** — warns when creating a branch from the wrong base
- **warn-commit-allow-empty** — warns about empty commits
- **warn-edit-public-locales** — warns when editing generated i18n artifacts
- **warn-git-commit-branch** — warns before committing on `main`

These hooks are independent of `settings.json` (which contains the always-on PreToolUse / PostToolUse hooks and is more universal).

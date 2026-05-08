# MEMORY — cross-agent shared learnings

> **What this is.** A tracked, versioned memory shared across Claude Code, Codex, Copilot, and peer sessions. Each entry is a short, named lesson — usually born of a real mistake — that next sessions should consult before repeating the same mistake.
>
> **What this is NOT.** Per-machine user memory (e.g. `~/.claude/projects/<repo>/memory/`) that's invisible to other agents. The files here are committed and shared.
>
> **How to add an entry.** At session end (`/self-analysis`), write a single-paragraph file `feedback_<short-slug>.md` with frontmatter `name`, `description`, `type: feedback`, then bold `**Why:**` and `**How to apply:**` sections. Keep entries < 25 lines. Link them from this index so they're discoverable.
>
> **Editor's note.** This template ships with **49 universal feedback files** distilled from a real production codebase. Some refer to specific PR numbers — those are kept as evidence of when/why the rule was learned. Drop or replace any entry that doesn't fit your project. Add `user_*.md`, `project_*.md`, and `reference_*.md` files as your team grows; this template intentionally ships **without** those (they're project-specific).

## Read Before Acting

Descriptions below are hooks; the rules live in the linked files. Recency does not matter. A 30-day-old rule is just as binding as today's if it applies.

The always-on bullets below are binding inline. Most memory files are short; read relevant ones in full before acting. The "trim context" rule applies to long source/docs files, not to memory files.

### Always-on

- **Verify state before claiming** "0 unresolved", "ready", or "no findings" - run a fresh query, not cached output.
- **Verify bot claims** before incorporating - Copilot, Gemini, CodeRabbit, and similar tools produce hypotheses; check the source.
- **Parallel-safe** - never group risky writes/mutations with safe reads in one parallel block.
- **Trim context** - use head/tail/grep before full reads; use offset/limit on long files.
- **Prove root cause cheaply** - use a fast probe (curl, unit test, shell check) before iterating through slow CI/E2E.

### Activity map

- **Merging a PR** -> "Git & PR Workflow" + "Merge & Automation" + "Post-Merge & QA"
- **Reviewing a PR** -> "PR Review & CI" + "Reasoning & Quality"
- **Debugging CI failure** -> "PR Review & CI" + "Merge & Automation"
- **Database migration** -> "Database & Architecture"
- **Content or data validation** -> "Validation & Data Quality" + "Reasoning & Quality"
- **Triage / backlog work** -> "Git & PR Workflow" + "Post-Merge & QA" + "Reasoning & Quality"

For activities covered by a slash command (`/merge`, `/review`, `/triage`), prefer that command's "Memory consult" step; it lists the tightest file set for that workflow.

## Git & PR Workflow

- [Use /merge command](feedback_use_merge_command.md) — Always use the merge command for PR merges (full checklist)
- [PR workflow](feedback_pr_workflow.md) — PRs sequentially, not in parallel — CI restarts
- [Draft PR](feedback_draft_pr.md) — Add changes to existing draft PR instead of creating new
- [No stash](feedback_no_stash.md) — Never use git stash; user forgets about them
- [PR setup](feedback_pr_setup.md) — After `gh pr create`: labels, assignee, GitHub Project fields
- [GitHub Rulesets](feedback_github_rulesets.md) — Use rulesets API, not legacy branch protection
- [Update branch](feedback_update_branch.md) — Proactively check `mergeable_state` and update before merge
- [Verify before delete](feedback_verify_before_delete.md) — Verify and ask before deleting branches
- [Pre-push OOM (Windows)](feedback_pre_push_oom.md) — Build OOM: `NODE_OPTIONS="--max-old-space-size=8192"`
- [Branch delete hook](feedback_branch_delete_hook.md) — `git push --delete` triggers build; use API or `fetch --prune`
- [Generators idempotent](feedback_generators_idempotent.md) — Build skips writing when output unchanged; no discard ritual
- [Fetch before push](feedback_fetch_before_push.md) — Automation can add commits; fetch/rebase before pushing to an active PR branch
- [PR path overlap check](feedback_pr_path_overlap_check.md) — Check open PR file lists before bundling unrelated leftovers
- [Git add explicit paths](feedback_git_add_explicit_paths.md) — Use explicit `git add path...`; never sweep with `git add -A` or `.`

## PR Review & CI

- [PR review bots](feedback_pr_review_bots.md) — GraphQL `resolveReviewThread` for bot reviews
- [Bot review triage](feedback_bot_review_triage.md) — How to assess / dismiss bot suggestions
- [Verify bot claims](feedback_verify_bot_claims.md) — Treat bot suggestions as hypotheses; verify against source code/docs
- [Bot fix re-audit](feedback_bot_fix_reaudit.md) — After bot-driven fixes, re-read the whole affected function/module
- [PR review loop](feedback_pr_review_loop.md) — After push to PR, monitor comments every 2 min and fix
- [Proactive review](feedback_review_proactive.md) — After push, check for new comments proactively
- [No poll loops](feedback_no_poll_loop.md) — Don't poll CI manually; use `--watch` in background
- [GraphQL pagination](feedback_graphql_pagination.md) — `reviewThreads(first:100)` + `hasNextPage`; PRs hit 80+ threads
- [Verify state before claim](feedback_verify_state_before_claim.md) — Fresh-query PR state before saying ready/clean
- [GraphQL rate limit](feedback_graphql_rate_limit.md) — Budget calls in multi-cycle sessions; batch mutations
- [Subagent report detail untrusted](feedback_subagent_report_detail_unreliable.md) — Verify implementer subagent reports against actual files/commits

## Post-Merge & QA

- [Post-merge checklist](feedback_post_merge.md) — Close tickets, verify deploy, smoke test, cleanup
- [For testing flow](feedback_for_testing_flow.md) — After merge: Kanban → "For testing" + QA tickets in Jira
- [QA ticket status](feedback_qa_ticket_status.md) — Create QA tickets in `To Do`, not `In Review`

## Session Management

- [Self-analysis](feedback_self_analysis.md) — Run `/self-analysis` at end of every session with PR review
- [Status cadence](feedback_status_cadence.md) — Proactive ~5-min ping during long async ops
- [Scan new tools](feedback_scan_new_tools.md) — On session start, check git log for new tools

## Reasoning & Quality

- [Grounding](feedback_grounding_in_project.md) — Assess practices based on THIS project's data, not generic best practices
- [Docs = code](feedback_docs_review_quality.md) — Shell commands in docs go through full bot review
- [Parallel calls](feedback_parallel_calls.md) — Don't group risky API calls with safe ones in a parallel block
- [Codex quality](feedback_codex_quality.md) — Codex generates placeholders — always audit topical relevance
- [Prove root cause cheaply](feedback_prove_root_cause_cheaply.md) — Use the fastest direct probe before slow CI/E2E loops
- [Check conventions & tests](feedback_check_conventions_and_tests.md) — Match neighboring files; run existing tests

## Validation & Data Quality

- [Validator against runtime](feedback_validator_against_runtime.md) — Validator rules must be checked against runtime code paths, not just specs

## Database & Architecture

- [Postgres SECURITY DEFINER ACL](feedback_postgres_security_definer_acl.md) — Model search_path, PUBLIC grants, named roles, and fresh DB drift together

## Merge & Automation

- [Auto-merge when ready](feedback_auto_merge_when_ready.md) — CI green + 0 unresolved → merge immediately
- [Supervisor timing](feedback_supervisor_timeout.md) — `WAIT_REVIEWS=240s`; "ready for review" triggers new bot cycle
- [Supervisor loop bypass](feedback_supervisor_loop_bypass.md) — Multi-cycle stuck loops; kill, use direct `gh pr merge --auto`
- [Hooks timeout big merges](feedback_hooks_timeout_big_merges.md) — Validators slow on 90+ files; foreground 10 min, never `--no-verify`
- [Batch-merge cascade](feedback_batch_merge_cascade.md) — Merging 5+ PRs forces cascading rebases; interleave authors

## Formatting & Code Patterns

- [SESSION_LEARNINGS format](feedback_session_learnings_format.md) — Use bullets (`- `), not numbered lists
- [Conditional string formatting](feedback_conditional_string_formatting.md) — Enumerate input→output cases before coding punctuation logic
- [Verify CSS plugins](feedback_verify_css_plugins.md) — Check `package.json` before using animation utility classes
- [Migration feature parity](feedback_migration_feature_parity.md) — Migrating eval→safeEval: test every operator before commit
- [Context efficiency](feedback_context_efficiency.md) — Trim output (`tail`/`head`); read files with offset/limit

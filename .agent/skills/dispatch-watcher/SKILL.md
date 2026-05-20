---
name: dispatch-watcher
description: "Optional agent dispatch watcher — Phase 1 walking skeleton, Codex-flavored. Use on agent session start when a Slack-style dispatch channel assigns GitHub issues to a model handle such as @codex. For Claude use [[dispatch-watcher-claude]], for Gemini use [[dispatch-watcher-gemini]], for the full multi-agent contract see [[agent-presence]]."
---

# Dispatch Watcher Skill

Use this optional skill when a team runs a lightweight dispatch loop where humans or a PM agent post messages like `@codex #123` in a shared channel and an agent claims one GitHub issue at a time.

> **Two phases.** This file is the Phase 1 walking-skeleton (Codex-flavored, one-shot, manual takeover only). Phase 2 — multi-agent coordination with leases, renewal, automatic takeover, and a pinned roster — lives in `.agent/skills/agent-presence/SKILL.md` + per-CLI adapters (`dispatch-watcher-claude`, `dispatch-watcher-gemini`). Phase 2 markers are **backwards-compatible** with Phase 1 (a Phase 1 marker is treated as `task: quick` with synthetic `lease_until = created_at + 4h`), so you can adopt them incrementally.

## Contract

- **Input:** recent messages from a dispatch channel, default `agent-dispatch`.
- **Output:** either claim and execute one open GitHub issue, or report idle.
- **Side effects:** GitHub issue comments/labels, branch and PR creation, and dispatch-channel status messages.
- **Scope:** GitHub-backed issues only. Ignore ad-hoc tasks, PR-review requests, and messages for other model handles unless the user explicitly extends the workflow.

## Configuration

Set these environment variables in the agent runtime:

| Variable | Default | Meaning |
|---|---|---|
| `AGENT_ID` | `codex-$(hostname)-1` | Unique visible worker name |
| `MODEL_HANDLE` | `@codex` | Dispatch mention this worker responds to |
| `AGENT_DISPATCH_CHANNEL` | `agent-dispatch` | Slack/channel name or connector target |
| `GH_TOKEN_AGENT_BOT` | none | Token used for issue comments, labels, branch pushes, and PR creation |

The repository must be the local checkout for `<OWNER>/<REPO>`, and `gh auth status` must work when `GH_TOKEN="$GH_TOKEN_AGENT_BOT"` is set.

## Presence Events

Post top-level lifecycle messages so operators can see which workers are online:

| Event | Format | When |
|---|---|---|
| `start` | `[${AGENT_ID}] start` | Session initialized and about to scan |
| `busy #N` | `[${AGENT_ID}] busy #N` | After winning the issue claim |
| `ready (...)` | `[${AGENT_ID}] ready (PR #N done)` | After completion or block |
| `end (...)` | `[${AGENT_ID}] end (reason)` | Before every planned exit |

In a noisy channel, thread presence under a pinned roster message instead of posting top-level events. Keep the dispatch scan focused on human/PM assignment messages.

## Workflow

### 0. Preflight

```bash
set -euo pipefail
export AGENT_ID="${AGENT_ID:-codex-$(hostname)-1}"
export MODEL_HANDLE="${MODEL_HANDLE:-@codex}"
export AGENT_DISPATCH_CHANNEL="${AGENT_DISPATCH_CHANNEL:-agent-dispatch}"

test -n "${GH_TOKEN_AGENT_BOT:-}" || { echo "GH_TOKEN_AGENT_BOT is required" >&2; exit 1; }
export GH_TOKEN="$GH_TOKEN_AGENT_BOT"
gh auth status
gh repo view <OWNER>/<REPO> --json nameWithOwner
```

Post `start` presence after preflight succeeds.

### 1. Read Recent Dispatch Messages

Read the most recent channel messages through your Slack/Teams/chat connector. Scan oldest-first so the earliest unclaimed dispatch wins.

Actionable message pattern:

```text
$MODEL_HANDLE #<issue-number>
```

A dispatch is actionable only if:

- the author is a human or PM agent, not this worker's own status message
- the GitHub issue exists and is open
- the issue has no winning claim comment matching `<!-- claim: ... -->`

### 2. Claim Atomically

Post a claim comment:

```bash
ISSUE_NUM=<issue-number>
case "$ISSUE_NUM" in ''|*[!0-9]*) echo "Invalid issue number: $ISSUE_NUM" >&2; exit 1 ;; esac

CLAIM_BODY="<!-- claim: ${AGENT_ID} --> Taking #${ISSUE_NUM} - ${AGENT_ID}"
CLAIM_FILE="$(mktemp)"
trap 'rm -f "$CLAIM_FILE"' EXIT
printf '%s\n' "$CLAIM_BODY" > "$CLAIM_FILE"

gh issue comment "$ISSUE_NUM" \
  --repo <OWNER>/<REPO> \
  --body-file "$CLAIM_FILE"
```

Wait three seconds, then re-read claim comments and sort by `(created_at, id)`:

```bash
gh api --paginate --slurp \
  "repos/<OWNER>/<REPO>/issues/${ISSUE_NUM}/comments?per_page=100" \
  | jq 'add | map(select(.body | startswith("<!-- claim:")) | {id, created_at, body}) | sort_by([.created_at, .id])'
```

You win if the first claim starts with `<!-- claim: ${AGENT_ID} -->`.

If you did not win, delete your losing claim comment when possible, post `end (lost claim race)`, and stop.

### 3. Mark Busy

Post:

- a thread reply on the original dispatch message: `Taking #${ISSUE_NUM} - ${AGENT_ID}`
- a presence event: `[${AGENT_ID}] busy #${ISSUE_NUM}`

Best-effort labels:

```bash
gh issue edit "$ISSUE_NUM" \
  --repo <OWNER>/<REPO> \
  --add-label "claimed-by:agent,status:in-flight" || true
```

Labels are optional. If your repo does not use them, remove or rename this step.

### 4. Execute The Issue

Fetch the issue:

```bash
gh issue view "$ISSUE_NUM" \
  --repo <OWNER>/<REPO> \
  --json number,title,body,labels,assignees,milestone,url
```

Then follow the normal repository workflow:

1. Read `AGENTS.md`, relevant skills, and the issue acceptance criteria.
2. Create a feature/fix branch, never committing directly to main.
3. Implement the smallest complete change.
4. Verify locally with the repo's documented checks.
5. Commit, push, and open a draft PR with `Closes #${ISSUE_NUM}`.

### 5. Report Completion Or Block

On success, post:

- thread reply: `Done #${ISSUE_NUM}. PR #<pr-number>`
- presence: `[${AGENT_ID}] ready (PR #<pr-number> done)`
- `end (one-shot complete)` if the session exits after one task

On block, post:

- thread reply: `Blocked: <one-sentence reason>`
- presence: `[${AGENT_ID}] ready (blocked #${ISSUE_NUM})`
- `end (blocked, escalated)` if the session exits

Do not delete the winning claim comment. It is the audit trail and prevents duplicate work.

## Out Of Scope For This Phase 1 Skeleton

The following are addressed in `agent-presence` + the per-CLI adapters (`dispatch-watcher-claude`, `dispatch-watcher-gemini`); adopt them after the one-issue claim → branch → PR → completion path works reliably here:

- Crash takeover via `<!-- takeover: ... -->` markers.
- Lease-based ownership with TTL renewal.
- Multi-agent work stealing with `(created_at, id)` tiebreak.
- Pinned-roster heartbeat / cache layer.
- Per-CLI adapters (Claude MCP, Gemini curl, Codex curl) sharing one
  `scripts/agent-presence-helpers.sh` library.

Long-running PM supervisor state machines remain out of scope here too — keep this skill focused on the dispatch loop.

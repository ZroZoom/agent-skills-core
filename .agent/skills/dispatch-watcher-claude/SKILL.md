---
name: dispatch-watcher-claude
description: "Claude Code adapter for the shared agent-presence protocol (for Codex CLI use [[dispatch-watcher]], for Gemini CLI use [[dispatch-watcher-gemini]]). Use on Claude session start to run pre-flight, claim Slack-dispatched issues (@claude #N), and emit lifecycle events. Triggers: Claude session start, /dispatch, /agent-presence, message addressed to @claude in the dispatch channel."
---

# Dispatch Watcher Skill — Claude Code Adapter

This is the **Claude Code-specific** adapter for the shared `agent-presence`
protocol. All shared logic (pre-flight, claim, lease, roster, takeover,
presence event format) lives in `.agent/skills/agent-presence/SKILL.md` and
`scripts/agent-presence-helpers.sh` — this file only contains Claude-specific
glue.

When this Claude Code session starts (or when explicitly triggered by
`@claude #<num>` in `<DISPATCH_CHANNEL>`), follow the workflow below.

## Contract

- **Input:** environment variables `AGENT_ID` (must start with `claude-`),
  `GH_TOKEN_CLAUDE_BOT`, `SLACK_BOT_TOKEN`, `ROSTER_MESSAGE_TS`,
  `ROSTER_CHANNEL_ID`, `REPO`. Slack MCP (`mcp__claude_ai_Slack__*`)
  available.
- **Output:** if a `@claude` dispatch is pending, claim and execute it;
  otherwise return idle. `start` is emitted only AFTER pre-flight passes
  (NOT on session boot — pre-flight uses tool calls itself, so emitting
  `start` first would create a circular requirement). After the shared
  helpers are sourced, `end` is emitted on session close via trap, with
  reason set in the `EXIT_REASON` shell variable (e.g., `declined`,
  `idle`, `error`, `task-done`).
- **Side effects:** posts comments on GitHub issues, opens branches/PRs,
  posts presence events in `<DISPATCH_CHANNEL>`.
- **Scope:** handle `@claude <num>` / `@claude #<num>` for issue
  implementation only. Ad-hoc `@claude <free-form>` messages and
  `@claude review #<PR>` (review dispatch) are explicitly OUT of scope
  for this adapter — the implementation workflow below assumes a GitHub
  issue, not a PR.

## Preconditions

1. `AGENT_ID` is set AND starts with `claude-`:

   ```bash
   if [ -z "${AGENT_ID:-}" ]; then
     echo "Set AGENT_ID, e.g. claude-${HOSTNAME}-wsl-1" >&2
     exit 1
   fi

   case "$AGENT_ID" in
     claude-*) ;;
     *)
       echo "AGENT_ID '$AGENT_ID' is not a claude-* identity; this adapter is Claude-only" >&2
       echo "Use the matching adapter for your model or fix AGENT_ID." >&2
       exit 1
       ;;
   esac
   ```

   `AGENT_ID` is otherwise treated as an opaque registry key beyond the
   model prefix.

2. `GH_TOKEN_CLAUDE_BOT` is set and works:

   ```bash
   if [ -z "${GH_TOKEN_CLAUDE_BOT:-}" ]; then
     echo "Set GH_TOKEN_CLAUDE_BOT before running the Claude adapter." >&2
     exit 1
   fi

   GH_TOKEN="$GH_TOKEN_CLAUDE_BOT" gh auth status
   ```

3. Slack MCP is reachable. The required channel is `<DISPATCH_CHANNEL>`
   (channel ID in `ROSTER_CHANNEL_ID` env). The pinned roster message TS
   is in `ROSTER_MESSAGE_TS`.

4. The shared protocol skill and helpers script are present and sourceable.
   Helpers expect `GH_TOKEN_BOT` (model-agnostic name) and `REPO`; the
   Claude adapter resolves `GH_TOKEN_BOT` from `GH_TOKEN_CLAUDE_BOT` and
   exports both before sourcing (a one-shot prefix assignment like
   `GH_TOKEN_BOT=... source ...` would only set the var for the `source`
   builtin itself, not for later function calls):

   ```bash
   if [ ! -f .agent/skills/agent-presence/SKILL.md ] || [ ! -f scripts/agent-presence-helpers.sh ]; then
     echo "Missing shared agent-presence dependencies (.agent/skills/agent-presence/SKILL.md or scripts/agent-presence-helpers.sh)" >&2
     exit 1
   fi

   export GH_TOKEN_BOT="$GH_TOKEN_CLAUDE_BOT"
   export REPO="<OWNER>/<REPO>"
   source scripts/agent-presence-helpers.sh
   ```

## Workflow

### 0. Wire shutdown wrapper

After preconditions pass and `scripts/agent-presence-helpers.sh` is sourced,
wire the trap-based shutdown wrapper before pre-flight or dispatch work so
an `end` event is emitted on every clean runtime exit path. Use an
`EXIT_REASON` shell variable the workflow updates throughout, so the trap
message is meaningful:

```bash
EXIT_REASON="boot-incomplete"  # default — overwritten as workflow progresses

emit_presence_end_once() {
  local reason="${EXIT_REASON}"
  trap - EXIT INT TERM HUP
  emit_presence end "${reason}" || true
}

trap 'emit_presence_end_once' EXIT
trap 'EXIT_REASON="interrupted (${EXIT_REASON})"; emit_presence_end_once; exit 130' INT
trap 'EXIT_REASON="terminated (${EXIT_REASON})"; emit_presence_end_once; exit 143' TERM
trap 'EXIT_REASON="hangup (${EXIT_REASON})"; emit_presence_end_once; exit 129' HUP
```

(MUST NOT use `exec` for any subsequent command — that would replace the
shell and prevent the trap from firing.)

### 1. Pre-flight check (mandatory)

```bash
if ! pre_flight_check; then
    EXIT_REASON="declined (pre-flight conflict)"
    echo "Pre-flight detected conflicts; aborting before claiming." >&2
    # Pre-flight already wrote details to stderr. Operator decides next move.
    # Note: NO `start` event was emitted — pre-flight uses tool calls itself,
    # so emitting `start` first would create a circular requirement. The trap
    # below emits `end (declined ...)` so the operator still sees a lifecycle
    # event.
    exit 0  # NOT 1 — this is intentional refusal, not an error
fi
```

Pre-flight covers:
1. Local git state check (no uncommitted changes from peer agents)
2. Read pinned roster (cache layer)
3. Cross-ref GitHub SSOT (in-flight issues, open PRs, claim comments with `lease_until > now`)
4. Reconcile + flag conflicts (legacy Phase 1 markers also detected via synthetic lease = created_at + 4h)
5. Worktree ownership advisory (if uncommitted changes exist that look like another agent's work, warn — operator should `git worktree add` for parallel work)

### 2. Emit `start` presence event

`start` is emitted AFTER pre-flight passes (not on session boot). Top-level
message in dispatch channel:

```bash
emit_presence start
EXIT_REASON="post-start"  # workflow proceeded past start
```

### 3. Read dispatch channel for `@claude` mentions

Use Claude's Slack MCP (NOT the shell helpers' read functions) so the
session has direct access to message content:

```
Tool: mcp__claude_ai_Slack__slack_read_channel
  channel_id: ${ROSTER_CHANNEL_ID}
  limit: 50
```

Filter messages matching the POSIX ERE pattern
`@claude[[:space:],:]+#?([0-9]+)` (the looser separator class catches
`@claude:`, `@claude,`, plus whitespace). Skip messages older than 1h to
avoid replaying stale dispatches. Scope is implementation only —
`@claude review #<PR>` patterns are NOT actionable in this adapter and
should be skipped silently.

### 4. For each actionable dispatch

Call the shared claim algorithm via helpers:

```bash
ISSUE_NUM=<extracted from regex>

# Default task type is 'quick' (30 min lease). For known long-running
# patterns (merge supervisor, content batch), declare 'standard' or 'long'
# upfront based on the issue body's "Acceptance Criteria" or "Estimate"
# section.
TASK_TYPE=quick  # or standard|long based on issue inspection

if claim_issue "$ISSUE_NUM" "$TASK_TYPE"; then
    # Won the race — proceed to execute
    # claim_issue already emitted `busy` and updated roster
    :
else
    # Lost the race or eventual-consistency failed — claim_issue handled cleanup
    continue  # try next dispatch in the loop
fi
```

### 5. Execute the task

Use the standard Claude Code task workflow per `CLAUDE.md`:

1. Read the issue body via `gh issue view`
2. Branch: `git checkout -b fix/issue-<num>-<slug>` or `feature/issue-<num>-<slug>`
3. Implement the change using Claude's Edit/Write tools
4. Verify locally per the project's `Verification After Changes` checklist
   (typecheck, lint, build, tests as applicable)
5. Commit on the feature branch with a descriptive message
6. Open PR with body `Closes #${ISSUE_NUM}` and capture the number:

   ```bash
   PR_URL=$(gh pr create --fill --body "Closes #${ISSUE_NUM}")
   PR_NUM=$(gh pr view "$PR_URL" --json number --jq '.number')
   ```

### 6. Renew lease during long execution

If the task is taking longer than `TTL/2` (15 min for `quick`, 1 h for
`standard`, 2 h for `long`), renew the lease BEFORE expiration:

```bash
renew_lease "$ISSUE_NUM"  # uses original TTL by default
```

Skip renewal once the PR is opened — the PR's commit activity itself
proves liveness, and the takeover gate's "no GH activity" condition will
fail safely for any peer agent.

### 7. Report completion

After the PR is opened (or task is blocked), update `EXIT_REASON` so the
trap-fired `end` event later carries useful context:

```bash
# Success path
emit_presence ready "PR #${PR_NUM} done"
EXIT_REASON="task-done (PR #${PR_NUM})"

# Block path
emit_presence ready "blocked #${ISSUE_NUM}: <one-sentence reason>"
# Also leave a :warning: thread reply on the original dispatch message
# (use mcp__claude_ai_Slack__slack_send_message with thread_ts)
```

The roster entry is automatically refreshed via `update_roster_chat_update`
(called inside `emit_presence`'s helper chain); operator sees the agent is
back to idle.

### 8. Idle exit

When the dispatch loop has no more actionable items, set the exit reason
and exit cleanly. The trap fires the `end` event with the right context:

```bash
EXIT_REASON="idle (no actionable dispatches)"
exit 0
```

## Slack MCP wiring (Claude-specific)

For CHANNEL READ + THREAD POST use Claude's Slack MCP tools directly:

| Action | MCP tool |
|---|---|
| Read 50 dispatch messages | `mcp__claude_ai_Slack__slack_read_channel` |
| Read a thread for context | `mcp__claude_ai_Slack__slack_read_thread` |
| Post a thread reply (`:eyes:`, `:warning:`) | `mcp__claude_ai_Slack__slack_send_message` with `thread_ts` |
| Post a top-level message | helpers' `emit_presence` (uses curl + xoxb token) |
| Update pinned roster | helpers' `update_roster_chat_update` (uses curl + chat.update) |

Why split between MCP and curl? The MCP tools work great for content
reads/replies but are not available in the helpers shell library. The
helpers use raw Slack Web API via curl for atomic operations
(`emit_presence`, `chat.update`) so any CLI can call them. Claude can use
either path for top-level posts; preferring helpers keeps the codebase
DRY.

## Required env summary

```bash
# Identity (per-machine)
export AGENT_ID="claude-${HOSTNAME}-wsl-1"  # or your environment slug

# Bot tokens (per-machine .envrc / .env.local — never committed)
export GH_TOKEN_CLAUDE_BOT="ghp_..."
export SLACK_BOT_TOKEN="xoxb-..."

# Repository (matches .agent/context/project-ids.md)
export REPO="<OWNER>/<REPO>"

# Roster pinned message (set up once per project; see project-ids.md)
export ROSTER_MESSAGE_TS="<ROSTER_MESSAGE_TS>"
export ROSTER_CHANNEL_ID="<DISPATCH_CHANNEL_ID>"

# Helpers expect a model-agnostic name
export GH_TOKEN_BOT="$GH_TOKEN_CLAUDE_BOT"

# Source helpers (REPO must already be exported)
if [ ! -f .agent/skills/agent-presence/SKILL.md ] || [ ! -f scripts/agent-presence-helpers.sh ]; then
  echo "Missing shared agent-presence dependencies (.agent/skills/agent-presence/SKILL.md or scripts/agent-presence-helpers.sh)" >&2
  exit 1
fi
source scripts/agent-presence-helpers.sh
```

## Out of scope

- **Auto-dispatch by PM** — separate spec
- **Polling loop after first task done** — Claude session exits after one
  dispatch cycle for now; the operator restarts when needed
- **Cost optimization** (idle exit at 30 min, polling backoff)
- **Cross-project dispatch** (`@claude other-repo#123`)
- **Slack DM dispatch** — channel only

## Shared protocol references

- `.agent/skills/agent-presence/SKILL.md` — shared protocol contract
- `scripts/agent-presence-helpers.sh` — shared shell library
- `.agent/skills/dispatch-watcher/SKILL.md` — Codex adapter (parallel to
  this one, same shape)
- `.agent/skills/dispatch-watcher-gemini/SKILL.md` — Gemini adapter

## Stop conditions (per shared agent-presence skill)

Stop and ask the human or PM agent when:

- Two active agents are editing the same non-generated file set
- A lease is expired but there is fresh PR/branch/commit activity
- The task requires overwriting uncommitted changes you did not make
- The roster and GitHub disagree in a way that changes ownership
- Secrets, tokens, or private Slack/GitHub identities would need to be exposed

If pre-flight detects any of these, exit cleanly (trap emits `end`) and
let the operator decide.

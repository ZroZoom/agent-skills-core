---
name: dispatch-watcher-gemini
description: "Gemini CLI adapter for the shared agent-presence protocol (for Claude Code use [[dispatch-watcher-claude]], for Codex CLI use [[dispatch-watcher]]). Use on Gemini session start to run pre-flight, claim Slack-dispatched issues (@gemini #N), and emit lifecycle events. Triggers: Gemini session start, /dispatch, /agent-presence, message addressed to @gemini in the dispatch channel."
---

# Dispatch Watcher Skill — Gemini CLI Adapter

This is the **Gemini CLI-specific** adapter for the shared `agent-presence`
protocol. All shared logic (pre-flight, claim, lease, roster, takeover,
presence event format) lives in `.agent/skills/agent-presence/SKILL.md` and
`scripts/agent-presence-helpers.sh` — this file only contains Gemini-specific
glue.

When this Gemini CLI session starts (or when explicitly triggered by
`@gemini #<num>` in `<DISPATCH_CHANNEL>`), follow the workflow below.

## Contract

- **Input:** environment variables `AGENT_ID` (starts with `gemini-`),
  `GH_TOKEN_GEMINI_BOT`, `SLACK_BOT_TOKEN`, `ROSTER_MESSAGE_TS`,
  `ROSTER_CHANNEL_ID`, `REPO`.
- **Output:** if a `@gemini` dispatch is pending, claim and execute it;
  otherwise return idle. `start` is emitted only AFTER pre-flight passes.
  `end` is emitted on session close via trap, with reason in `EXIT_REASON`.
- **Slack Connectivity:** Gemini CLI uses `curl`-based helpers in
  `scripts/agent-presence-helpers.sh` (which use `SLACK_BOT_TOKEN`) for both
  reading and writing to Slack. It does NOT use MCP tools.

## Preconditions

1. **Workspace name check (optional but recommended):**
   When running multiple Gemini sessions in parallel, the `seq` for
   `AGENT_ID` is conventionally derived from a worktree directory named
   `*-Gemini-<N>`. Skip this check if running a single-session setup.

   ```bash
   WS_SEQ=$(basename "$PWD" | grep -oP 'Gemini-\K[0-9]+' || echo "")
   if [ -z "$WS_SEQ" ]; then
     # Single-session setup — fall back to a default seq
     WS_SEQ=1
   fi
   export AGENT_ID="gemini-${HOSTNAME:-host}-wsl-${WS_SEQ}"
   ```

2. **Dependency check:**
   Ensure shared protocol files are present before proceeding:

   ```bash
   if [ ! -f .agent/skills/agent-presence/SKILL.md ] || [ ! -f scripts/agent-presence-helpers.sh ]; then
     echo "Missing shared agent-presence dependencies (.agent/skills/agent-presence/SKILL.md or scripts/agent-presence-helpers.sh)" >&2
     exit 1
   fi
   ```

3. **Tokens and repo:** `GH_TOKEN_GEMINI_BOT`, `SLACK_BOT_TOKEN`, and `REPO`
   must be set. `GH_TOKEN_BOT` is resolved from `GH_TOKEN_GEMINI_BOT`:

   ```bash
   export GH_TOKEN_BOT="$GH_TOKEN_GEMINI_BOT"
   export REPO="<OWNER>/<REPO>"
   source scripts/agent-presence-helpers.sh
   ```

## Workflow

### 0. Wire shutdown wrapper

Use the trap-based wrapper to ensure `end` event emission:

```bash
EXIT_REASON="boot-incomplete"

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

### 1. Pre-flight check

Run `pre_flight_check`. If it fails, set
`EXIT_REASON="declined (pre-flight conflict)"` and exit 0.

### 2. Emit `start` event

```bash
emit_presence start
EXIT_REASON="post-start"
```

### 3. Read dispatch channel for `@gemini` mentions

Use `curl` via helper (or direct if helper read is restricted) to check
`<DISPATCH_CHANNEL>` for messages matching:
`(^|[[:space:]])@gemini\b\s*#?([0-9]+)\b`

Filter out messages older than 1h.

### 4. Claim and execute

For a matched `<issue_num>`, call `claim_issue "$issue_num" quick`.

If successful, follow the implementation workflow:
1. `git checkout -b feature/issue-<num>-<slug>`
2. Implement and verify per the project's `Verification After Changes`
   checklist
3. Open PR with `Closes #<num>`

### 5. Report completion

Update roster with `workspace_path`:
`emit_presence ready "PR #${PR_NUM} done" "{\"workspace_path\": \"$PWD\"}"`

Update `EXIT_REASON="task-done (PR #${PR_NUM})"`.

## Required env summary

```bash
export AGENT_ID="gemini-${HOSTNAME}-wsl-1"
export GH_TOKEN_GEMINI_BOT="ghp_..."
export SLACK_BOT_TOKEN="xoxb-..."
export REPO="<OWNER>/<REPO>"
export ROSTER_MESSAGE_TS="<ROSTER_MESSAGE_TS>"
export ROSTER_CHANNEL_ID="<DISPATCH_CHANNEL_ID>"
export GH_TOKEN_BOT="$GH_TOKEN_GEMINI_BOT"

source scripts/agent-presence-helpers.sh
```

## Shared protocol references

- `.agent/skills/agent-presence/SKILL.md` — shared protocol contract
- `scripts/agent-presence-helpers.sh` — shared shell library
- `.agent/skills/dispatch-watcher-claude/SKILL.md` — Claude adapter
- `.agent/skills/dispatch-watcher/SKILL.md` — Codex adapter

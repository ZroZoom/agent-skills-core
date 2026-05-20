---
name: agent-presence
description: "Shared multi-agent presence and claim protocol. Use before any coding agent starts work in this repo, when coordinating Claude/Codex/Gemini sessions, or when checking who is already working on the repository. Triggers: agent session start, check agent presence, agent coordination, who's working on repo."
---

# Agent Presence Skill

Shared protocol for answering: "who is working on this repository right now,
what are they doing, and when may another agent take over?"

This skill is deliberately tool-agnostic. Claude Code, Codex CLI, Gemini CLI,
and future workers use this as the common contract. Each CLI still needs a
thin adapter (see `dispatch-watcher-claude`, `dispatch-watcher-gemini`,
`dispatch-watcher`) for loading the skill, posting Slack messages, and wiring
shutdown hooks.

## Contract

- **Input:** `AGENT_ID`, access to the project's dispatch channel
  (`<DISPATCH_CHANNEL>`), and GitHub access through `gh` (read for pre-flight,
  write for claims/updates).
- **Output:** a pre-flight status decision before starting work, plus optional
  presence/claim updates.
- **Durable source of truth:** GitHub issue comments, open PRs, branches,
  commits, and labels.
- **Cache / operator view:** pinned Slack roster message. The roster is never a
  lock and may be stale.
- **Scope:** coding agents only. PM automation may reuse the same protocol but
  has additional heartbeat/leader-election rules — out of scope here.

## Identity

Every agent session must set:

```bash
AGENT_ID="<model>-<machine>-<environment>-<seq>"
# examples:
# codex-lenovo-wsl-1
# claude-mbp-macos-1
# gemini-hpm01-ubuntu-1
```

`environment` is one of `wsl|windows|ubuntu|macos|cloud`. Pick the most specific
that uniquely describes the runtime — `wsl` is preferred over `ubuntu` when the
agent runs inside WSL2.

Treat `AGENT_ID` as an opaque registry key. Do not infer authorization from the
string. If tooling needs display parsing, use:

- first token = model
- last token = sequence number
- second-last token = environment
- all middle tokens joined with `-` = machine

## Required Pre-Flight

Run this before the first dispatch, claim, or substantive work action in a
coding task, including before proposing a PR or claiming an issue. Minimal
local status reads required by this pre-flight are allowed.

1. Verify local state:
   ```bash
   git branch --show-current
   git status --short
   ```
   Do not overwrite unrelated user or peer-agent changes.

2. Read the pinned roster message from `<DISPATCH_CHANNEL>`, if present.
   It is a fast cache only.

3. Bind GitHub CLI to the current agent's bot token before every canonical
   presence query. Adapters may export `GH_TOKEN` once or prefix each command,
   but the shared pre-flight must never depend on the operator's ambient
   `gh auth` session:
   ```bash
   : "${GH_TOKEN:?Set GH_TOKEN to this agent's bot token before GitHub presence queries}"
   ```

4. Cross-check GitHub, which is the truth layer. The list commands below are
   quick discovery helpers only; ownership decisions must not depend on their
   capped result set.
   ```bash
   GH_TOKEN="${GH_TOKEN:?}" gh issue list -R <OWNER>/<REPO> \
     --state open \
     --limit 200 \
     --json number,title,labels,assignees,updatedAt

   GH_TOKEN="${GH_TOKEN:?}" gh pr list -R <OWNER>/<REPO> \
     --state open \
     --limit 200 \
     --json number,title,headRefName,headRefOid,author,updatedAt,isDraft
   ```

5. For a concrete dispatch target, always fetch that issue's comments directly
   even when labels are missing. For general pre-flight/takeover reconciliation,
   prefer a GitHub Search path that returns only open issues whose comments
   contain `<!-- claim:` / `<!-- takeover:` markers; do not scan every open
   issue unless search is unavailable or the search result cap is reached.
   GitHub search is capped at 1000 results; if either marker search returns
   exactly 1000 issue numbers, treat the result as truncated and fall back to
   a paginated open-issue scan before reconciling ownership. Labels,
   assignees, titles, and roster `current_task` values can prioritize
   candidates, but they are not the source of truth. Inspect each candidate
   for active claim and takeover markers:
   ```bash
   {
     GH_TOKEN="${GH_TOKEN:?}" gh search issues \
       '"<!-- claim:" in:comments repo:<OWNER>/<REPO> state:open' \
       --limit 1000 --json number --jq '.[].number'
     GH_TOKEN="${GH_TOKEN:?}" gh search issues \
       '"<!-- takeover:" in:comments repo:<OWNER>/<REPO> state:open' \
       --limit 1000 --json number --jq '.[].number'
   } | sort -u |
   while read -r issue_num; do
     GH_TOKEN="${GH_TOKEN:?}" gh api --paginate --slurp \
       "repos/<OWNER>/<REPO>/issues/${issue_num}/comments" \
       --jq '[.[][] | select(.body | test("^\\s*<!-- (claim|takeover):"))
              | {id, created_at, updated_at, body}] | sort_by(.created_at, .id)'
   done
   ```

   Per-issue canonical marker read:
   ```bash
   GH_TOKEN="${GH_TOKEN:?}" gh api --paginate --slurp \
     "repos/<OWNER>/<REPO>/issues/<num>/comments" \
     --jq '[.[][] | select(.body | test("^\\s*<!-- (claim|takeover):")) | {id, created_at, updated_at, body}] | sort_by(.created_at, .id)'
   ```

6. Verify local worktree ownership. A branch checkout changes `HEAD` for every
   agent using the same filesystem path. Before any checkout, merge, rebase,
   commit, generated-file refresh, or cleanup, confirm no active peer-agent
   claim/roster entry is using this checkout. If overlap is possible, create
   a separate `git worktree` for your task.

7. Decide:
   - If another agent has an active lease or fresh PR/commit activity in the
     same area, do not start. Post an acknowledgement or pick a disjoint task.
   - If the roster says an agent is busy but GitHub shows no active work and
     the lease is expired, mark the roster entry `last_event: "unknown"` with
     a `stale_reason` before continuing.
   - If there is no overlap, emit `start` or update your roster entry and begin.

## Presence Events

Presence communicates availability to humans and peer agents. It does not
grant ownership of a task.

| Event | Meaning |
|---|---|
| `start` | Session is online and has completed pre-flight. |
| `busy` | Session is actively working on a task or draft. |
| `ready` | Session is idle and may accept work. |
| `standby` | Session is idle and may exit soon. |
| `pause` | Session is temporarily unavailable but may resume. |
| `end` | Session is closing cleanly. |
| `unknown` | Last known session is no longer trustworthy; explain in `stale_reason`. |

Top-level fallback message format:

```text
<emoji> [<AGENT_ID>] <event> [context]
```

Examples:

```text
:large_green_circle: [codex-lenovo-wsl-1] start
:large_yellow_circle: [codex-lenovo-wsl-1] busy #2186
:large_green_circle: [codex-lenovo-wsl-1] ready (PR #2190 done)
:red_circle: [codex-lenovo-wsl-1] end (operator stopped)
```

When Slack supports it, prefer updating the pinned roster message instead of
posting many top-level lifecycle lines.

## Pinned Roster

The roster is a Slack-pinned cache for fast reads and human visibility. It
must be overwritten only after GitHub cross-check, not from Slack silence
alone.

Recommended body:

````markdown
Agent roster (cache, not lock)
Updated: 2026-05-10T13:25:00Z

```json
{
  "version": 1,
  "updated_at": "2026-05-10T13:25:00Z",
  "agents": [
    {
      "agent_id": "gemini-lenovo-wsl-1",
      "last_event": "busy",
      "last_seen_at": "2026-05-10T13:24:50Z",
      "current_task": "#2186",
      "lease_until": "2026-05-10T13:54:50Z",
      "stale_reason": null,
      "workspace_path": "/home/dev/<REPO>"
    }
  ]
}
```
````

Roster rules:

- `presence_stale_after = 20m`; `updated_at` older than that means "stale
  cache"; verify GitHub before trusting it. This roster threshold is separate
  from GitHub claim lease TTL.
- Legacy `last_seen_at` values use the same `presence_stale_after = 20m`
  threshold and may mark an agent stale only after GitHub shows no fresh PR,
  branch, commit, or claim renewal. Stale agents get
  `last_event: "unknown"` plus `stale_reason: "stale Xm"` (the age string
  lives in `stale_reason`, never in `last_event`).
- If two agents update concurrently, Slack `chat.update` is last-writer-wins,
  so the writer must re-read the pinned message immediately before writing,
  merge peer entries into its own snapshot, and only then post the update.
  Squashed entries self-heal in the next pre-flight cross-ref against GitHub.
- The roster is allowed to lag; active GitHub lease/activity wins over stale
  roster data.

## GitHub Claim Lease

GH-backed work must be claimed with a durable issue/PR comment. Slack
reactions and roster entries are visibility only.

**Ordering invariant.** Posting a claim is forbidden until Required Pre-Flight
step 7 returns no-overlap. Adapters that bypass steps 4-6 (cross-checking
GitHub for active leases, in-flight issues, fresh PR/commit activity, and
peer worktree ownership) are protocol violations — even if the roster cache
shows a free slot.

Initial claim marker:

```markdown
<!-- claim: <AGENT_ID>; lease_until: <ISO8601>; renewed_at: <ISO8601>; task: <type>; branch: <head-ref-or-none>; pr: <number-or-none> -->
Taking #N - <AGENT_ID> (branch: <head-ref-or-none>, PR: <number-or-none>)
```

`task` is one of:

- `quick`: `lease_until = now + 30min` (default for ad-hoc fixes, doc edits)
- `standard`: `lease_until = now + 2h` (typical feature work)
- `long`: `lease_until = now + 4h` (declared upfront with a short reason in
  the visible comment text — for merge supervisor, content batch, large
  refactor)

`branch` and `pr` are the canonical mapping keys for fresh GitHub activity.
Use `none` before branch/PR creation, then PATCH the marker before the first
push or immediately after opening the PR.

Renewal cadence: every `min(TTL/2, 15min)` while executing — refreshes the
GitHub claim AND the roster entry so a healthy agent does not look stale.

**Backwards compatibility (Phase 1 markers):** legacy claim comments without
`lease_until`/`renewed_at`/`task`/`branch`/`pr` are treated as `task: quick`
with synthetic `lease_until = created_at + 4h`, preserving the legacy manual
takeover window, and unknown branch/PR mapping. Adapters that touch a legacy
marker during a renewal MUST upgrade it in place to the full format.

Renew by editing the original comment, not by adding a second claim:

```bash
GH_TOKEN="${GH_TOKEN:?}" gh api -X PATCH \
  "repos/<OWNER>/<REPO>/issues/comments/<comment_id>" \
  -f body="$UPDATED_CLAIM_BODY"
```

Claim race:

1. Post the claim comment.
2. Wait 3 seconds.
3. Re-read all `<!-- claim:` and `<!-- takeover:` comments. Use the explicit
   query so adapters implement identical sort/select logic:

   ```bash
   GH_TOKEN="${GH_TOKEN:?}" gh api --paginate --slurp \
     "repos/<OWNER>/<REPO>/issues/<num>/comments" \
     --jq '[.[][] | select(.body | test("^\\s*<!-- (claim|takeover):"))
                | {id, created_at, body}]
           | sort_by(.created_at, .id)'
   ```

   If your own freshly posted comment is missing from the response, GitHub's
   eventual-consistency window has not closed yet — wait another 2 seconds
   and retry the read up to 3 times before treating the race as resolved.
4. Sort by `(created_at, id)`.
5. Resolve the active lease stream:
   - first valid active claim by `(created_at, id)` wins when no takeover exists
   - first valid active takeover by `(created_at, id)` supersedes the stale
     claim it names via `after:`
   - any unexpired takeover marker blocks fresh claims just like an unexpired
     claim marker
6. Losers delete their own claim comments.

## Takeover

Never take over from an agent because the Slack roster is silent by itself.

Before evaluating takeover, verify the task is still open and not explicitly
blocked for human decision. If that prerequisite fails, stop instead of
taking over.

Takeover is allowed only when all 3 gate conditions are true:

- `lease_until < now`
- no open PR/draft PR/branch/commit activity for the marker's `branch`/`pr`
  exists that shows fresh progress
- no Slack presence message from that `AGENT_ID` within the relevant TTL
  window (roster `last_seen_at` is only a cache/optimization)

If Slack presence history cannot be read and the roster is stale/untrusted,
automatic takeover is disallowed; emit `pause`/blocked and wait for human
decision.

Takeover marker:

```markdown
<!-- takeover: <AGENT_ID>; after: <PREVIOUS_AGENT_ID>; lease_until: <ISO8601>; renewed_at: <ISO8601>; task: <type>; branch: <head-ref-or-none>; pr: <number-or-none> -->
Taking over #N from <PREVIOUS_AGENT_ID> - <AGENT_ID> (branch: <head-ref-or-none>, PR: <number-or-none>)
```

Active lease selector:

- Parse both `claim` and `takeover` markers.
- If one or more unexpired takeover markers exist, the first valid takeover
  by `(created_at, id)` is the current owner and supersedes the stale claim
  named via `after:`.
- If no unexpired takeover exists, the first valid active claim by
  `(created_at, id)` is the current owner.
- Expired takeover markers do not block a fresh claim unless there is fresh
  GitHub activity or presence from their holder.

## Adapter Responsibilities

Each CLI adapter must define:

- how the skill is loaded at session start
- how Slack channel and pinned roster are found
- how `start`, `busy`, `ready`, `pause`, `standby`, and `end` are emitted
- whether a shell `trap` / launcher wrapper exists for best-effort `end`
- which GitHub token env var to use (`GH_TOKEN_CODEX_BOT`,
  `GH_TOKEN_CLAUDE_BOT`, `GH_TOKEN_GEMINI_BOT`, etc.)
- how to renew leases during long-running operations
- how to use a launcher wrapper without `exec` when emitting best-effort `end`

Shutdown hooks are best-effort only. They do not catch hard kill, runtime
crash, host power loss, or network loss. Lease expiry plus GitHub activity
checks are the recovery mechanism.

## Stop Conditions

Stop and ask the human or PM agent when:

- two active agents are editing the same non-generated file set
- another active agent is using the same local checkout and your next step
  would switch branches, merge, rebase, commit, regenerate tracked files, or
  clean files
- a lease is expired but there is fresh PR/branch/commit activity
- the task requires overwriting uncommitted changes you did not make
- the roster and GitHub disagree in a way that changes ownership
- secrets, tokens, or private Slack/GitHub identities would need to be exposed

## Shared Library

The shared shell library lives at `scripts/agent-presence-helpers.sh`. Adapters
source it once at startup and delegate all shared logic (`pre_flight_check`,
`claim_issue`, `renew_lease`, `emit_presence`, `update_roster_chat_update`).
Required env vars and defaults are documented in the script header.

## Placeholders

This skill references these placeholders (defined in
`.agent/context/project-ids.md`):

- `<OWNER>/<REPO>` — GitHub repository
- `<DISPATCH_CHANNEL>` — Slack channel name (e.g. `#agent-dispatch`)
- `<DISPATCH_CHANNEL_ID>` — Slack channel ID (e.g. `C0B25SWSUKS`)
- `<ROSTER_MESSAGE_TS>` — pinned roster message timestamp

## References

- Per-CLI adapters: `dispatch-watcher-claude`, `dispatch-watcher-gemini`,
  `dispatch-watcher` (Codex)
- Shared library: `scripts/agent-presence-helpers.sh`

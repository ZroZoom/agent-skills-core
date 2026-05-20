#!/usr/bin/env bash
# scripts/agent-presence-helpers.sh
#
# Shared shell library for the multi-agent presence + lease-based claim
# protocol defined in `.agent/skills/agent-presence/SKILL.md` (§§ Pre-Flight,
# GitHub Claim Lease, Takeover).
#
# Sourced by per-CLI adapters (dispatch-watcher, dispatch-watcher-claude,
# dispatch-watcher-gemini). Adapters MUST source this file at startup,
# wire the trap-based shutdown wrapper, and delegate all shared logic here.
#
# Usage from any adapter:
#
#   source scripts/agent-presence-helpers.sh
#   adapter_main() {
#     if pre_flight_check; then
#       emit_presence start
#       # adapter-specific dispatch loop ...
#       if claim_issue 1859 quick; then
#         # work the task
#         emit_presence ready "PR #${PR_NUM} done"
#       fi
#     fi
#   }
#   shutdown_wrapper adapter_main
#
# Required env vars (set by adapter):
#   AGENT_ID            <model>-<machine>-<environment>-<seq>
#   GH_TOKEN_BOT        per-model bot PAT (resolved per adapter from
#                       GH_TOKEN_CODEX_BOT / GH_TOKEN_CLAUDE_BOT / GH_TOKEN_GEMINI_BOT)
#   SLACK_BOT_TOKEN     xoxb-* token (Slack Web API access)
#   ROSTER_MESSAGE_TS   pinned roster message timestamp (Slack ts format)
#   ROSTER_CHANNEL_ID   Slack channel ID for the roster (e.g., C0B25SWSUKS)
#
# Optional env vars (defaults provided):
#   DISPATCH_CHANNEL_ID default = ROSTER_CHANNEL_ID
#   REPO                no default — adapter MUST set this to the project's
#                       <OWNER>/<REPO> (e.g. `acme/widget`)
#
# Shutdown wrapper note: this script does NOT use `exec` for the inner command
# in any wrapper — the trap-based `end` emission requires the shell process to
# survive long enough to fire the trap.
#
# Shell options note: this library is SOURCED, so it does NOT set global
# `set -uo pipefail` — that would alter the caller's shell options and break
# adapters that rely on different settings (e.g., `set +u` to allow optional
# vars). Each public function uses local strict checks where needed via
# explicit `${VAR:?msg}` and explicit return-on-failure paths.

# ---------- Defaults ----------

: "${DISPATCH_CHANNEL_ID:=${ROSTER_CHANNEL_ID:-}}"
# ---------- Internal: env validation ----------

_aph_require_env() {
    local name="$1"
    if [ -z "${!name:-}" ]; then
        echo "agent-presence-helpers: missing required env var '$name'" >&2
        return 1
    fi
}

_aph_require_command() {
    local name="$1"
    if ! command -v "$name" >/dev/null 2>&1; then
        echo "agent-presence-helpers: missing required command '$name'" >&2
        return 1
    fi
}

_aph_validate_deps() {
    local cmd
    for cmd in jq gh curl git awk date sed grep head sleep; do
        _aph_require_command "$cmd" || return 1
    done
    return 0
}

_aph_validate_core_env() {
    _aph_require_env AGENT_ID || return 1
    _aph_require_env GH_TOKEN_BOT || return 1
    _aph_require_env SLACK_BOT_TOKEN || return 1
    _aph_require_env ROSTER_MESSAGE_TS || return 1
    _aph_require_env ROSTER_CHANNEL_ID || return 1
    _aph_require_env REPO || return 1
    _aph_validate_deps || return 1
    return 0
}

_aph_restore_trap() {
    local signal="$1"
    local previous="$2"
    if [ -n "$previous" ]; then
        eval "$previous"
    else
        trap - "$signal"
    fi
}

# ---------- Internal: ISO 8601 + epoch helpers ----------

_aph_now_iso() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

_aph_now_epoch() {
    date -u +%s
}

_aph_iso_to_epoch() {
    # GNU date — works on Linux/WSL; macOS would need `gdate` from coreutils
    date -d "$1" +%s 2>/dev/null
}

_aph_lease_until_iso() {
    local ttl_sec="$1"
    date -u -d "+${ttl_sec} seconds" +"%Y-%m-%dT%H:%M:%SZ"
}

# ---------- Internal: emoji per event ----------

_aph_emoji_for_event() {
    case "$1" in
        start)             echo "🟢" ;;
        busy)              echo "🟡" ;;
        ready)             echo "🟢" ;;
        standby)           echo "🟠" ;;
        pause)             echo "⚪" ;;
        end)               echo "🔴" ;;
        unknown)           echo "❔" ;;
        *)                 echo "•" ;;
    esac
}

# ---------- Internal: Slack Web API ----------

_aph_slack_api() {
    # _aph_slack_api <method> <json-payload>
    # Returns Slack response on stdout; non-zero exit on transport failure only.
    # Caller must inspect .ok in the JSON for API-level errors.
    local method="$1"
    local payload="$2"
    curl -sS --fail-with-body -X POST "https://slack.com/api/${method}" \
        -H "Authorization: Bearer ${SLACK_BOT_TOKEN}" \
        -H "Content-Type: application/json; charset=utf-8" \
        --data-binary "$payload"
}

_aph_response_error() {
    local resp="$1"
    if [ -z "$resp" ]; then
        echo "empty response"
        return 0
    fi
    echo "$resp" | jq -r '.error // "unknown"' 2>/dev/null || echo "non-JSON response"
}

# ---------- Public: emit_presence ----------

# emit_presence <event> [<context>]
# Posts a top-level Slack message in DISPATCH_CHANNEL_ID.
# Format: "<emoji> [<AGENT_ID>] <event> [<context>]"
emit_presence() {
    local event="${1:?emit_presence: event required}"
    local context="${2:-}"
    _aph_validate_core_env || return 1
    local channel_id="${DISPATCH_CHANNEL_ID:-${ROSTER_CHANNEL_ID:-}}"
    if [ -z "$channel_id" ]; then
        echo "emit_presence: DISPATCH_CHANNEL_ID or ROSTER_CHANNEL_ID required" >&2
        return 1
    fi

    local emoji msg
    emoji=$(_aph_emoji_for_event "$event")
    if [ -n "$context" ]; then
        if [ "$event" = "busy" ]; then
            msg="${emoji} [${AGENT_ID}] ${event} ${context}"
        else
            msg="${emoji} [${AGENT_ID}] ${event} (${context})"
        fi
    else
        msg="${emoji} [${AGENT_ID}] ${event}"
    fi

    local payload
    payload=$(jq -nc --arg ch "$channel_id" --arg text "$msg" \
        '{channel: $ch, text: $text}')

    local resp
    if ! resp=$(_aph_slack_api chat.postMessage "$payload"); then
        echo "emit_presence: chat.postMessage transport failure" >&2
        return 1
    fi
    if ! echo "$resp" | jq -e '.ok == true' >/dev/null 2>&1; then
        echo "emit_presence: chat.postMessage failed: $(_aph_response_error "$resp")" >&2
        return 1
    fi
    return 0
}

# ---------- Public: read_pinned_roster ----------

# read_pinned_roster
# Stdout: roster JSON object (the fenced block from the pinned message).
# If the pinned message has no JSON block or is empty, returns the bootstrap
# empty roster: {"version": 1, "updated_at": null, "agents": []}.
read_pinned_roster() {
    _aph_validate_core_env || return 1

    local resp
    if ! resp=$(curl -sS --fail-with-body "https://slack.com/api/conversations.history?channel=${ROSTER_CHANNEL_ID}&latest=${ROSTER_MESSAGE_TS}&inclusive=true&limit=1" \
        -H "Authorization: Bearer ${SLACK_BOT_TOKEN}"); then
        echo "read_pinned_roster: conversations.history transport failure" >&2
        return 1
    fi
    if ! echo "$resp" | jq -e '.ok == true' >/dev/null 2>&1; then
        echo "read_pinned_roster: conversations.history failed: $(_aph_response_error "$resp")" >&2
        return 1
    fi
    if ! echo "$resp" | jq -e --arg ts "$ROSTER_MESSAGE_TS" \
        '(.messages | length) == 1 and .messages[0].ts == $ts' >/dev/null 2>&1; then
        echo "read_pinned_roster: roster message ts mismatch or missing message" >&2
        return 1
    fi

    local body
    body=$(echo "$resp" | jq -r '.messages[0].text // ""')

    # Prefer the first ```json block. Fall back to the first plain fence only
    # when no JSON-labelled fence is present, for compatibility with early
    # helper drafts.
    local json has_json_fence
    has_json_fence=$(echo "$body" | awk '
        /^[[:space:]]*```json[[:space:]]*$/ {found=1}
        END {print found ? "1" : "0"}
    ')
    if [ "$has_json_fence" = "1" ]; then
        json=$(echo "$body" | awk '
            /^[[:space:]]*```json[[:space:]]*$/ {if (!done) flag=1; next}
            /^[[:space:]]*```[[:space:]]*$/ && flag {done=1; exit}
            flag {print}
        ')
    else
        json=$(echo "$body" | awk '
            /^[[:space:]]*```[[:space:]]*$/ {
                if (flag) {done=1; exit}
                if (!done) {flag=1; next}
            }
            flag {print}
        ')
    fi

    if [ -z "$json" ]; then
        echo '{"version": 1, "updated_at": null, "agents": []}'
    else
        if ! echo "$json" | jq -e 'type == "object"' >/dev/null 2>&1; then
            echo "read_pinned_roster: roster fenced block is not valid JSON object" >&2
            return 1
        fi
        echo "$json"
    fi
}

# ---------- Public: update_roster_chat_update ----------

# update_roster_chat_update
# Reads pinned roster, mutates own AGENT_ID entry, posts via chat.update.
# Implements merge-on-write per spec §5.5: re-read immediately before posting,
# merge peer entries, then post. Squashed updates self-heal in next pre-flight.
#
# Args (all optional, override own entry fields):
#   --event <event>             default = previous own.last_event or "start"
#   --task #<num>               default = previous own.current_task
#   --lease-until <iso>         default = previous own.lease_until
#   --stale-reason <text>       default = null
#   --clear-task                clear current_task and lease_until
update_roster_chat_update() {
    _aph_validate_core_env || return 1

    local event="" task="" lease_until="" stale_reason="" clear_task=0
    while [ $# -gt 0 ]; do
        case "$1" in
            --event)
                if [ $# -lt 2 ]; then echo "update_roster_chat_update: --event requires a value" >&2; return 1; fi
                event="$2"; shift 2 ;;
            --task)
                if [ $# -lt 2 ]; then echo "update_roster_chat_update: --task requires a value" >&2; return 1; fi
                task="$2"; shift 2 ;;
            --lease-until)
                if [ $# -lt 2 ]; then echo "update_roster_chat_update: --lease-until requires a value" >&2; return 1; fi
                lease_until="$2"; shift 2 ;;
            --stale-reason)
                if [ $# -lt 2 ]; then echo "update_roster_chat_update: --stale-reason requires a value" >&2; return 1; fi
                stale_reason="$2"; shift 2 ;;
            --clear-task)    clear_task=1; shift ;;
            *) echo "update_roster_chat_update: unknown arg '$1'" >&2; return 1 ;;
        esac
    done

    # Step 1: re-read RIGHT BEFORE writing (merge-on-write)
    local roster
    roster=$(read_pinned_roster) || return 1

    # Step 2: mutate own entry
    local now_iso
    now_iso=$(_aph_now_iso)

    local new_roster
    if ! new_roster=$(echo "$roster" | jq --arg aid "$AGENT_ID" \
        --arg now "$now_iso" \
        --arg event "$event" \
        --arg task "$task" \
        --arg lease "$lease_until" \
        --arg stale "$stale_reason" \
        --argjson clear "$clear_task" \
        '
        if type != "object" then
            error("roster must be object")
        else
            .updated_at = $now |
            .agents = (
                (.agents // []) as $existing |
                ($existing | map(select(.agent_id != $aid))) as $others |
                ($existing | map(select(.agent_id == $aid)) | .[0] // {agent_id: $aid}) as $own |
                $own
                | .last_event = (if $event != "" then $event else (.last_event // "start") end)
                | .last_seen_at = $now
                | (if $clear == 1 then .current_task = null | .lease_until = null
                   elif $task != "" then .current_task = $task
                   else . end)
                | (if $clear == 1 then . elif $lease != "" then .lease_until = $lease else . end)
                | (if $stale != "" then .stale_reason = $stale else .stale_reason = null end)
                | . as $updated
                | $others + [$updated]
            )
        end
        '); then
        echo "update_roster_chat_update: failed to merge roster JSON" >&2
        return 1
    fi

    # Step 3: render full message body (human summary + JSON block)
    local body
    # Slack mrkdwn uses *bold* (single asterisks), not **bold** (would render
    # as literal asterisks). Per Copilot review.
    body=$(printf '📋 *Agent Roster* (auto-updated by `agent-presence` skill — do not edit manually)\n\n_Updated: %s_\n\n```json\n%s\n```\n\nSchema reference: spec §5.5. Pre-flight contract: every coding agent verifies this roster + GH SSOT before its first dispatch, claim, or substantive work action.\n' \
        "$now_iso" \
        "$new_roster")

    local payload
    payload=$(jq -nc --arg ch "$ROSTER_CHANNEL_ID" --arg ts "$ROSTER_MESSAGE_TS" --arg text "$body" \
        '{channel: $ch, ts: $ts, text: $text}')

    local resp
    if ! resp=$(_aph_slack_api chat.update "$payload"); then
        echo "update_roster_chat_update: chat.update transport failure" >&2
        return 1
    fi
    if ! echo "$resp" | jq -e '.ok == true' >/dev/null 2>&1; then
        echo "update_roster_chat_update: chat.update failed: $(_aph_response_error "$resp")" >&2
        return 1
    fi
    return 0
}

# ---------- Public: cross_ref_gh ----------

# cross_ref_gh
# Stdout: JSON snapshot of GitHub state used by pre_flight_check + takeover_check.
# Schema: { in_flight_issues: [...], open_prs: [...], claim_comments: [...] }
cross_ref_gh() {
    _aph_validate_core_env || return 1

    local repo_owner repo_name snapshot in_flight open_prs claims
    local open_claim_issues open_issue_snapshot open_issue_page
    local open_issue_cursor open_issue_has_next
    local comments_since repo_comments
    repo_owner="${REPO%%/*}"
    repo_name="${REPO#*/}"
    if [ -z "$repo_owner" ] || [ -z "$repo_name" ] || [ "$repo_owner" = "$repo_name" ]; then
        echo "cross_ref_gh: REPO must be owner/name, got '$REPO'" >&2
        return 1
    fi

    if ! snapshot=$(GH_TOKEN="$GH_TOKEN_BOT" gh api graphql \
        -F owner="$repo_owner" \
        -F name="$repo_name" \
        -f query='
query($owner: String!, $name: String!) {
  repository(owner: $owner, name: $name) {
    issues(first: 100, states: OPEN, filterBy: {labels: ["status:in-flight"]}, orderBy: {field: UPDATED_AT, direction: DESC}) {
      nodes {
        number
        title
        updatedAt
        labels(first: 20) { nodes { name } }
        assignees(first: 20) { nodes { login } }
      }
    }
    pullRequests(first: 100, states: OPEN, orderBy: {field: UPDATED_AT, direction: DESC}) {
      nodes {
        number
        title
        headRefName
        author { login }
        updatedAt
        isDraft
      }
    }
  }
}' 2>/dev/null); then
        echo "cross_ref_gh: failed to fetch GitHub snapshot" >&2
        return 1
    fi

    if ! echo "$snapshot" | jq -e '
        ((.errors // []) | length == 0) and
        (.data.repository.issues.nodes | type == "array") and
        (.data.repository.pullRequests.nodes | type == "array")
    ' >/dev/null 2>&1; then
        echo "cross_ref_gh: invalid GitHub GraphQL response" >&2
        echo "$snapshot" | jq -r '(.errors // [])[]? | "  - " + (.message // "unknown GraphQL error")' >&2 2>/dev/null || true
        return 1
    fi

    if ! open_prs=$(echo "$snapshot" | jq '
        [(.data.repository.pullRequests.nodes // [])[] |
          {
            number,
            title,
            headRefName,
            author,
            updatedAt,
            isDraft
          }]'); then
        echo "cross_ref_gh: failed to parse open PRs" >&2
        return 1
    fi

    if ! in_flight=$(echo "$snapshot" | jq '
        [(.data.repository.issues.nodes // [])[] |
          {
            number,
            title,
            updatedAt,
            labels: (.labels.nodes // []),
            assignees: (.assignees.nodes // [])
          }]'); then
        echo "cross_ref_gh: failed to parse in-flight issues" >&2
        return 1
    fi

    # Claim comments are the lock SSOT. Fetch repository issue comments by
    # updated_at so renewed lock markers cannot fall off a per-issue created_at
    # window. Five hours covers the four-hour maximum lease plus clock/API lag.
    comments_since=$(date -u -d "-5 hours" +"%Y-%m-%dT%H:%M:%SZ")
    if ! repo_comments=$(GH_TOKEN="$GH_TOKEN_BOT" gh api --method GET --paginate --slurp \
        "repos/${REPO}/issues/comments" \
        -F since="$comments_since" \
        -F per_page=100 2>/dev/null); then
        echo "cross_ref_gh: failed to fetch repository issue comments" >&2
        return 1
    fi
    if ! claims=$(echo "$repo_comments" | jq '
        [.[][]
          | select(.body | test("^\\s*<!-- (claim|takeover):"))
          | {
              issue: (.issue_url | split("/") | .[-1] | tonumber),
              id: .id,
              created_at: .created_at,
              updated_at: .updated_at,
              body
            }]'); then
        echo "cross_ref_gh: failed to parse repository claim comments" >&2
        return 1
    fi

    # The repository issue-comments feed includes comments from closed issues.
    # Batch-load recently updated open issues and intersect locally so closed
    # work cannot leave a live pre-flight conflict for the remainder of its lease.
    open_claim_issues="[]"
    open_issue_cursor=""
    open_issue_has_next=true
    while [ "$open_issue_has_next" = "true" ]; do
        local -a cursor_arg
        if [ -n "$open_issue_cursor" ]; then
            cursor_arg=(-F cursor="$open_issue_cursor")
        else
            cursor_arg=(-F cursor=null)
        fi

        if ! open_issue_snapshot=$(GH_TOKEN="$GH_TOKEN_BOT" gh api graphql \
            -F owner="$repo_owner" \
            -F name="$repo_name" \
            -F since="$comments_since" \
            "${cursor_arg[@]}" \
            -f query='
query($owner: String!, $name: String!, $since: DateTime!, $cursor: String) {
  repository(owner: $owner, name: $name) {
    issues(first: 100, after: $cursor, states: OPEN, filterBy: {since: $since}, orderBy: {field: UPDATED_AT, direction: DESC}) {
      pageInfo {
        hasNextPage
        endCursor
      }
      nodes {
        number
      }
    }
  }
}' 2>/dev/null); then
            echo "cross_ref_gh: failed to fetch recently updated open issues" >&2
            return 1
        fi

        if ! echo "$open_issue_snapshot" | jq -e '
            ((.errors // []) | length == 0) and
            (.data.repository.issues.nodes | type == "array") and
            (.data.repository.issues.pageInfo.hasNextPage | type == "boolean")
        ' >/dev/null 2>&1; then
            echo "cross_ref_gh: invalid recent open issues response" >&2
            echo "$open_issue_snapshot" | jq -r '(.errors // [])[]? | "  - " + (.message // "unknown GraphQL error")' >&2 2>/dev/null || true
            return 1
        fi

        if ! open_issue_page=$(echo "$open_issue_snapshot" | jq '[.data.repository.issues.nodes[] | .number]'); then
            echo "cross_ref_gh: failed to parse recent open issue page" >&2
            return 1
        fi
        if ! open_claim_issues=$(jq -nc \
            --argjson existing "$open_claim_issues" \
            --argjson page "$open_issue_page" \
            '$existing + $page'); then
            echo "cross_ref_gh: failed to append recent open issue page" >&2
            return 1
        fi

        open_issue_has_next=$(echo "$open_issue_snapshot" | jq -r '.data.repository.issues.pageInfo.hasNextPage')
        open_issue_cursor=$(echo "$open_issue_snapshot" | jq -r '.data.repository.issues.pageInfo.endCursor // ""')
        if [ "$open_issue_has_next" = "true" ] && [ -z "$open_issue_cursor" ]; then
            echo "cross_ref_gh: missing recent open issue pagination cursor" >&2
            return 1
        fi
    done
    if ! claims=$(jq -nc \
        --argjson claims "$claims" \
        --argjson open_issues "$open_claim_issues" \
        '$claims | map(select(.issue as $n | $open_issues | index($n)))'); then
        echo "cross_ref_gh: failed to filter claim comments by open issue state" >&2
        return 1
    fi

    jq -nc \
        --argjson in_flight "$in_flight" \
        --argjson open_prs "$open_prs" \
        --argjson claims "$claims" \
        '{in_flight_issues: $in_flight, open_prs: $open_prs, claim_comments: $claims}'
}

# ---------- Internal: parse claim marker ----------

_aph_parse_claim_marker() {
    # _aph_parse_claim_marker <body>
    # Stdout: JSON {kind, agent_id, lease_until|null, renewed_at|null, task,
    #               after|null, branch|null, pr|null} — null fields explicit so
    #               callers always get an object.
    # kind ∈ {claim, takeover}.
    # Backwards-compatible: legacy Phase 1 markers without lease fields →
    # task="legacy", lease_until=null, renewed_at=null, branch=null, pr=null.
    # Caller is responsible for synthesizing lease_until = comment.created_at
    # + 4h when null, per spec amendment §5.2 backwards compatibility rule
    # (4h preserves the long-lease cap so legacy merge-supervisor markers do
    # not look prematurely stale).
    local body="$1"
    # Strip everything after the first newline
    local marker
    marker=$(echo "$body" | head -n 1)

    # Detect kind: claim or takeover. Both use semicolon-delimited fields.
    local kind=""
    if echo "$marker" | grep -q '<!-- claim:'; then
        kind="claim"
    elif echo "$marker" | grep -q '<!-- takeover:'; then
        kind="takeover"
    else
        return 1
    fi

    # Extract fields. For claim: first token after "claim:" is agent_id.
    # For takeover: first token after "takeover:" is the NEW agent_id; "after:"
    # carries the previous (stale) agent id.
    local agent_id lease_until renewed_at task after branch pr
    if [ "$kind" = "claim" ]; then
        agent_id=$(echo "$marker" | sed -nE 's/.*claim:[[:space:]]+([^;>[:space:]]+).*/\1/p')
        after=""
    else
        agent_id=$(echo "$marker" | sed -nE 's/.*takeover:[[:space:]]+([^;>[:space:]]+).*/\1/p')
        after=$(echo "$marker" | sed -nE 's/.*after:[[:space:]]+([^;>[:space:]]+).*/\1/p')
    fi
    lease_until=$(echo "$marker" | sed -nE 's/.*lease_until:[[:space:]]+([^;>[:space:]]+).*/\1/p')
    renewed_at=$(echo "$marker" | sed -nE 's/.*renewed_at:[[:space:]]+([^;>[:space:]]+).*/\1/p')
    task=$(echo "$marker" | sed -nE 's/.*task:[[:space:]]+([^;>[:space:]]+).*/\1/p')
    branch=$(echo "$marker" | sed -nE 's/.*branch:[[:space:]]+([^;>[:space:]]+).*/\1/p')
    pr=$(echo "$marker" | sed -nE 's/.*pr:[[:space:]]+([^;>[:space:]]+).*/\1/p')

    if [ -z "$agent_id" ]; then
        return 1
    fi
    if [ -z "$task" ]; then
        task="legacy"
    fi

    # Treat sentinel "none" as null for branch/pr (matches shared skill).
    if [ "$branch" = "none" ]; then branch=""; fi
    if [ "$pr" = "none" ]; then pr=""; fi

    # Always emit explicit nulls for missing optional fields so the parser
    # output schema is stable for callers (no missing keys).
    jq -nc \
        --arg kind "$kind" \
        --arg id "$agent_id" \
        --arg lease "$lease_until" \
        --arg renewed "$renewed_at" \
        --arg task "$task" \
        --arg after "$after" \
        --arg branch "$branch" \
        --arg pr "$pr" \
        '{
            kind: $kind,
            agent_id: $id,
            lease_until: (if $lease == "" then null else $lease end),
            renewed_at: (if $renewed == "" then null else $renewed end),
            task: $task,
            after: (if $after == "" then null else $after end),
            branch: (if $branch == "" then null else $branch end),
            pr: (if $pr == "" then null else $pr end)
        }'
}

# ---------- Public: pre_flight_check ----------

# pre_flight_check
# Returns 0 if safe to proceed, 1 if conflicts detected.
# Implements 6-step sequence per spec §5.5.1.
pre_flight_check() {
    _aph_validate_core_env || return 1

    # Step 1: local git state
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        echo "pre_flight_check: not in a git repo" >&2
        return 1
    fi
    local current_branch
    current_branch=$(git branch --show-current 2>/dev/null || echo "(detached)")

    # Step 2: read pinned roster (cache layer)
    read_pinned_roster >/dev/null || return 1

    # Step 3: cross-ref GitHub SSOT
    local gh_state
    gh_state=$(cross_ref_gh) || return 1

    # Step 4: reconcile — for each agent in roster, decide if stale.
    local now_epoch
    now_epoch=$(_aph_now_epoch)

    # NOTE: actual stale-marking happens in update_roster_chat_update by the
    # caller. Here we only DETECT conflicts and warn.
    # Pass created_at through so legacy Phase 1 markers (no lease_until) get
    # synthetic lease = created_at + 4h per spec amendment §5.2 (the 4h cap
    # matches the `long` lease ceiling, which preserves the legacy Phase 1
    # manual-takeover window for merge-supervisor markers).
    local conflict=0
    local active_claims
    active_claims=$(echo "$gh_state" | jq -r '.claim_comments[] | "\(.issue)\t\(.created_at)\t\(.body | split("\n")[0])"')
    if [ -n "$active_claims" ]; then
        echo "pre_flight_check: active lock comments found:" >&2
        while IFS=$'\t' read -r issue created_at marker; do
            local parsed
            parsed=$(_aph_parse_claim_marker "$marker")
            if [ -z "$parsed" ]; then continue; fi
            local other_id other_lease
            other_id=$(echo "$parsed" | jq -r '.agent_id')
            other_lease=$(echo "$parsed" | jq -r '.lease_until // ""')
            local other_lease_epoch
            if [ -z "$other_lease" ] || [ "$other_lease" = "null" ]; then
                # Legacy Phase 1 marker — synthesize lease = created_at + 4h
                # per spec amendment §5.2 (4h preserves the long-lease cap).
                local created_epoch
                created_epoch=$(_aph_iso_to_epoch "$created_at" 2>/dev/null || echo 0)
                other_lease_epoch=$((created_epoch + 14400))
                other_lease="${created_at} + 4h (synthetic, legacy Phase 1 marker)"
            else
                other_lease_epoch=$(_aph_iso_to_epoch "$other_lease" 2>/dev/null || echo 0)
            fi
            if [ "$other_lease_epoch" -gt "$now_epoch" ]; then
                if [ "$other_id" = "$AGENT_ID" ]; then
                    echo "  - issue #$issue: already held by this agent, lease until $other_lease" >&2
                    conflict=1
                else
                    echo "  - issue #$issue: held by $other_id, lease until $other_lease (informational)" >&2
                fi
            fi
        done <<< "$active_claims"
    fi

    # Step 5: worktree ownership check (advisory — adapter is responsible
    # for the actual `git worktree` switch when overlap is possible).
    if [ "$current_branch" != "(detached)" ]; then
        # Could check `git worktree list` against expected paths but that
        # depends on adapter convention. For Phase 2 baseline: warn if
        # uncommitted changes exist that we did not author.
        local uncommitted
        uncommitted=$(git status --porcelain 2>/dev/null)
        if [ -n "$uncommitted" ]; then
            echo "pre_flight_check: uncommitted changes in working tree on branch $current_branch:" >&2
            echo "$uncommitted" >&2
            echo "  Verify these are yours before proceeding; otherwise create a separate git worktree." >&2
        fi
    fi

    # Step 6: emit start
    # NOTE: by spec, the caller (adapter) is responsible for calling
    # emit_presence start AFTER pre_flight_check returns 0, so adapters
    # can decide whether to abort on conflict before emitting. We do NOT
    # emit start here automatically.

    if [ "$conflict" -eq 1 ]; then
        return 1
    fi
    return 0
}

# ---------- Internal: cleanup posted claim ----------

_aph_cleanup_posted_claim() {
    # _aph_cleanup_posted_claim <issue_num> <posted_comment_id> <own_prefix>
    local issue_num="$1"
    local posted_comment_id="$2"
    local own_prefix="$3"
    local cleanup_pages cleanup_id

    if [ -n "$posted_comment_id" ]; then
        GH_TOKEN="$GH_TOKEN_BOT" gh api -X DELETE \
            "repos/${REPO}/issues/comments/${posted_comment_id}" >/dev/null 2>&1 || true
        return 0
    fi
    if cleanup_pages=$(GH_TOKEN="$GH_TOKEN_BOT" gh api --paginate --slurp \
        "repos/${REPO}/issues/${issue_num}/comments" 2>/dev/null); then
        cleanup_id=$(echo "$cleanup_pages" | jq -r --arg pfx "$own_prefix" \
            '[.[][] | select(.body | startswith($pfx)) | {id, created_at}]
             | sort_by([.created_at, .id])
             | .[-1].id // empty')
        if [ -n "$cleanup_id" ] && [ "$cleanup_id" != "null" ]; then
            GH_TOKEN="$GH_TOKEN_BOT" gh api -X DELETE \
                "repos/${REPO}/issues/comments/${cleanup_id}" >/dev/null 2>&1 || true
        fi
    fi
}

# ---------- Public: claim_issue ----------

# claim_issue <issue_num> [<task_type>] [<branch>] [<pr>]
# Posts the lease-aware claim marker, waits 3s + retry-on-eventual-consistency,
# returns 0 if won. Updates roster on win.
# task_type ∈ {quick, standard, long}; default = quick (30 min lease).
# branch/pr are canonical mapping keys for fresh GH activity cross-ref. Pass
# "none" (or omit) before branch/PR creation; PATCH the marker via renew_lease
# once known. Per spec §5.2 marker schema.
claim_issue() {
    local issue_num="${1:?claim_issue: issue number required}"
    local task_type="${2:-quick}"
    local branch="${3:-none}"
    local pr="${4:-none}"
    _aph_validate_core_env || return 1

    local ttl_sec
    case "$task_type" in
        quick)    ttl_sec=1800 ;;   # 30 min
        standard) ttl_sec=7200 ;;   # 2 h
        long)     ttl_sec=14400 ;;  # 4 h
        *) echo "claim_issue: unknown task_type '$task_type' (use quick|standard|long)" >&2; return 1 ;;
    esac

    local now_iso lease_iso
    now_iso=$(_aph_now_iso)
    lease_iso=$(_aph_lease_until_iso "$ttl_sec")

    # Match by EXACT prefix "<!-- claim: <AGENT_ID>;" to prevent substring
    # collision (e.g., "...-1" matching "...-10"). Per Codex P1 + Copilot review.
    local own_prefix
    own_prefix="<!-- claim: ${AGENT_ID};"

    local body post_output posted_comment_id
    body="<!-- claim: ${AGENT_ID}; lease_until: ${lease_iso}; renewed_at: ${now_iso}; task: ${task_type}; branch: ${branch}; pr: ${pr} -->
Biorę #${issue_num} — ${AGENT_ID} (branch: ${branch}, PR: ${pr})"

    if ! post_output=$(GH_TOKEN="$GH_TOKEN_BOT" gh issue comment "$issue_num" \
        -R "$REPO" --body "$body" 2>/dev/null); then
        echo "claim_issue: failed to post claim comment on #${issue_num}" >&2
        return 1
    fi
    posted_comment_id=$(printf '%s\n' "$post_output" | sed -nE 's#.*issuecomment-([0-9]+).*#\1#p' | head -n 1)

    sleep 3

    # Re-read with eventual-consistency retry (up to 3× × 2s).
    # Filter MUST include both <!-- claim: AND <!-- takeover: per spec §5.2 —
    # a takeover marker outranks the original claim it succeeded.
    local attempt pages comments own_present winner now_epoch
    now_epoch=$(_aph_now_epoch)
    for attempt in 1 2 3; do
        if ! pages=$(GH_TOKEN="$GH_TOKEN_BOT" gh api --paginate --slurp \
            "repos/${REPO}/issues/${issue_num}/comments" 2>/dev/null); then
            echo "claim_issue: failed to re-read comments for #${issue_num}" >&2
            _aph_cleanup_posted_claim "$issue_num" "$posted_comment_id" "$own_prefix"
            return 1
        fi
        if ! comments=$(echo "$pages" | jq --argjson now_epoch "$now_epoch" \
            '
            def marker_field($name):
              (capture(($name + ":[[:space:]]+(?<v>[^;>[:space:]]+)"))? // {}) | .v;
            def iso_epoch($value):
              try ($value | fromdateiso8601) catch 0;
            [.[][] | select(.body | test("^\\s*<!-- (claim|takeover):"))
              | . as $comment
              | ($comment.body | split("\n")[0]) as $marker
              | {
                  id,
                  created_at,
                  body,
                  kind: (if ($marker | test("^\\s*<!-- takeover:")) then "takeover" else "claim" end),
                  lease_until: ($marker | marker_field("lease_until"))
                }
              | .lease_epoch = (
                  if .lease_until == null then
                    (iso_epoch(.created_at) + 14400)
                  else
                    iso_epoch(.lease_until)
                  end
                )
              | select(.lease_epoch > $now_epoch)]
             | sort_by([.created_at, .id])'); then
            echo "claim_issue: failed to parse comments for #${issue_num}" >&2
            _aph_cleanup_posted_claim "$issue_num" "$posted_comment_id" "$own_prefix"
            return 1
        fi
        own_present=$(echo "$comments" | jq -r --arg pfx "$own_prefix" \
            '[.[] | select(.body | startswith($pfx))] | length')
        if [ "$own_present" -ge 1 ]; then
            break
        fi
        sleep 2
    done

    if [ "$own_present" -lt 1 ]; then
        echo "claim_issue: own comment not visible after 3 retries (GitHub eventual consistency)" >&2
        _aph_cleanup_posted_claim "$issue_num" "$posted_comment_id" "$own_prefix"
        return 1
    fi

    # Winner selection follows Phase 2 precedence within the active lease window:
    # if active takeover markers exist, race among active takeovers only;
    # otherwise race among active claims only. Historical expired lock markers do
    # not participate in a fresh claim race. The array is already sorted by
    # composite (created_at, id).
    winner=$(echo "$comments" | jq -r '
        ([.[] | select(.kind == "takeover")] | if length > 0 then .[0]
         else ([.[] | select(.kind == "claim")] | .[0]) end).body // empty
    ' | head -n 1)
    if [ -z "$winner" ]; then
        echo "claim_issue: no claim/takeover marker found after posting claim" >&2
        return 1
    fi
    local winner_parsed winner_id
    winner_parsed=$(_aph_parse_claim_marker "$winner")
    winner_id=$(echo "$winner_parsed" | jq -r '.agent_id')

    if [ "$winner_id" != "$AGENT_ID" ]; then
        # Lost — delete own claim comment (exact prefix match)
        local own_id
        own_id=$(echo "$comments" | jq -r --arg pfx "$own_prefix" \
            '[.[] | select(.body | startswith($pfx))] | .[-1].id')
        if [ -n "$own_id" ] && [ "$own_id" != "null" ]; then
            GH_TOKEN="$GH_TOKEN_BOT" gh api -X DELETE \
                "repos/${REPO}/issues/comments/${own_id}" >/dev/null 2>&1
        fi
        return 1
    fi

    # Won — update roster
    update_roster_chat_update --event busy --task "#${issue_num}" --lease-until "$lease_iso" || true
    return 0
}

# ---------- Public: renew_lease ----------

# renew_lease <issue_num> [<new_ttl_sec>] [<branch_override>] [<pr_override>]
# Edits own claim comment, bumping lease_until + renewed_at. Preserves task,
# branch, pr from the existing marker unless overrides are passed (use these
# to PATCH branch/pr from "none" to real values once the work creates them).
# Also refreshes roster entry so healthy agent doesn't appear stale.
renew_lease() {
    local issue_num="${1:?renew_lease: issue number required}"
    local new_ttl="${2:-1800}"
    local branch_override="${3:-}"
    local pr_override="${4:-}"
    _aph_validate_core_env || return 1

    # Match own comment by EXACT prefix to prevent substring collision
    # (e.g., "...-1" matching "...-10"). Per Codex P1 review.
    # gh api --jq does not accept --arg, so fetch raw and pipe to jq.
    local own_claim_prefix="<!-- claim: ${AGENT_ID};"
    local legacy_own_claim_prefix="<!-- claim: ${AGENT_ID} -->"
    local own_takeover_prefix="<!-- takeover: ${AGENT_ID};"
    local all_comments own_comment
    all_comments=$(GH_TOKEN="$GH_TOKEN_BOT" gh api --paginate --slurp \
        "repos/${REPO}/issues/${issue_num}/comments" 2>/dev/null) || {
        echo "renew_lease: failed to fetch comments for #${issue_num}" >&2
        return 1
    }
    own_comment=$(echo "$all_comments" | jq -c \
        --arg claim_pfx "$own_claim_prefix" \
        --arg legacy_claim "$legacy_own_claim_prefix" \
        --arg takeover_pfx "$own_takeover_prefix" \
        '[.[][] | select(.body | startswith($claim_pfx) or startswith($legacy_claim) or startswith($takeover_pfx)) | {id, created_at, body}]
         | sort_by([.created_at, .id])
         | .[-1]')

    if [ -z "$own_comment" ] || [ "$own_comment" = "null" ]; then
        echo "renew_lease: no own claim/takeover comment found on #${issue_num}" >&2
        return 1
    fi

    local own_id
    own_id=$(echo "$own_comment" | jq -r '.id')

    # Preserve existing task/branch/pr unless overrides provided. Parser
    # returns null for missing fields → fall back to "quick"/"none".
    local parsed kind task after branch pr
    parsed=$(_aph_parse_claim_marker "$(echo "$own_comment" | jq -r '.body')")
    kind=$(echo "$parsed" | jq -r '.kind')
    task=$(echo "$parsed" | jq -r '.task // "quick"')
    after=$(echo "$parsed" | jq -r '.after // ""')
    branch=$(echo "$parsed" | jq -r '.branch // "none"')
    pr=$(echo "$parsed" | jq -r '.pr // "none"')
    if [ -n "$branch_override" ]; then branch="$branch_override"; fi
    if [ -n "$pr_override" ]; then pr="$pr_override"; fi

    local now_iso lease_iso new_body
    now_iso=$(_aph_now_iso)
    lease_iso=$(_aph_lease_until_iso "$new_ttl")
    if [ "$kind" = "takeover" ]; then
        if [ -z "$after" ]; then
            echo "renew_lease: takeover marker missing after field on comment ${own_id}" >&2
            return 1
        fi
        new_body="<!-- takeover: ${AGENT_ID}; after: ${after}; lease_until: ${lease_iso}; renewed_at: ${now_iso}; task: ${task}; branch: ${branch}; pr: ${pr} -->
Przejmuję #${issue_num} po ${after} — ${AGENT_ID} (branch: ${branch}, PR: ${pr})"
    else
        new_body="<!-- claim: ${AGENT_ID}; lease_until: ${lease_iso}; renewed_at: ${now_iso}; task: ${task}; branch: ${branch}; pr: ${pr} -->
Biorę #${issue_num} — ${AGENT_ID} (branch: ${branch}, PR: ${pr})"
    fi

    local payload
    payload=$(jq -nc --arg body "$new_body" '{body: $body}')

    GH_TOKEN="$GH_TOKEN_BOT" gh api -X PATCH \
        "repos/${REPO}/issues/comments/${own_id}" \
        --input - <<<"$payload" >/dev/null || {
        echo "renew_lease: PATCH failed for comment ${own_id}" >&2
        return 1
    }

    # Refresh roster entry too
    update_roster_chat_update --event busy --task "#${issue_num}" --lease-until "$lease_iso" || true
    return 0
}

# ---------- Public: takeover_check ----------

# takeover_check <issue_num> <stale_agent_id>
# Returns 0 if takeover allowed (3-condition gate ALL true), 1 otherwise.
# Per spec §5.2: lease_expired AND no_gh_activity AND no_presence_event
takeover_check() {
    local issue_num="${1:?takeover_check: issue number required}"
    local stale_agent_id="${2:?takeover_check: stale_agent_id required}"
    _aph_validate_core_env || return 1

    # Find their latest lock comment by exact marker prefix (not substring match).
    local their_comment their_marker their_lease
    local stale_claim_prefix="<!-- claim: ${stale_agent_id};"
    local legacy_stale_claim_prefix="<!-- claim: ${stale_agent_id} -->"
    local stale_takeover_prefix="<!-- takeover: ${stale_agent_id};"
    local pages
    if ! pages=$(GH_TOKEN="$GH_TOKEN_BOT" gh api --paginate --slurp \
        "repos/${REPO}/issues/${issue_num}/comments" 2>/dev/null); then
        echo "takeover_check: failed to fetch comments for #${issue_num}" >&2
        return 1
    fi
    their_comment=$(echo "$pages" | jq -c \
        --arg claim_pfx "$stale_claim_prefix" \
        --arg legacy_claim "$legacy_stale_claim_prefix" \
        --arg takeover_pfx "$stale_takeover_prefix" \
        '[.[][] | select(.body | startswith($claim_pfx) or startswith($legacy_claim) or startswith($takeover_pfx)) | {id, created_at, updated_at, body}]
         | sort_by([.created_at, .id])
         | .[-1]')

    if [ -z "$their_comment" ] || [ "$their_comment" = "null" ]; then
        echo "takeover_check: no claim/takeover marker found from ${stale_agent_id} on #${issue_num}" >&2
        return 1
    fi

    their_marker=$(_aph_parse_claim_marker "$(echo "$their_comment" | jq -r '.body')")
    their_lease=$(echo "$their_marker" | jq -r '.lease_until // ""')

    local now_epoch lease_epoch
    now_epoch=$(_aph_now_epoch)
    if [ -z "$their_lease" ] || [ "$their_lease" = "null" ]; then
        local their_created_epoch
        their_created_epoch=$(_aph_iso_to_epoch "$(echo "$their_comment" | jq -r '.created_at')" 2>/dev/null || echo 0)
        lease_epoch=$((their_created_epoch + 14400))
        their_lease="$(echo "$their_comment" | jq -r '.created_at') + 4h (synthetic, legacy Phase 1 marker)"
    else
        lease_epoch=$(_aph_iso_to_epoch "$their_lease" 2>/dev/null || echo 0)
    fi

    # Condition 1: lease expired
    if [ "$lease_epoch" -ge "$now_epoch" ]; then
        echo "takeover_check: lease still valid (until $their_lease) — refusing takeover" >&2
        return 1
    fi

    # Condition 2: no GH activity after lease expiry. Historical post-claim
    # updates should not block takeover forever after the lease is expired.
    local issue_updated_at
    if ! issue_updated_at=$(GH_TOKEN="$GH_TOKEN_BOT" gh api \
        "repos/${REPO}/issues/${issue_num}" --jq '.updated_at' 2>/dev/null); then
        echo "takeover_check: failed to fetch issue #${issue_num}" >&2
        return 1
    fi
    local issue_updated_epoch activity_cutoff_epoch
    issue_updated_epoch=$(_aph_iso_to_epoch "$issue_updated_at" 2>/dev/null || echo 0)
    activity_cutoff_epoch="$lease_epoch"
    if [ "$issue_updated_epoch" -gt "$activity_cutoff_epoch" ]; then
        echo "takeover_check: issue #${issue_num} has GH activity after lease expiry (${their_lease}) — refusing takeover" >&2
        return 1
    fi

    # Condition 3: no presence event from stale agent in roster after lease expiry.
    local roster their_seen_at their_seen_epoch
    roster=$(read_pinned_roster) || return 1
    if ! their_seen_at=$(echo "$roster" | jq -r --arg aid "$stale_agent_id" '
        if type != "object" then
            error("roster must be object")
        else
            [(.agents // [])[] | select(.agent_id == $aid) | .last_seen_at // ""] | .[0] // ""
        end
    ' 2>/dev/null); then
        echo "takeover_check: failed to parse roster JSON" >&2
        return 1
    fi
    their_seen_epoch=$(_aph_iso_to_epoch "$their_seen_at" 2>/dev/null || echo 0)
    if [ "$their_seen_epoch" -gt "$activity_cutoff_epoch" ]; then
        echo "takeover_check: stale agent has roster presence after lease expiry (${their_lease}) — refusing takeover" >&2
        return 1
    fi

    return 0
}

# ---------- Public: shutdown_wrapper ----------

# shutdown_wrapper <inner_command...>
# Wraps an arbitrary command with trap-based `end` emission. MUST NOT use
# `exec`; replacing the shell would prevent the trap from firing.
shutdown_wrapper() {
    if [ "$#" -lt 1 ]; then
        echo "shutdown_wrapper: command required" >&2
        return 1
    fi

    local prev_exit prev_int prev_term prev_hup trap_fired=0 child_pid=""
    prev_exit=$(trap -p EXIT || true)
    prev_int=$(trap -p INT || true)
    prev_term=$(trap -p TERM || true)
    prev_hup=$(trap -p HUP || true)

    _aph_shutdown_signal() {
        local signal="$1"
        trap_fired=1
        if [ -n "$child_pid" ] && kill -0 "$child_pid" 2>/dev/null; then
            kill "-${signal}" "$child_pid" 2>/dev/null || true
            sleep 1
            if kill -0 "$child_pid" 2>/dev/null; then
                kill -TERM "$child_pid" 2>/dev/null || true
            fi
        fi
        emit_presence end "signal=${signal}" || true
    }

    # EXIT emits only for shell-level exits; signal traps handle child teardown.
    trap 'rc=$?; if [ "$trap_fired" -eq 0 ]; then trap_fired=1; emit_presence end "trap-fired (${rc})" || true; fi' EXIT
    trap '_aph_shutdown_signal INT' INT
    trap '_aph_shutdown_signal TERM' TERM
    trap '_aph_shutdown_signal HUP' HUP

    # Run command as a child so signal traps can terminate it before reporting end.
    "$@" &
    child_pid=$!
    local errexit_was_set=0
    case $- in
        *e*) errexit_was_set=1; set +e ;;
    esac
    wait "$child_pid"
    local rc=$?

    # Restore all traps that were active before the wrapper.
    _aph_restore_trap EXIT "$prev_exit"
    _aph_restore_trap INT "$prev_int"
    _aph_restore_trap TERM "$prev_term"
    _aph_restore_trap HUP "$prev_hup"

    if [ "$trap_fired" -eq 0 ]; then
        emit_presence end "rc=${rc}" || true
    fi
    if [ "$errexit_was_set" -eq 1 ]; then
        set -e
    fi
    return $rc
}

# ---------- End of helpers ----------

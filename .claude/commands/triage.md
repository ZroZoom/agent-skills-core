# Triage

Two supported modes:

- `signals` — existing admin error signal triage from Supabase/app data.
- `backlog` — GitHub/Jira backlog prioritization: issues without milestone, QA queue, proposed owner/priority.

Mode selection:

- If args contain `backlog`, `milestone`, `jira`, or `qa`, use backlog mode.
- If args contain `--source`, `--severity`, `--min-frequency`, or `--dry-run`, use signals mode.
- If the user context says "priorytetyzacja backlogu", "bez milestone", or "kolejka QA", use backlog mode.
- Otherwise keep the legacy default: signals mode.

## Mode: backlog — Issue And QA Prioritization

Load `.agent/skills/backlog-triage/SKILL.md` and follow it.

### Scope

Find open GitHub issues and Jira tickets without a milestone/release target, propose priority and ownership, and report the `For testing` queue size.

### Commands

```bash
gh issue list \
  --repo <OWNER>/<REPO> \
  --state open \
  --limit 200 \
  --json number,title,labels,assignees,milestone,updatedAt,url \
  --jq '.[] | select(.milestone == null)'
```

```bash
PROJECT_IDS_FILE=.agent/context/project-ids.md
PROJECT_ID=$(awk -F'`' '/Project ID:/ {print $2; exit}' "$PROJECT_IDS_FILE")
STATUS_FIELD_ID=$(awk -F'`' '/^## Status Field:/ {print $2; exit}' "$PROJECT_IDS_FILE")
FOR_TESTING_OPTION_ID=$(awk -F'`' '/\| For testing \|/ {print $2; exit}' "$PROJECT_IDS_FILE")

gh api graphql --paginate \
  -f projectId="$PROJECT_ID" \
  -f query='
query($projectId: ID!, $endCursor: String) {
  node(id: $projectId) {
    ... on ProjectV2 {
      items(first: 100, after: $endCursor) {
        nodes {
          fieldValues(first: 20) {
            nodes {
              ... on ProjectV2ItemFieldSingleSelectValue {
                field {
                  ... on ProjectV2SingleSelectField { id }
                }
                optionId
                name
              }
            }
          }
          content {
            ... on Issue { number title }
            ... on PullRequest { number title }
          }
        }
        pageInfo { hasNextPage endCursor }
      }
    }
  }
}' --jq ".data.node.items.nodes[] | select(.fieldValues.nodes[]? | (.field.id == \"$STATUS_FIELD_ID\" and .optionId == \"$FOR_TESTING_OPTION_ID\"))"
```

For Jira, use Atlassian MCP with:

```text
project = <JIRA_PROJECT_KEY>
AND statusCategory != Done
AND fixVersion is EMPTY
ORDER BY priority DESC, updated DESC
```

### Output

```markdown
## Backlog triage

**GitHub issues without milestone:** N
**Jira tickets without fixVersion:** M / not checked
**QA queue (`For testing`):** Q

### Recommended changes
| Item | Priority | Milestone | Owner | Why |
|---|---|---|---|---|
```

Do not mutate GitHub or Jira unless the user explicitly confirms or passes `--apply`.

---

## Mode: signals — Admin Error Signal Analyst

Scan 4 error signal sources, dedupe against open GitHub issues, create new issues and update existing ones.

**v1 scope:** this skill creates and updates issues only. Automatic closing of stale triage issues is deferred to v2 — the current dedupe is filter/truncation-sensitive, so auto-close would wrongly close out-of-scope issues when `--source`/`--severity` are used or when a source hits its row cap. Track follow-up in a separate issue.

**Sources:**
1. `chatbot_missed_queries` — questions the deterministic chatbot couldn't answer
2. `answer_reports` — incorrect answers (auto-logged + user-flagged "my answer is correct")
3. `content_feedback` — negative feedback with category=`error` or ≥2 negative comments
4. `get_content_triage_report()` RPC — exercise quality (success-rate outliers)

**Contract:** Skill creates or updates GitHub issues. It does NOT modify content files, DB state, open PRs, or close issues.

## 1. Preconditions

- Run `npx tsx tools/admin-triage-bootstrap.ts` once per repo (creates labels). If labels missing, the script will tell you.
- Env: `VITE_SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` in `.env`.
- `gh auth status` must show authenticated.

## 2. Parse user flags

User may pass:
- `--source=chatbot|answers|feedback|exercises` — restrict to one stream
- `--severity=critical|warning|info` — minimum severity
- `--min-frequency N` — lower bound for chatbot clusters
- `--limit N` — raise the default 20-new-issues cap (max 50)
- `--dry-run` — show preview, make no changes
- `--yes` — skip the confirmation gate (for autonomous loops)

If the user typed plain `/triage`, run with no flags (full scan, default thresholds).

## 3. Run the script

```bash
npx tsx tools/admin-triage.ts --json <user-flags>
```

Exit codes:
- `0` — JSON on stdout. Parse it.
- `1` — labels missing. Tell user to run bootstrap.
- `2` — Supabase error. Show the error, stop.
- `3` — gh CLI error. Show the error, stop.
- `4` — unexpected. Show stack trace, stop.
- `5` — usage / flag-validation error. Show the message, stop.

## 4. Show preview to the user

Print a Polish-language summary table (the literal output below MUST stay in Polish — it is shown to the user, who reads PL per CLAUDE.md communication rule):

```
Triage report:
  Nowe issues: N (top severity: X critical, Y warning, Z info)
  Aktualizacje istniejących: M
  [Truncated: pokazuję top 20 z N znalezionych]
```

List top 5 new issues by title with their fingerprint. List issue numbers for updates.

Note: `resolved` is always 0 in v1 (auto-close disabled — see intro note).

## 5. Confirmation gate

Unless `--yes` or `--dry-run`, print this confirmation prompt to the user verbatim in Polish (user-facing, must stay PL):
> "Utworzę N issues i dopiszę komentarze do M. Kontynuować? (ok/skip)"

Wait for explicit `ok`. On `skip` — print "anulowano" and stop.

If `--dry-run` — print the full JSON and stop. No mutations.

## 6. Execute actions

**Security: never interpolate raw title/body/comment text into a shell command.** The JSON payload comes from user-generated DB content (missed queries, answers, feedback comments); a title like `$(rm -rf ~)` inlined into `gh issue create --title "..."` would execute when bash parses the command (double quotes do NOT block `$(...)` or backticks). Always write every user-origin field to its own tempfile using a single-quoted heredoc, then pass the file's content through `--body-file` or `"$(cat <file>)"` — bash command substitution treats file output as a literal string and never re-evaluates it.

Pattern for `new` issues:

```bash
BODY_TMP=$(mktemp)
cat > "$BODY_TMP" << 'ISSUE_BODY_EOF'
<paste the raw body JSON value verbatim here>
ISSUE_BODY_EOF

TITLE_TMP=$(mktemp)
cat > "$TITLE_TMP" << 'ISSUE_TITLE_EOF'
<paste the raw title verbatim here>
ISSUE_TITLE_EOF

gh issue create \
  --title "$(cat "$TITLE_TMP")" \
  --body-file "$BODY_TMP" \
  --label "triage" --label "source:<...>" --label "severity:<...>"

rm -f "$BODY_TMP" "$TITLE_TMP"
```

Why this is safe: the single-quoted heredoc delimiter (`'ISSUE_BODY_EOF'`, `'ISSUE_TITLE_EOF'`) disables `$` / backtick expansion when bash writes the file. When we later read the file via `$(cat "$TITLE_TMP")`, command substitution captures the file's stdout and passes it as a single argv entry to gh — gh does not shell-eval its arguments, so nothing in the payload executes.

Run at most 1 issue create at a time (not in parallel) — each tempfile lifecycle must be self-contained.

Pattern for `update` comments — same structure:

```bash
COMMENT_TMP=$(mktemp)
cat > "$COMMENT_TMP" << 'COMMENT_EOF'
<paste comment text verbatim>
COMMENT_EOF
gh issue comment <N> --body-file "$COMMENT_TMP"
rm -f "$COMMENT_TMP"
```

The JSON payload's `resolved` array is always empty in v1 — skip it (no `gh issue close` calls).

## 7. Final summary

Print in Polish (user-facing literal — must stay PL):

```
Utworzone: #123 #124 #125 ...
Zaktualizowane: #42 #50
```

If any action failed: list failures with exit reason. Suggest re-run.

## 8. Rules

- **Never** edit content files, DB rows, submit PRs, or close issues from this command.
- **Never** reopen closed issues — v2 may add a "previous: #<N>" reference in new issue bodies when a closed one matches; v1 does not.
- **Always** show the preview before mutations unless `--yes`.
- On partial failure: print what succeeded + what didn't. User decides whether to rerun.

## References

- Spec: `docs/superpowers/specs/2026-04-16-admin-triage-skill-design.md`
- Script: `tools/admin-triage.ts`
- Bootstrap: `tools/admin-triage-bootstrap.ts`
- Related admin dashboards: `src/components/admin/{AnswerReportsManager,MissedQueriesDashboard,FeedbackManager,ContentQualityDashboard}.tsx`

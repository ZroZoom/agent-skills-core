---
name: demo-check
description: "Demo readiness verifier. Checks Milestone issues, key user paths, deploy/CI signals, and produces a presenter demo script. Trigger when: /demo-check, demo readiness, przed demo, sprawdź demo."
---

# Demo Check Skill

Verify whether the app is ready to present and generate a tested demo script.

## Contract

- Inputs: optional milestone name, preview URL, or local URL. Default milestone: configure per project.
- Output: a Polish readiness report and a presenter script with verified clicks.
- Side effects: none by default. Do not create or close issues unless the user explicitly asks.

## Data Sources

- GitHub milestone and linked issues.
- GitHub PR/check status.
- Local build and selected Playwright smoke paths.
- Optional deploy preview or production URL.
- Memory (optional): your project demo-readiness notes.

## Workflow

### 1. Gather milestone status

```bash
MILESTONE_TITLE="<DEMO_MILESTONE>"
MILESTONE_DUE_ON=$(gh api repos/<OWNER>/<REPO>/milestones \
  --jq ".[] | select(.title == \"$MILESTONE_TITLE\") | .due_on" | head -1)

gh issue list \
  --repo <OWNER>/<REPO> \
  --milestone "$MILESTONE_TITLE" \
  --state all \
  --limit 100 \
  --json number,title,state,labels,assignees,url,updatedAt
```

Use `$MILESTONE_DUE_ON` for the report deadline. If it is empty, report `not set`.

Also check open PRs that explicitly mention Milestone issues. Derive issue numbers from the milestone instead of hardcoding them, and avoid broad `gh pr list --search "1854 1855 ..."` queries because GitHub search can return unrelated PRs.

```bash
MILESTONE_ISSUE_NUMBERS=$(gh issue list \
  --repo <OWNER>/<REPO> \
  --milestone "$MILESTONE_TITLE" \
  --state all \
  --limit 100 \
  --json number \
  --jq '.[].number')

if [ -n "$MILESTONE_ISSUE_NUMBERS" ]; then
  MILESTONE_PATTERN="#($(printf '%s\n' "$MILESTONE_ISSUE_NUMBERS" | paste -sd'|' -))"

  gh pr list \
    --repo <OWNER>/<REPO> \
    --state open \
    --limit 100 \
    --json number,title,body,state,isDraft,headRefName,statusCheckRollup,url \
    --jq ".[] | select(((.title // \"\") + \" \" + (.body // \"\")) | test(\"$MILESTONE_PATTERN\"))"
else
  echo "No issues found for milestone: $MILESTONE_TITLE"
fi
```

If a linked-PR view is needed for a single issue, inspect the issue timeline in GitHub UI or GraphQL rather than relying on fuzzy PR search.

### 2. Run fast quality checks

```bash
npm run typecheck
npm run lint
```

If the user asked for a full release-grade check, add:

```bash
npm run build
```

### 3. Verify key user paths

Preferred local flow:

1. Start the dev server with `npm run dev`.
2. Use Playwright against `http://localhost:5173`.
3. Run focused specs:

```bash
npx playwright test e2e/landing.spec.ts e2e/auth.spec.ts --reporter=list
```

If Playwright is too broad for the moment, manually smoke test the project's critical paths.

> **Configure for your project.** Maintain the demo path table in `.agent/context/demo-paths.md` (or equivalent). Suggested skeleton:

| Path | Purpose |
|---|---|
| `/` | landing page first impression |
| `/auth` | registration / login entry |
| `<feature route>` | core feature route |
| `<deep-link>` | a representative deep link covering data integration |

### 4. Check deploy signal

If a deploy URL is provided, test that URL. Otherwise use production:

- `https://<DOMAIN_PRIMARY>`
- `https://<DOMAIN_SECONDARY>`

If Netlify MCP is available, read latest deploy status. If not, use GitHub deployments:

```bash
gh api repos/<OWNER>/<REPO>/deployments --jq '.[0] | {environment,description,created_at,sha}'
```

### 5. Produce the report

Use this format:

```markdown
## Demo readiness

**Verdict:** ready / risky / blocked
**Checked at:** YYYY-MM-DD HH:mm Europe/Warsaw
**Milestone deadline:** YYYY-MM-DD / not set / not checked

### Milestone issues
| Issue | State | Risk |
|---|---|---|
| #1854 ... | open/closed | ... |

### Quality checks
- Typecheck: pass/fail/not run
- Lint: pass/fail/not run
- Build: pass/fail/not run
- Playwright smoke: pass/fail/not run

### Key paths
| Path | Result | Notes |
|---|---|---|

### Blockers
- ...

### Demo script
1. Open `/` and show ...
2. Navigate to a core feature page and ...
3. Open a verified deep link / detail page ...
4. Show a secondary feature ...
5. Close with ...
```

## Rules

- Mark the demo `blocked` if registration, landing, or a critical path cannot be opened.
- Do not claim a path was verified unless it was actually checked.
- Include exact dates when talking about deadlines. Use the milestone `due_on` value from GitHub; if it is missing, say that no GitHub milestone deadline is configured.
- Do not create synthetic demo content unless the user asks.

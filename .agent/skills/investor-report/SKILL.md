---
name: investor-report
description: "Stakeholder report generator. Collects product metrics, GitHub milestones, and DB stats where available, then formats PDF-ready markdown. Trigger when: /investor-report, stakeholder report, raport inwestorski, metryki produktu."
---

# Investor Report Skill

Prepare a concise, evidence-backed report for stakeholders.

## Contract

- Inputs: optional report period, target audience, and whether to query Supabase.
- Output: PDF-ready markdown in Polish by default, with an English executive variant if requested.
- Side effects: none. Do not publish or email unless explicitly asked.

## Metrics Sources

> **Configure for your project.** Replace `<PRODUCT_STATS_FILE>` and `<DB_STATS_QUERY>` with the actual paths in your repo.

| Metric | Source |
|---|---|
| product / inventory metrics | `<PRODUCT_STATS_FILE>` (e.g. generated JSON, or build artifact) |
| roadmap / milestones | GitHub milestones API |
| velocity / highlights | merged PRs in period |
| users / usage | DB admin query or analytics export, if credentials are available |
| deploy status | hosting provider MCP or GitHub deployments |

## Workflow

### 1. Gather product metrics

Load whatever generated stats file your project produces (JSON, CSV, build artifact). Example:

```bash
node -e "const s=require('./<PRODUCT_STATS_FILE>'); console.log(JSON.stringify(s, null, 2));"
```

### 2. Gather milestone progress

```bash
gh api repos/<OWNER>/<REPO>/milestones \
  --jq '.[] | select(.state == "open") | {title,open_issues,closed_issues,due_on}'
```

### 3. Gather delivery highlights

```bash
gh pr list \
  --repo <OWNER>/<REPO> \
  --state merged \
  --search "merged:>=YYYY-MM-DD base:main" \
  --limit 100 \
  --json number,title,mergedAt,labels,url
```

### 4. Gather DB / analytics metrics if available

Never print service-role keys. If credentials are missing, state `DB metrics unavailable`.

Possible sources:

- a backend stats endpoint (e.g. `/api/stats`, Edge Function)
- direct admin SQL approved by the user
- analytics dashboard export supplied by the user (GA, Plausible, PostHog, etc.)

Minimum useful metrics:

- registered users
- active users in the period, if defined
- core actions completed (e.g. resources viewed, conversions)
- waitlist / signups, if available

### 5. Write the report

```markdown
# Raport dla stakeholderów

**Okres:** YYYY-MM-DD - YYYY-MM-DD
**Wygenerowano:** YYYY-MM-DD HH:mm Europe/Warsaw

## Executive summary
- ...

## Metryki produktu
| Metryka | Wartość | Źródło |
|---|---:|---|
| <Twoja metryka> | ... | <źródło> |

## Postęp milestone
| Milestone | Postęp | Termin | Ryzyko |
|---|---:|---|---|

## Highlights
- ...

## Ryzyka
- ...

## Następne kroki
1. ...
```

## Rules

- Separate measured facts from interpretation.
- Do not fabricate user metrics when the data source is unavailable.
- Mention stale generated stats if their `generatedAt` is older than the report period.
- Keep regulatory-sensitive language conservative: do not present capabilities that have not been verified.
- Prefer specific dates over relative phrases like "today" in report output.

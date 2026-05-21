# Project IDs — single source of truth

> All project-specific identifiers (GitHub Project, Jira, Netlify, Supabase, team) live here. Skills and slash commands MUST read values from this file rather than hard-coding them.

This file is intentionally checked in with placeholders. Fork the repo, fill in your values, commit. Use `<UPPER_SNAKE>` placeholders so they are easy to find with `rg "<MY_PLACEHOLDER>"`.

## GitHub Project (Projects v2)

| Field | Value | How to find |
|---|---|---|
| Owner | `<OWNER>` | GitHub org or user login |
| Project number | `<PROJECT_NUMBER>` | URL: `github.com/orgs/<owner>/projects/<N>` |
| Project ID (`PVT_...`) | `<PROJECT_ID>` | `gh api graphql -f query='{ organization(login: "<OWNER>") { projectV2(number: <N>) { id } } }'` |

### Single-select field IDs (`PVTSSF_...`)

| Field name | Field ID | Notes |
|---|---|---|
| Status | `<STATUS_FIELD_ID>` | usually built-in |
| Priority | `<PRIORITY_FIELD_ID>` | |
| Size | `<SIZE_FIELD_ID>` | story points / t-shirt |
| Iteration | `<ITERATION_FIELD_ID>` | optional |

How to fetch all field IDs at once:

```bash
gh api graphql -f query='
  query {
    node(id: "<PROJECT_ID>") {
      ... on ProjectV2 {
        fields(first: 50) {
          nodes {
            ... on ProjectV2SingleSelectField {
              id name options { id name }
            }
          }
        }
      }
    }
  }
' --jq '.data.node.fields.nodes[] | select(.options) | {name, id, options}'
```

### Status option IDs

Capture from the query above and paste here:

| Status | Option ID |
|---|---|
| Todo / Backlog | `<STATUS_TODO_ID>` |
| In progress | `<STATUS_IN_PROGRESS_ID>` |
| In review | `<STATUS_IN_REVIEW_ID>` |
| For testing | `<STATUS_FOR_TESTING_ID>` |
| Done | `<STATUS_DONE_ID>` |

### Priority option IDs

| Priority | Option ID |
|---|---|
| P0 / Urgent | `<PRIORITY_P0_ID>` |
| P1 / High   | `<PRIORITY_P1_ID>` |
| P2 / Medium | `<PRIORITY_P2_ID>` |
| P3 / Low    | `<PRIORITY_P3_ID>` |

## Jira

| Field | Value |
|---|---|
| Cloud ID | `<JIRA_CLOUD_ID>` |
| Site URL | `https://<your-org>.atlassian.net` |
| Project key | `<JIRA_PROJECT_KEY>` |
| Issue types | `Task, Bug, Story, Epic, Sub-task` (adjust to your workflow) |
| Default tester (account ID) | `<TESTER_ACCOUNT_ID>` |
| Access | MCP Atlassian (requires login) |

## Netlify (or your hosting)

| Site | Name | Site ID |
|---|---|---|
| Primary | `<SITE_NAME_PRIMARY>` | `<SITE_ID_PRIMARY>` |
| Secondary | `<SITE_NAME_SECONDARY>` | `<SITE_ID_SECONDARY>` |

## Domains

| Role | Domain |
|---|---|
| Primary | `<DOMAIN_PRIMARY>` |
| Secondary | `<DOMAIN_SECONDARY>` |

## Supabase / database (if applicable)

| Field | Value |
|---|---|
| Project ref | `<SUPABASE_PROJECT_REF>` |
| Migration path | `supabase/migrations/` |
| Generated types path | `src/types/supabase.ts` |
| Sync command | `npm run update-types` |
| Local start command | `npm run db:start` |
| Local reset command | `npm run db:reset` |
| Local type sync command | `npm run update-types:local` |

## Tables / collections that affect content layout

> Only fill in if a slash command or skill needs to know which schema bumps require regenerating downstream artifacts.

| Table / collection | Triggers regen of |
|---|---|
| `<TABLE_A>` | `<artifact-or-script>` |
| `<TABLE_B>` | `<artifact-or-script>` |

## Team (for `Co-Authored-By` and ticket assignment)

| Role | Handle / email |
|---|---|
| Owner / maintainer | `<OWNER_HANDLE>` |
| QA / tester | `<TESTER_HANDLE>` |
| Content owner | `<CONTENT_OWNER_HANDLE>` |

## Multi-agent dispatch (optional)

> Only needed if you use the `agent-presence` skill + dispatch adapters (`dispatch-watcher-claude`, `dispatch-watcher-gemini`, `dispatch-watcher`). Otherwise leave blank.

| Field | Value | How to find |
|---|---|---|
| Dispatch channel name | `<DISPATCH_CHANNEL>` | e.g. `#agent-dispatch`, `#proj-XYZ-agent-dispatch` |
| Dispatch channel ID | `<DISPATCH_CHANNEL_ID>` | Slack channel ID (e.g. `C0B25SWSUKS`); right-click channel → "Copy link" → last path segment |
| Pinned roster message TS | `<ROSTER_MESSAGE_TS>` | Slack message timestamp of the pinned roster message (e.g. `1778500000.123456`) |

Adapters expect these as env vars (`ROSTER_CHANNEL_ID`, `ROSTER_MESSAGE_TS`) plus per-agent bot tokens (`GH_TOKEN_CLAUDE_BOT`, `GH_TOKEN_GEMINI_BOT`, `GH_TOKEN_CODEX_BOT`) and a model-agnostic `GH_TOKEN_BOT` resolved from the matching `*_BOT` variable. See `.agent/skills/agent-presence/SKILL.md` for the full contract.

## Vercel (only if the `next-vercel` overlay is enabled)

> Only needed if you enabled the overlay with `scripts/enable-overlay.sh next-vercel`. Otherwise leave blank. See `.agent/overlays/next-vercel/README.md`.

| Field | Value | How to find |
|---|---|---|
| Vercel project | `<VERCEL_PROJECT>` | Vercel project name (e.g. `fajnaszkola`) |
| Vercel org / team | `<VERCEL_ORG>` | Vercel team slug (Settings → General) |
| Production URL | `<VERCEL_PRODUCTION_URL>` | e.g. `https://fajnaszkola.pl` |

## How skills consume this file

A skill or slash command that needs an ID must:

1. Look up the value in this file.
2. If the placeholder is still `<...>`, halt and tell the user "fill in `<X>` in `.agent/context/project-ids.md` first" — do NOT make up an ID.
3. Use the resolved value in the command.

This protects against hallucinated IDs and makes the template safe to drop into a fresh repo.

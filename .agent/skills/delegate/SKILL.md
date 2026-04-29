---
name: delegate
description: "Issue-to-agent delegation. Generates a ready-to-paste Claude/Codex prompt from a GitHub issue, gathers repository context, and moves the issue to In progress. Trigger when: delegate an issue, prepare a prompt for an agent, /delegate, przekaż issue agentowi."
---

# Delegate Skill

Turn a GitHub issue into a complete implementation prompt for another AI agent.

## Contract

- Input: GitHub issue number or URL.
- Output: a ready-to-paste prompt containing the task, acceptance criteria, likely files, project context, constraints, verification, and delivery checklist.
- Side effect: move the issue to `In progress` on the GitHub Project board.
- Do not modify application code while preparing the prompt.

## Preconditions

- Work in the local repo `<OWNER>/<REPO>`.
- `gh auth status` must be authenticated.
- Load:
  - `AGENTS.md`
  - `.agent/context/project-ids.md`
  - relevant skill files based on issue labels and paths
  - any project-specific compliance docs your repo defines (e.g. AI policy, privacy policy) for sensitive tasks

## Workflow

### 1. Fetch the issue

```bash
ISSUE_INPUT=1234 # or https://github.com/<OWNER>/<REPO>/issues/1234
ISSUE_NUMBER=$(gh issue view "$ISSUE_INPUT" \
  --repo <OWNER>/<REPO> \
  --json number \
  --jq '.number')

gh issue view "$ISSUE_NUMBER" \
  --repo <OWNER>/<REPO> \
  --json number,title,body,state,labels,assignees,milestone,url,comments
```

Stop if the issue is closed unless the user explicitly asked for a retrospective prompt.

### 2. Move the project item to In progress

Read IDs from `.agent/context/project-ids.md` instead of copying them into the command.

```bash
PROJECT_IDS_FILE=.agent/context/project-ids.md
PROJECT_ID=$(awk -F'`' '/Project ID:/ {print $2; exit}' "$PROJECT_IDS_FILE")
STATUS_FIELD_ID=$(awk -F'`' '/^## Status Field:/ {print $2; exit}' "$PROJECT_IDS_FILE")
IN_PROGRESS_OPTION_ID=$(awk -F'`' '/\| In progress \|/ {print $2; exit}' "$PROJECT_IDS_FILE")

if [ -z "$PROJECT_ID" ] || [ -z "$STATUS_FIELD_ID" ] || [ -z "$IN_PROGRESS_OPTION_ID" ]; then
  echo "Could not read project IDs from $PROJECT_IDS_FILE"
  exit 1
fi

ITEM_ID=$(gh api graphql -F issue="$ISSUE_NUMBER" -f query='query($issue: Int!) {
  repository(owner: "<OWNER>", name: "<REPO>") {
    issue(number: $issue) {
      projectItems(first: 5) { nodes { id project { id title } } }
    }
  }
}' --jq ".data.repository.issue.projectItems.nodes[] | select(.project.id == \"$PROJECT_ID\") | .id" | head -1)

if [ -z "$ITEM_ID" ]; then
  CONTENT_ID=$(gh issue view "$ISSUE_NUMBER" --repo <OWNER>/<REPO> --json id --jq '.id')
  ITEM_ID=$(gh api graphql \
    -f projectId="$PROJECT_ID" \
    -f contentId="$CONTENT_ID" \
    -f query='mutation($projectId: ID!, $contentId: ID!) {
      addProjectV2ItemById(input: {projectId: $projectId, contentId: $contentId}) {
        item { id }
      }
    }' \
    --jq '.data.addProjectV2ItemById.item.id')
fi

gh project item-edit \
  --project-id "$PROJECT_ID" \
  --id "$ITEM_ID" \
  --field-id "$STATUS_FIELD_ID" \
  --single-select-option-id "$IN_PROGRESS_OPTION_ID"
```

If project scopes are missing, stop and ask the user to run `gh auth refresh -s read:project,project`.

### 3. Infer the context bundle

Map labels and task text to likely files:

| Signal | Load first |
|---|---|
| `tooling`, `feat(skills)` | `.agent/skills/`, `.claude/commands/`, `.agent/AGENTS.md` |
| `area: tests` | `.agent/skills/test-automation/SKILL.md`, `.agent/skills/test-manager/SKILL.md`, `e2e/`, `src/**/__tests__/` |
| `area: database` | `.agent/skills/supabase-admin/SKILL.md`, `.agent/context/database.md`, `supabase/migrations/`, `src/types/supabase.ts` |
| `area: ui/ux` | `.agent/skills/frontend-system/SKILL.md`, route/page/component files named in the issue |
| content / copy / docs | your project's content skill (if any) |
| GitHub, PR, release | `.agent/skills/repo-ops/SKILL.md`, `.claude/commands/repo.md`, `.claude/commands/merge.md` |

Search for concrete terms from the title and body:

```bash
rg -n "term-from-issue|another-term" src tools scripts .agent .claude docs
```

Include only context that materially helps the next agent. Do not paste huge files.

### 4. Build the prompt

Use this exact structure:

```markdown
# Task
Implement GitHub issue #<number>: <title>
<issue URL>

## Goal
<1-3 sentence summary in Polish, grounded in the issue body>

## Acceptance Criteria
- <copy/restate each criterion from the issue>

## Repository Context
- Branch rule: create `feature/<short-slug>` or `fix/<short-slug>`, never commit to `main`.
- Architecture: <route/content/Supabase/skills context relevant to this task>
- Existing patterns to follow:
  - `<path>` — <why it matters>

## Likely Files To Inspect Or Change
- `<path>` — <expected reason>

## Constraints
- Follow `AGENTS.md` and relevant `.agent/skills/*`.
- AI Act: no AI grading, profiling, adaptive learning, or behavioral monitoring.
- Do not edit generated files unless running the documented generator.
- Do not touch `public/locales/*`; edit `src/locales/*` if translations are needed.
- Keep changes scoped to this issue.

## Verification
- `npm run typecheck`
- `npm run lint`
- `npm run build`
- Add narrower tests when code behavior changes.

## Delivery
- Commit on a feature/fix branch.
- Push and open a draft PR.
- Link with `Closes #<number>`.
```

### 5. Output

Return:

1. `Status moved to In progress: yes/no`.
2. The prompt in a fenced `markdown` block.
3. Any missing context or risk, such as missing token scopes or ambiguous files.

## Rules

- Never invent acceptance criteria.
- Never include secrets, `.env` values, or MCP tokens.
- If the issue asks for high-risk AI behavior, explicitly reframe to an allowed deterministic or human-in-the-loop approach.
- If multiple issues are requested, produce one prompt per issue and move each issue independently.

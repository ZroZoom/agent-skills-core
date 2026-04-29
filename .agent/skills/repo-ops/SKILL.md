---
name: repo-ops
description: "Repository and project manager. Git Flow, Issues/PRs, GitHub Projects, sprint planning, backlog management, and ROADMAP synchronization. Trigger when: create an issue/PR, push changes, plan a sprint, review backlog, update the roadmap, stwórz issue/PR, wypchnij zmiany, planuj sprint, przegląd backlogu, aktualizacja roadmapy."
---

# 🐙 GitHub Operations & Project Management

## 1. Iron Rules of Git

> Git rules: see CLAUDE.md. Below: only repo-ops specific procedures.

- **Cleanup**: Delete local and remote branches after merging.
- **Uncommitted changes**: DO NOT stash! Ask → WIP commit → operation → `git reset --soft HEAD~1`

## 2. GitHub Project Configuration (ID Reference)

> GitHub Project IDs: see `.agent/context/project-ids.md`

> **IMPORTANT**: The agent MUST update status during work!
> Details: `.agent/workflows/repository-management.md` → section "Status Automation"

## 3. Creating Issues/PRs

**Issue:**
```bash
gh issue create --title "..." --body "..." --label "Antigravity" --assignee "@copilot"
```

**PR:**
```bash
gh pr create --title "..." --body "..." --label "Antigravity"
```

## 4. Versioning (Semantic Versioning)

- **+0.1.0** — new features, components, significant improvements
- **+0.0.1** — fixes, minor UI improvements, refactoring
- **Maximum one major change per day** — for stability and history readability

## 5. Documentation Structure (IMPORTANT!)

**DO NOT create .md files in the repository root!**

In root (`/`) only these are allowed:
- `README.md`
- `ROADMAP.md`

All other documentation must go into `/docs`:
- **Feature specs** → `docs/features/`
- **Technical specs** → `docs/specs/`
- **Architecture decisions** → `docs/ADR/`
- **ESLint** → `docs/eslint/`
- **Marketing/SEO** → `docs/`
- **Other** → `docs/`

## 6. Backlog Management

### Issue Prioritization

| Priority | When to use | Action |
|----------|-------------|--------|
| **P0 Critical** | Blocks production, security | Immediately, before everything |
| **P1 High** | Important for the next release | In the current sprint |
| **P2 Medium** | Nice-to-have, improvements | When time allows |

### Backlog Grooming (weekly)

1. Review Issues without priority → assign P0/P1/P2
2. Close inactive Issues (>30 days without activity)
3. Merge duplicates
4. Add missing labels (`bug`, `enhancement`, `docs`)

```bash
# List Issues without priority
gh issue list --label "" --limit 50
```

## 7. Sprint Planning

### Sprint = 1-2 weeks

**Before the sprint:**
1. Select Issues from the Backlog → move to "To Do"
2. Estimate Size (S/M/L) for each
3. Don't plan more than 3-5 M-size Issues per sprint

**During the sprint:**
- "In Progress" Issues → max 2 at a time
- Daily status updates

**After the sprint:**
- Incomplete Issues → return to Backlog or move to next sprint
- Retrospective: what went well/poorly?

### Commands

```bash
# Move Issue to "To Do"
gh project item-edit --project-id PVT_kwDODtV8184BKyTu --id <ITEM_ID> --field-id <STATUS_FIELD_ID> --single-select-option-id 61e4505c

# Set priority to P1
gh project item-edit --project-id PVT_kwDODtV8184BKyTu --id <ITEM_ID> --field-id <PRIORITY_FIELD_ID> --single-select-option-id 0a877460
```

## 8. Syncing with ROADMAP.md

`ROADMAP.md` is the **source of truth** for long-term goals.

### Workflow

1. **New goal in ROADMAP** → Create corresponding Issues with a link to the section
2. **Issue closed** → Check if the ROADMAP goal can be marked as ✅
3. **Monthly**: Review ROADMAP and update statuses

### ROADMAP.md Format

```markdown
## Q1 2026

### ✅ Completed
- [x] Feature X (#123)

### 🚧 In Progress
- [ ] Feature Y (#456) - 60% done

### 📋 Planned
- [ ] Feature Z (no Issue)
```

### Automated Sync

```bash
# List Issues closed this month
gh issue list --state closed --limit 50 --json number,title,closedAt
```

## 9. Resolving Review Threads (Copilot/Code Review)

> [!IMPORTANT]
> After fixing Copilot or code review comments, you **MUST** resolve threads via the GraphQL API!

> [!WARNING]
> **Resolving without reading the content = mistake.** Mechanical resolveReviewThread without reading comments missed a real bug in session 2026-03. ALWAYS read before resolving.

### Workflow

1. **Fix the comments** in code
2. **Push** changes to the branch
3. **Fetch thread IDs WITH CONTENT**:
```bash
gh api graphql -f query='query {
  repository(owner: "<OWNER>", name: "<REPO>") {
    pullRequest(number: PR_NUMBER) {
      reviewThreads(first: 50) {
        nodes {
          id isResolved path
          comments(first: 5) {
            nodes { body author { login } }
          }
        }
      }
    }
  }
}'
```

4. **READ each unresolved thread and decide**:
   - Bug pointed out by the reviewer? → **FIX FIRST, THEN resolve**
   - Cosmetic note / already fixed? → resolve

5. **Resolve the thread** (only after making a decision):
```bash
gh api graphql -f query='mutation {
  resolveReviewThread(input: {threadId: "PRRT_xxx"}) {
    thread { isResolved }
  }
}'
```

### Why This Matters

- A PR with unresolved threads has status **BLOCKED**
- GitHub won't allow merging until all conversations are resolved
- Pushing a fix alone does NOT automatically resolve the thread

## 10. Pitfalls (Lessons Learned)

> This section is updated on an ongoing basis — it collects mistakes Claude makes during Git/PR operations.

### P1. Unexpected changes in `git status`
**Mistake:** Committing `modified` files that Claude didn't edit (e.g., changed by another instance or a hook).
**Fix:** If you see unexpected `modified` files → STOP. Ask the user before adding anything to staging.

### P2. Rebase after squash-merge
**Mistake:** `git rebase main` on an old branch after a squash-merge → conflicts, duplicate commits.
**Fix:** After a squash-merge, DO NOT rebase. Create a NEW branch from `origin/main`.

### P3. Pre-commit hook exit code
**Mistake:** Hook returns exit code ≠ 0, Claude assumes the commit failed → creates a duplicate.
**Fix:** Always check `git log --oneline -1` after a commit. The hook may have fixed files and the commit may have succeeded.

### P4. Case sensitivity on Windows
**Mistake:** `git add src/Components/...` instead of `src/components/...` → Git on Windows doesn't report an error, but CI on Linux fails.
**Fix:** Copy the exact path from `git status`, don't type from memory.

### P5. Resolving review threads without reading
**Mistake:** Bulk `resolveReviewThread` via GraphQL without reading comment content → missing a real bug.
**Fix:** ALWAYS fetch thread content (section 9), read each one, THEN resolve.

### P6. Squash-merge pulls in stale lockfile
**Mistake:** Squash takes the diff branch→main. If the branch was based on an old main, the lockfile may revert fixes.
**Fix:** After a squash-merge: check `package.json` and `package-lock.json` on main (section 11 below).

### P7. "In Progress" in GitHub Project = don't touch
**Mistake:** Starting work on an issue marked "In Progress" → conflict with another Claude Code instance.
**Fix:** Check the status in GitHub Project BEFORE starting work. "In Progress" = another instance is already working on it.


## 11. Post Squash-Merge — Mandatory Verification

Squash-merge takes the **full branch diff vs base**, not the last commit. A stale branch state can pull in reverted changes.

After every squash-merge, run this (< 30 seconds):

```bash
# 1. Check key dependencies on main
git fetch origin
git show origin/main:package.json | grep -E '"netlify-cli|"serialize-javascript'

# 2. Check lockfile (whether the optional:true fix didn't vanish)
git show origin/main:package-lock.json | python3 -c "
import json,sys
d=json.load(sys.stdin)
missing=[k for k,v in d.get('packages',{}).items()
         if 'netlify-cli/node_modules' in k
         and ('os' in v or 'cpu' in v)
         and not v.get('optional')]
print(f'BRAK optional:true: {len(missing)} wpisów — NAPRAW!' if missing else 'OK — lockfile czysty')
"
```

If anything is off → **STOP, investigate before pushing**.

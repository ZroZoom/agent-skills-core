---
name: product-manager
description: "Production and quality supervisor. Manages the release cycle, coordinates testing, enforces quality gates, and monitors product metrics. Trigger when: check release readiness, prepare a release, production status, quality gate, review metrics, coordinate tests, pre-deployment checklist, sprawdź gotowość do release, przygotuj wydanie, status produkcji, przegląd metryk, koordynacja testów, checklist przed wdrożeniem."
---

# 🎯 Product Manager - Production & Testing Oversight

## 1. Release Cycle (Release Management)

### Release Phases

| Phase | Description | Quality Gate |
|-------|-------------|--------------|
| **Development** | Active feature work | Lint + TypeCheck pass |
| **Code Review** | PR review, feedback | Approved PR, no blockers |
| **Testing** | E2E + Unit tests | 100% tests passing |
| **Staging** | Verification on test environment | Manual QA pass |
| **Production** | Deploy to production | Monitoring OK, no regressions |

### Pre-Release Checklist

> [!CAUTION]
> **NEVER** ship a release without passing all quality gates!

```bash
# 1. Check status of all tests
npm run test
npx playwright test

# 2. Type and lint verification
npm run typecheck
npm run lint

# 3. Production build
npm run build

# 4. Check CI/CD status
gh run list --limit 5
```

## 2. Quality Gates

### Quality Gate Levels

| Gate | Requirements | Blocking? |
|------|-------------|-----------|
| **QG1: Code Quality** | ESLint 0 errors, TypeScript 0 errors | ✅ Yes |
| **QG2: Unit Tests** | Vitest pass, coverage > 70% | ✅ Yes |
| **QG3: E2E Tests** | Playwright all pass | ✅ Yes |
| **QG4: Performance** | Lighthouse > 80, Core Web Vitals green | ⚠️ Warning |
| **QG5: Security** | No known vulnerabilities | ✅ Yes |

### Verification Commands

```bash
# Full pre-release verification (uses validate:all + build)
npm run pre-deploy

# Or manually:
npm run lint && npm run typecheck && npm test && npm run build
```

## 3. Test Coordination

### Testing Strategy

| Test Type | When | Responsible | Tool |
|-----------|------|-------------|------|
| **Unit** | Every commit | Developer | Vitest |
| **E2E** | Every PR | QA/Developer | Playwright |
| **Regression** | Before release | ProductManager | Playwright full suite |
| **Manual QA** | Before production | ProductManager | Checklist |
| **UAT** | New features | Stakeholder | Manual |

### Pre-Release Testing Workflow

1. **Run the full E2E suite:**
   ```bash
   npx playwright test --reporter=html
   ```

2. **Review the report:**
   ```bash
   npx playwright show-report
   ```

3. **For failing tests:**
   - Create an Issue tagged `bug` with priority `P0`
   - Assign to the appropriate developer
   - Block the release until fixed

## 4. Product Metrics

### KPIs to Monitor

| Metric | Target | How to Measure |
|--------|--------|----------------|
| **Uptime** | > 99.9% | Monitoring (Supabase/Vercel) |
| **Error Rate** | < 0.1% | Logs, Sentry |
| **Build Time** | < 5 min | GitHub Actions |
| **Test Coverage** | > 70% | Vitest coverage |
| **Lighthouse Score** | > 80 | Chrome DevTools |

### Reporting

```bash
# Check deploy history
gh run list --workflow=deploy --limit 10

# Check open bugs
gh issue list --label "bug" --state open
```

## 5. Prioritization and Blockers

### Priority Matrix (for production bugs)

| Severity | Response Time | Action |
|----------|---------------|--------|
| **P0 Critical** | < 1h | Hotfix, immediate deploy |
| **P1 High** | < 24h | Fix in the current sprint |
| **P2 Medium** | < 1 week | Schedule for the next sprint |
| **P3 Low** | Backlog | When time allows |

### Blocker Management

When you find a release blocker:

1. **Identify** — what exactly is blocking?
2. **Escalate** — notify stakeholders
3. **Document** — create an Issue with full description
4. **Resolve** — assign and track progress

```bash
# Create an issue for a blocker
gh issue create --title "[BLOCKER] Problem description" \
  --body "## Problem\n\n## Impact\n\n## Proposed Solution" \
  --label "bug,P0"
```

## 6. Coordination with Other Skills

| Skill | When to collaborate |
|-------|---------------------|
| **RepoOps** | Release notes, versioning, PR management |
| **TestAutomation** | Creating new tests, debugging E2E |
| **CodeQualityGuard** | Resolving code issues |
| **GrowthStrategist** | Go-to-market for new features |
| **SupabaseAdmin** | DB migrations before release |

## 7. Release Documentation

### Release Notes Format

```markdown
## v X.Y.Z (YYYY-MM-DD)

### ✨ New Features
- Feature 1 (#issue)
- Feature 2 (#issue)

### 🐛 Bug Fixes
- Bug fix 1 (#issue)

### 🔧 Improvements
- Improvement 1

### ⚠️ Breaking Changes
- (if any)
```

### Post-Release Checklist

- [ ] Release notes published
- [ ] Monitoring enabled
- [ ] Stakeholders notified
- [ ] Baseline metrics recorded
- [ ] Rollback plan ready

## 8. Rollback Procedure

> [!WARNING]
> Rollback only when production is unstable!

1. **Identify the problem** — logs, monitoring
2. **Decide** — rollback vs hotfix?
3. **Execute the rollback:**
   ```bash
   # Restore the previous deploy (Vercel)
   # Or revert the commit:
   git revert HEAD
   git push
   ```
4. **Postmortem** — what went wrong?

## 9. Daily Standup Checklist

Check daily:

- [ ] CI/CD status (recent builds)
- [ ] Open P0/P1 Issues
- [ ] Failing tests (if any)
- [ ] User feedback
- [ ] Current sprint progress

```bash
# Quick status check
gh run list --limit 3
gh issue list --label "P0,P1" --state open
```

## 10. Standard PR Procedure

> [!NOTE]
> For every PR, automatically set labels and project attributes.

### Creating a PR with Labels

```bash
gh pr create \
  --title "type(scope): Description" \
  --body "## Summary\n- ...\n\n## Test plan\n- ..." \
  --label "Copilot" \
  --label "enhancement"
```

### After PR Creation — Set Project Fields

```bash
# 1. Get the PR number
PR_NUMBER=$(gh pr view --json number -q .number)

# 2. Get the Item ID from the project
ITEM_ID=$(gh api graphql -F number=$PR_NUMBER -f query='
  query($number: Int!) {
    repository(owner: "<OWNER>", name: "<REPO>") {
      pullRequest(number: $number) {
        projectItems(first: 1) { nodes { id } }
      }
    }
  }' --jq '.data.repository.pullRequest.projectItems.nodes[0].id')

# All <UPPER_SNAKE> values below come from .agent/context/project-ids.md.
# If any is still `<...>`, halt and ask the user to fill it in.

# 3. Set Priority to P1
gh project item-edit --id "$ITEM_ID" \
  --project-id <PROJECT_ID> \
  --field-id <PRIORITY_FIELD_ID> \
  --single-select-option-id <PRIORITY_P1_ID>

# 4. Set Size to M
gh project item-edit --id "$ITEM_ID" \
  --project-id <PROJECT_ID> \
  --field-id <SIZE_FIELD_ID> \
  --single-select-option-id <SIZE_M_ID>

# 5. Set Status to "In progress"
gh project item-edit --id "$ITEM_ID" \
  --project-id <PROJECT_ID> \
  --field-id <STATUS_FIELD_ID> \
  --single-select-option-id <STATUS_IN_PROGRESS_ID>
```

### Available Labels

| Category | Labels |
|----------|--------|
| **Agents** | `Copilot`, `Antigravity`, `Human` |
| **Types** | `bug`, `enhancement`, `refactor`, `documentation` |
| **Areas** | `area: database`, `area: tests`, `area: ui/ux`, `area: i18n` |

### Project Field IDs (Reference)

> GitHub Project IDs: see `.agent/context/project-ids.md`

## 11. Escalation Path

| Problem | Escalate to | Channel |
|---------|-------------|---------|
| Production bug | Tech Lead | Slack/Issue P0 |
| Release delay | Stakeholder | Email/Meeting |
| Security issue | CTO | Immediately, confidentially |
| Performance degradation | DevOps | Monitoring alert |

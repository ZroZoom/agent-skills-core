---
name: release-notes
description: "Release notes generator. Collects merged PRs since the latest tag, groups by type, and emits Polish and English changelog markdown. Trigger when: /release-notes, changelog, release notes, notatki wydania."
---

# Release Notes Skill

Generate a bilingual changelog from merged PRs.

## Contract

- Inputs: optional `--since <tag|date>`, `--until <date>`, `--target team|investors|both`.
- Output: markdown release notes in PL and EN.
- Side effects: none unless the user asks to create a GitHub Release or commit a changelog.

## Workflow

### 1. Resolve range

Prefer an explicit `--since`. Otherwise use the newest tag:

```bash
git fetch --tags origin
git tag --sort=-creatordate | head -5
git describe --tags --abbrev=0
```

If there are no tags, use the last merged release PR or a date confirmed by the user.

### 2. Collect merged PRs

For a tag range:

```bash
BASE_TAG=vX.Y.Z
BASE_DATE=$(git log -1 --format=%cI "$BASE_TAG")

gh pr list \
  --repo <OWNER>/<REPO> \
  --state merged \
  --search "merged:>=$BASE_DATE base:main" \
  --limit 200 \
  --json number,title,mergedAt,author,labels,url
```

Also inspect commits if PR data is incomplete:

```bash
git log --oneline "$BASE_TAG"..HEAD
```

### 3. Group changes

Use title prefixes first, then labels:

| Group | Signals |
|---|---|
| Features | `feat`, `enhancement`, user-visible additions |
| Fixes | `fix`, `bug`, regressions, production issues |
| Content | `content`, copy / docs changes |
| Tests and QA | `test`, `area: tests`, Playwright/Vitest/manual QA |
| Tooling | `chore`, `ci`, `tooling`, scripts, agent skills |
| Docs | `docs`, documentation-only changes |

Exclude noise:

- version bump PRs unless they are the release itself
- reverted PRs when the revert also merged in range
- duplicate squash commits

### 4. Write PL and EN outputs

Team format:

```markdown
## Release notes PL

### Najważniejsze zmiany
- ...

### Funkcje
- ...

### Poprawki
- ...

### Testy i tooling
- ...

### Ryzyka i follow-up
- ...
```

Investor format:

```markdown
## Release notes EN

### Highlights
- ...

### Product progress
- ...

### Quality and reliability
- ...

### Next risks
- ...
```

## Rules

- Keep every bullet traceable to a PR number.
- Do not invent impact metrics.
- Translate meaning, not commit prefixes.
- Mention incomplete CI or unmerged PRs only in a separate `Not included` section.
- If the range is ambiguous, ask for the range before generating final notes.

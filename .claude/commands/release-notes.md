# Release Notes

Generate bilingual release notes from merged PRs since the latest tag or a provided range.

Load `.agent/skills/release-notes/SKILL.md` and follow it.

## Arguments

- `--since <tag|YYYY-MM-DD>` optional.
- `--until <YYYY-MM-DD>` optional.
- `--target team|investors|both` optional, default `both`.

## Required flow

1. Resolve the comparison range.
2. Collect merged PRs on `main`.
3. Group changes into features, fixes, content, tests/QA, tooling, and docs.
4. Produce markdown in Polish and English.

Every bullet must reference a PR number. Do not invent impact metrics.

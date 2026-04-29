# Branch rulesets

Versioned GitHub branch rulesets for this template. Apply them once after creating a new repo from the template (and re-apply whenever you change them).

## Available rulesets

| File | When to use |
|---|---|
| `main-branch-protection.json` | **Default.** Solo dev + bots. PR required, no required reviewer, force-push and deletion blocked, conversations must be resolved, squash-only, linear history. |
| `main-branch-protection-with-ci.json` | Stricter variant. All of the above + named CI status checks (`lint`, `typecheck`, `test`). Edit the `required_status_checks` list to match your workflow's job names. |

Both files target `~DEFAULT_BRANCH`, so they work whether your default branch is `main`, `master`, or anything else.

## Apply

```bash
# Default ruleset, current repo
./scripts/apply-rulesets.sh

# Stricter variant, current repo
./scripts/apply-rulesets.sh main-branch-protection-with-ci

# Different repo
REPO=acme/widget ./scripts/apply-rulesets.sh
```

The script is **idempotent** — it updates the ruleset if one with the same `name` exists, otherwise creates a new one.

## What this enforces

- **Pull request required** for every change to the default branch. Direct commits to `main` are refused, in line with `CLAUDE.md` → `Git Rules`.
- **Force-push blocked** (`non_fast_forward`).
- **Branch deletion blocked** (`deletion`).
- **Linear history** (no merge commits on `main` — squash only).
- **Stale reviews dismissed on new push** — when an approved PR gets a follow-up commit, the approval is dismissed and reviewers re-review.
- **All review threads must be resolved** before merge — bot threads (Copilot, Gemini) block merge just like human ones, matching the workflow in `repo-ops/SKILL.md`.
- **Squash-only merging** — keeps `main`'s history clean and aligned with the linear-history requirement.

## What this does NOT enforce (by design, in the default ruleset)

- **Required approving reviewers.** Solo devs and tightly coupled small teams don't need this. Switch to `main-branch-protection-with-ci.json` and bump `required_approving_review_count` to `1` once you have collaborators.
- **Signed commits.** Add the `required_signatures` rule when working in a regulated environment.
- **Bypass list.** Empty by default. Add admin actors here only if you need a documented escape hatch.

## Verifying

```bash
gh api repos/<OWNER>/<REPO>/rulesets --jq '.[] | {id, name, enforcement, ref: .conditions.ref_name.include}'
```

Test a refusal:

```bash
git checkout main
git commit --allow-empty -m "should fail"
git push   # → remote refuses with "rule violation: changes must be made through a pull request"
```

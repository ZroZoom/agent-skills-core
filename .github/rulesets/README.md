# Branch rulesets

Versioned GitHub branch rulesets for this template. Apply them once after creating a new repo from the template (and re-apply whenever you change them).

## Available rulesets

| File | When to use |
|---|---|
| `main-branch-protection.json` | **Default.** Solo dev + bots. PR required, no required reviewer, force-push and deletion blocked, conversations must be resolved, squash-only, linear history. |
| `main-branch-protection-with-ci.json` | Stricter variant. All of the above + named CI status checks (`lint`, `typecheck`, `test`). Edit the `required_status_checks` list to match your workflow's job names. |
| `main-branch-protection-with-bots-and-queue.json` | **Production-grade.** Full setup as used in `ZroZoom/Szkola_Przyszlosci_AI`: strict CI checks (branch must be up-to-date), automatic Copilot code review on every push (including drafts), and a merge queue with batch builds. |

All three target `~DEFAULT_BRANCH`, so they work whether your default branch is `main`, `master`, or anything else.

## Apply

```bash
# Default ruleset, current repo
./scripts/apply-rulesets.sh

# Stricter variant, current repo
./scripts/apply-rulesets.sh main-branch-protection-with-ci

# Production-grade (Copilot review + merge queue)
./scripts/apply-rulesets.sh main-branch-protection-with-bots-and-queue

# Different repo
REPO=acme/widget ./scripts/apply-rulesets.sh
```

The script is **idempotent** — it updates the ruleset if one with the same `name` exists, otherwise creates a new one. All three variants share the name `main-branch-protection`, so applying a different variant **replaces** the previous one.

## What each ruleset enforces

### Common to all three (the universal core)

- **Pull request required** for every change to the default branch. Direct commits to `main` are refused, in line with `CLAUDE.md` → `Git Rules`.
- **Force-push blocked** (`non_fast_forward`).
- **Branch deletion blocked** (`deletion`).
- **Linear history** (no merge commits — squash only).
- **Stale reviews dismissed on new push** — when an approved PR gets a follow-up commit, the approval is dismissed and reviewers re-review.
- **All review threads must be resolved** before merge — bot threads (Copilot, Gemini) block merge just like human ones, matching the workflow in `repo-ops/SKILL.md`.
- **Squash-only merging** — keeps `main`'s history clean and aligned with the linear-history requirement.

### Default-only

Nothing extra. Designed for a fresh repo before CI exists — applies the universal core and gets out of the way.

### `with-ci` adds

- **`required_status_checks`** with three job names: `lint`, `typecheck`, `test`. Edit the list to match your workflow's actual job names.
- `strict_required_status_checks_policy: false` — the branch does NOT have to be up-to-date with `main` before merge (lighter gate, still safe for small teams).

### `with-bots-and-queue` adds (on top of `with-ci`)

- `strict_required_status_checks_policy: **true**` — branch must be up-to-date before merge. Combined with the merge queue, this means CI runs once per batch on the queue's HEAD, not on every PR push.
- **`copilot_code_review`** — Copilot reviews every push (including drafts). Without this rule, Copilot only reviews when you toggle it manually in the PR UI.
- **`merge_queue`** — PRs land in batches of 2-5; queue waits up to 30 min for a batch to fill; `ALLGREEN` strategy means a single failure unqueues the offender without unqueueing the rest. Saves significant CI minutes on busy repos.
- A fourth required check (`build`) — the production setup runs build separately from typecheck.

> **Note on names:** the production source (`ZroZoom/Szkola_Przyszlosci_AI`) uses emoji-prefixed check contexts (`🧪 Unit Tests`, `🔍 ESLint`, `📘 TypeScript`, `🎭 E2E Tests`, etc.). The template uses plain ASCII names so they match a clean Actions setup. Replace them with whatever your workflows actually emit.

## What none of these enforce (by design)

- **Required approving reviewers.** Solo devs and tightly coupled small teams don't need this. Bump `required_approving_review_count` to `1` once you have collaborators (and consider `require_code_owner_review: true`).
- **Signed commits.** Add the `required_signatures` rule when working in a regulated environment.
- **Bypass list.** Empty by default. Add admin actors here only if you need a documented escape hatch.

## Verifying

```bash
gh api repos/<OWNER>/<REPO>/rulesets --jq '.[] | {id, name, enforcement, ref: .conditions.ref_name.include}'
gh api repos/<OWNER>/<REPO>/rulesets/<ID> --jq '{name, rules: [.rules[].type]}'
```

Test a refusal:

```bash
git checkout main
git commit --allow-empty -m "should fail"
git push   # → remote refuses with "rule violation: changes must be made through a pull request"
```

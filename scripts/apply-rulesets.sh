#!/usr/bin/env bash
# Apply (or update) GitHub branch rulesets from .github/rulesets/*.json
#
# Usage:
#   scripts/apply-rulesets.sh                                # apply main-branch-protection.json
#   scripts/apply-rulesets.sh main-branch-protection-with-ci # apply named ruleset
#   REPO=acme/widget scripts/apply-rulesets.sh               # target another repo
#
# Idempotent: if a ruleset with the same name already exists in the repo, it's updated; otherwise created.
# Requires: gh (authenticated), jq.

set -euo pipefail

RULESET_NAME="${1:-main-branch-protection}"
RULESET_FILE=".github/rulesets/${RULESET_NAME}.json"

if [[ ! -f "$RULESET_FILE" ]]; then
  echo "✗ Ruleset file not found: $RULESET_FILE" >&2
  exit 1
fi

# Resolve target repo (current repo by default)
REPO="${REPO:-$(gh repo view --json nameWithOwner --jq '.nameWithOwner')}"

echo "→ Applying $RULESET_FILE to $REPO"

# Strip the _comment field before sending (GitHub rejects unknown fields)
PAYLOAD=$(jq 'del(._comment)' "$RULESET_FILE")

# Find existing ruleset by name. We DON'T interpolate the name into the gh --jq
# filter (that would be vulnerable to jq-filter injection if a ruleset name ever
# contained quotes or special chars). Instead, fetch JSON, then pipe through a
# standalone jq with --arg, which guarantees the value is treated as a literal.
RULESET_NAME_VALUE=$(jq -r .name "$RULESET_FILE")
EXISTING_ID=$(gh api "repos/$REPO/rulesets" \
  | jq -r --arg name "$RULESET_NAME_VALUE" '.[] | select(.name == $name) | .id' \
  | head -n1)

if [[ -n "$EXISTING_ID" ]]; then
  echo "  Updating existing ruleset id=$EXISTING_ID"
  gh api -X PUT "repos/$REPO/rulesets/$EXISTING_ID" \
    --input - <<<"$PAYLOAD" \
    --jq '{id, name, enforcement, rules: [.rules[].type]}'
else
  echo "  Creating new ruleset"
  gh api -X POST "repos/$REPO/rulesets" \
    --input - <<<"$PAYLOAD" \
    --jq '{id, name, enforcement, rules: [.rules[].type]}'
fi

echo "✓ Done"

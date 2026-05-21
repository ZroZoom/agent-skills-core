#!/usr/bin/env bash
# scripts/enable-overlay.sh
#
# Activate a stack/domain overlay by copying its skill directories into
# .agent/skills/ so they register as active skills.
#
# Usage:
#   scripts/enable-overlay.sh <overlay-name> [--force]
#
# Example:
#   scripts/enable-overlay.sh next-vercel
#
# Overlays live under .agent/overlays/<overlay-name>/. Each immediate
# subdirectory that contains a SKILL.md is treated as a skill and copied to
# .agent/skills/<skill>/. The overlay's own README.md is not a skill and is
# skipped. The copy refuses to overwrite an existing skill of the same name
# unless --force is given. The overlay source is never modified.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OVERLAYS_DIR="${REPO_ROOT}/.agent/overlays"
SKILLS_DIR="${REPO_ROOT}/.agent/skills"

usage() {
    echo "Usage: scripts/enable-overlay.sh <overlay-name> [--force]" >&2
    echo "Available overlays:" >&2
    if [ -d "$OVERLAYS_DIR" ]; then
        find "$OVERLAYS_DIR" -mindepth 1 -maxdepth 1 -type d -printf '  %f\n' >&2
    else
        echo "  (none — $OVERLAYS_DIR does not exist)" >&2
    fi
}

OVERLAY=""
FORCE=0
for arg in "$@"; do
    case "$arg" in
        --force) FORCE=1 ;;
        -h|--help) usage; exit 0 ;;
        --*) echo "Unknown flag: $arg" >&2; usage; exit 1 ;;
        *)
            if [ -n "$OVERLAY" ]; then
                echo "Only one overlay name allowed (got '$OVERLAY' and '$arg')" >&2
                exit 1
            fi
            OVERLAY="$arg"
            ;;
    esac
done

if [ -z "$OVERLAY" ]; then
    usage
    exit 1
fi

OVERLAY_PATH="${OVERLAYS_DIR}/${OVERLAY}"
if [ ! -d "$OVERLAY_PATH" ]; then
    echo "Overlay not found: $OVERLAY_PATH" >&2
    usage
    exit 1
fi

mkdir -p "$SKILLS_DIR"

copied=0
skipped=0
while IFS= read -r skill_md; do
    skill_dir="$(dirname "$skill_md")"
    skill_name="$(basename "$skill_dir")"
    dest="${SKILLS_DIR}/${skill_name}"
    if [ -e "$dest" ] && [ "$FORCE" -ne 1 ]; then
        echo "skip  ${skill_name} (already in .agent/skills/; pass --force to overwrite)"
        skipped=$((skipped + 1))
        continue
    fi
    rm -rf "$dest"
    cp -R "$skill_dir" "$dest"
    echo "copy  ${skill_name} -> .agent/skills/${skill_name}/"
    copied=$((copied + 1))
done < <(find "$OVERLAY_PATH" -mindepth 2 -maxdepth 2 -name SKILL.md)

echo ""
echo "Enabled overlay '${OVERLAY}': ${copied} skill(s) copied, ${skipped} skipped."
if [ "$copied" -gt 0 ]; then
    echo "Next: python3 scripts/fill-placeholders.py --interactive"
fi

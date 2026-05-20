#!/usr/bin/env python3
"""
Validate cross-references inside the agent-skills-core template itself.

The goal is to catch broken pointers like the ones Codex flagged in PR review:
- /review listing memory files that don't exist (feedback_copilot-scope-nag.md)
- repo-ops pointing at .agent/workflows/repository-management.md that was never added

What we DO check:
- References (Markdown links + backticked paths) that target files inside
  the template's own scope: .agent/, .claude/, scripts/, .github/, plus the
  root files (CLAUDE.md, README.md, LICENSE).

What we DO NOT check (intentional):
- Paths pointing at the consumer project (e.g. package.json, src/, tsconfig.json,
  docs/, ROADMAP.md). The template references these as illustrative paths;
  they only need to exist in the project that uses the template.
- HTTP/HTTPS links, mailto, anchors, placeholders (<...>, $VAR, @user).

Outputs:
- exit 0 + summary on success
- exit 1 + ::error annotations on broken in-scope references
"""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

# Files / dirs whose references SHOULD exist inside the template.
# Anything outside this set is treated as a consumer-project reference and skipped.
IN_SCOPE_DIRS = (".agent/", ".claude/", "scripts/", ".github/")
IN_SCOPE_ROOT_FILES = {"CLAUDE.md", "README.md", "LICENSE"}

# Directories that contain Markdown files we want to scan.
SOURCE_DIRS = (".agent", ".claude")
SOURCE_ROOT_FILES = ("CLAUDE.md", "README.md")

INLINE_CODE_RE = re.compile(r"`([^`\n]+?)`")
MD_LINK_RE = re.compile(r"\[(?:[^\]]+)\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")
PATH_LIKE_RE = re.compile(r"^[\w./-]+\.(md|json|sh|yml|yaml)$")
ANCHOR_RE = re.compile(r"#.*$")

PLACEHOLDER_PREFIXES = ("<", "$", "@", "{{")


def is_external(ref: str) -> bool:
    return (
        ref.startswith(("http://", "https://", "mailto:"))
        or ref.startswith(PLACEHOLDER_PREFIXES)
    )


def is_in_scope(ref: str) -> bool:
    """Decide whether a reference targets the template (so it must exist) or the
    consumer project (so it's an illustrative path and we don't enforce)."""
    ref = ref.lstrip("./")
    if ref in IN_SCOPE_ROOT_FILES:
        return True
    return ref.startswith(IN_SCOPE_DIRS)


def resolve(source: Path, ref: str) -> Path | None:
    if is_external(ref):
        return None
    ref = ANCHOR_RE.sub("", ref)
    if not ref:
        return None
    if ref.startswith("/"):
        target = (REPO_ROOT / ref.lstrip("/")).resolve()
    else:
        # Bare root-file references (e.g. `CLAUDE.md`, `README.md`) are commonly
        # used as a friendly shorthand for `<repo>/CLAUDE.md` even from deeper
        # directories. If the bare file exists at the repo root, prefer that.
        bare = ref.lstrip("./")
        if bare in IN_SCOPE_ROOT_FILES and (REPO_ROOT / bare).exists():
            target = (REPO_ROOT / bare).resolve()
        # Repo-rooted paths to in-scope dirs (e.g. `scripts/foo.sh`, `.agent/skills/x/SKILL.md`)
        # are commonly written without a leading slash. Resolve them from the
        # repo root when the file actually exists there; this avoids spurious
        # broken-link reports when a deep SKILL.md points at a shared script.
        elif bare.startswith(IN_SCOPE_DIRS) and (REPO_ROOT / bare).exists():
            target = (REPO_ROOT / bare).resolve()
        else:
            target = (source.parent / ref).resolve()
    # Only validate references inside the repo
    try:
        target.relative_to(REPO_ROOT)
    except ValueError:
        return None
    return target


def collect_refs() -> list[tuple[Path, int, str]]:
    refs: list[tuple[Path, int, str]] = []
    sources: list[Path] = []
    for d in SOURCE_DIRS:
        base = REPO_ROOT / d
        if base.is_dir():
            sources.extend(base.rglob("*.md"))
    for f in SOURCE_ROOT_FILES:
        p = REPO_ROOT / f
        if p.exists():
            sources.append(p)
    for md in sources:
        text = md.read_text(encoding="utf-8", errors="replace")
        for line_no, line in enumerate(text.splitlines(), start=1):
            for m in MD_LINK_RE.finditer(line):
                refs.append((md, line_no, m.group(1)))
            for m in INLINE_CODE_RE.finditer(line):
                cand = m.group(1).strip()
                if PATH_LIKE_RE.match(cand):
                    refs.append((md, line_no, cand))
    return refs


def main() -> int:
    in_ci = os.environ.get("GITHUB_ACTIONS", "").lower() == "true"
    refs = collect_refs()

    in_scope = 0
    broken: list[tuple[Path, int, str]] = []

    for source, line_no, ref in refs:
        if not is_in_scope(ref):
            continue
        in_scope += 1
        target = resolve(source, ref)
        if target is None:
            continue
        if not target.exists():
            broken.append((source, line_no, ref))

    print(f"→ {len(refs)} candidate references found.")
    print(f"→ {in_scope} in-scope references checked (template-internal).")
    print(f"→ {len(refs) - in_scope} consumer-project references skipped.")

    if not broken:
        print("\n✓ All in-scope references resolve.")
        return 0

    print(f"\n✗ {len(broken)} broken in-scope references:\n")
    for source, line_no, ref in broken:
        rel = source.relative_to(REPO_ROOT)
        if in_ci:
            print(f"::error file={rel},line={line_no}::broken reference: `{ref}`")
        else:
            print(f"  {rel}:{line_no}  →  {ref}")
    return 1


if __name__ == "__main__":
    sys.exit(main())

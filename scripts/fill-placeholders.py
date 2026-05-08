#!/usr/bin/env python3
"""
Cross-platform placeholder bootstrapper for agent-skills-core.

Replaces `<UPPER_SNAKE>` placeholders across .agent/, .claude/, CLAUDE.md, README.md
with values you provide. Safer than `sed -i` (which behaves differently on GNU/Linux
and macOS) and idempotent.

Usage:
    python3 scripts/fill-placeholders.py --owner my-org --repo my-app

    # interactive setup wizard:
    python3 scripts/fill-placeholders.py --interactive

    # with more placeholders:
    python3 scripts/fill-placeholders.py \\
        --owner my-org \\
        --repo my-app \\
        --domain-primary my-app.com \\
        --domain-secondary my-app.io \\
        --jira-project-key MYAPP \\
        --jira-cloud-id 1234abcd-... \\
        --tester-account-id 5678efgh-... \\
        --dry-run

Run with --help for the full list of supported placeholders.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

# Each entry: (CLI flag, placeholder shown in repo, help text)
PLACEHOLDERS: list[tuple[str, str, str]] = [
    ("owner",                 "<OWNER>",                 "GitHub org or user (e.g. acme)"),
    ("repo",                  "<REPO>",                  "GitHub repo name (e.g. widget)"),
    ("domain-primary",        "<DOMAIN_PRIMARY>",        "Primary production domain (e.g. acme.com)"),
    ("domain-secondary",      "<DOMAIN_SECONDARY>",      "Secondary production domain (e.g. acme.app)"),
    ("site-name-primary",     "<SITE_NAME_PRIMARY>",     "Primary hosting site name (e.g. acme-prod)"),
    ("site-id-primary",       "<SITE_ID_PRIMARY>",       "Primary hosting site ID (UUID-ish)"),
    ("site-name-secondary",   "<SITE_NAME_SECONDARY>",   "Secondary hosting site name"),
    ("site-id-secondary",     "<SITE_ID_SECONDARY>",     "Secondary hosting site ID"),
    ("jira-project-key",      "<JIRA_PROJECT_KEY>",      "Jira project key (e.g. ACME)"),
    ("jira-cloud-id",         "<JIRA_CLOUD_ID>",         "Jira cloud ID (UUID)"),
    ("tester-account-id",     "<TESTER_ACCOUNT_ID>",     "Default Jira tester account ID"),
    ("project-id",            "<PROJECT_ID>",            "GitHub Project (v2) node ID (PVT_...)"),
    ("project-number",        "<PROJECT_NUMBER>",        "GitHub Project (v2) number"),
    ("status-field-id",       "<STATUS_FIELD_ID>",       "GitHub Project Status field ID (PVTSSF_...)"),
    ("priority-field-id",     "<PRIORITY_FIELD_ID>",     "GitHub Project Priority field ID"),
    ("size-field-id",         "<SIZE_FIELD_ID>",         "GitHub Project Size field ID"),
    ("supabase-project-ref",  "<SUPABASE_PROJECT_REF>",  "Supabase project ref (if applicable)"),
    ("storage-base-url",      "<STORAGE_BASE_URL>",      "Public base URL of the blog-images bucket"),
    ("product-stats-file",    "<PRODUCT_STATS_FILE>",    "Path to your generated product stats file"),
    ("demo-milestone",        "<DEMO_MILESTONE>",        "Milestone title used by /demo-check (e.g. M0)"),
]

# Files outside the repo's tracked content shouldn't be touched.
TARGET_DIRS = [".agent", ".claude"]
TARGET_FILES = ["CLAUDE.md", "README.md"]
SKIP_DIRS = {".git", "node_modules", ".venv", "__pycache__"}


def gather_files(root: Path) -> list[Path]:
    paths: list[Path] = []
    for d in TARGET_DIRS:
        base = root / d
        if not base.is_dir():
            continue
        for p in base.rglob("*"):
            if any(part in SKIP_DIRS for part in p.parts):
                continue
            if p.is_file() and p.suffix in {".md", ".json", ".sh", ".yml", ".yaml"}:
                paths.append(p)
    for f in TARGET_FILES:
        p = root / f
        if p.exists():
            paths.append(p)
    return paths


def build_replacements(args: argparse.Namespace) -> list[tuple[str, str]]:
    """Build replacement pairs from flags and, optionally, interactive prompts."""
    replacements: dict[str, str] = {}
    for flag, placeholder, _ in PLACEHOLDERS:
        value = getattr(args, flag.replace("-", "_"))
        if value:
            replacements[placeholder] = value

    if not args.interactive:
        return list(replacements.items())

    print("Interactive placeholder setup")
    print("Leave a value blank to skip it. Values passed as flags are kept.\n")

    for flag, placeholder, help_text in PLACEHOLDERS:
        if placeholder in replacements:
            print(f"{placeholder} already set from --{flag}: {replacements[placeholder]}")
            continue
        try:
            value = input(f"{placeholder} — {help_text} [skip]: ").strip()
        except EOFError:
            print()
            break
        if value:
            replacements[placeholder] = value

    print()
    return list(replacements.items())


def main() -> int:
    parser = argparse.ArgumentParser(
        prog="fill-placeholders.py",
        description="Replace <UPPER_SNAKE> placeholders across the agent-skills-core template.",
    )
    for flag, placeholder, help_text in PLACEHOLDERS:
        parser.add_argument(f"--{flag}", help=f"{help_text} (replaces `{placeholder}`)")
    parser.add_argument(
        "--root",
        default=".",
        help="Repository root (default: current directory).",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would change without writing files.",
    )
    parser.add_argument(
        "--interactive",
        action="store_true",
        help="Prompt for placeholder values in a terminal wizard. Blank answers are skipped.",
    )
    args = parser.parse_args()

    root = Path(args.root).resolve()
    if not root.exists():
        print(f"✗ Root does not exist: {root}", file=sys.stderr)
        return 1

    replacements = build_replacements(args)

    if not replacements:
        print("✗ No replacements specified. Pass flags or run with --interactive.", file=sys.stderr)
        print("  Run with --help to see all flags.", file=sys.stderr)
        return 1

    print(f"→ Root: {root}")
    print(f"→ Replacements: {len(replacements)}")
    for placeholder, value in replacements:
        print(f"    {placeholder}  →  {value}")
    print()

    files = gather_files(root)
    print(f"→ Scanning {len(files)} files…\n")

    total_changes = 0
    files_changed = 0
    for path in files:
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        new_text = text
        file_changes = 0
        for placeholder, value in replacements:
            count = new_text.count(placeholder)
            if count:
                new_text = new_text.replace(placeholder, value)
                file_changes += count
        if file_changes:
            rel = path.relative_to(root)
            print(f"  {file_changes:>3}× in {rel}")
            total_changes += file_changes
            files_changed += 1
            if not args.dry_run:
                path.write_text(new_text, encoding="utf-8")

    print()
    if args.dry_run:
        print(f"✓ Dry-run complete: {total_changes} replacements across {files_changed} files (no writes).")
    else:
        print(f"✓ Done: {total_changes} replacements across {files_changed} files.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

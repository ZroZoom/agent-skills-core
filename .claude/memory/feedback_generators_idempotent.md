---
name: Make generators content-aware idempotent
description: Build-time generators should skip writing when output is structurally unchanged. Avoids dirty working tree on Windows from CRLF/LF differences.
type: feedback
---

If your project commits generated files (e.g. JSON indexes, type files, route manifests), every generator should use a content-aware "skip-if-unchanged" pattern. `npm run build` should NOT leave a dirty working tree just from CRLF/LF or whitespace differences.

**Why:** On Windows with `core.autocrlf=true`, generators that always rewrite files convert LF→CRLF on checkout and then write LF on build, leaving "modified" status with zero structural delta. This blocks `git checkout main` and `git merge origin/main`, and forces agents to run a `git checkout -- <files>` discard ritual.

**How to apply:**
- If you write a generator that emits a tracked JSON/text file, mirror a `writeJsonIfChanged` helper. Don't `writeFileSync` unconditionally.
- Comparison strategy: `JSON.parse(existing)` → `JSON.stringify(parsed, null, 2)` === `JSON.stringify(new, null, 2)` → skip write. This normalizes EOL and harmless format drift.
- Stronger version: a `normalizeJson` that sorts keys recursively before compare, so manual key reorderings don't trigger rewrites.
- If your output contains a timestamp (e.g. `generatedAt`), strip it before compare; otherwise the file is "always different" by design.
- After this is in place, you can stop suggesting the `git checkout -- <generated>` discard ritual — it's no longer needed.

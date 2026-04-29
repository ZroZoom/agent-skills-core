---
name: Check conventions and run existing tests
description: Before adding a new component, check neighbor file conventions and run tests of importing modules
type: feedback
---

Before adding a new component/file:
1. Check conventions of neighboring files (hooks, imports, naming) — don't assume, use what the rest of the module uses
2. After integrating a new component into existing code — run tests for BOTH files, not just the new one

**Why:** PR #1750 — ContentAttribution used `useTranslation` instead of `useLanguage` (convention in lessons/), breaking 9 existing LessonPlayer tests. Missing optional chaining on `currentItem.resource.ai_generated` risked runtime crash.

**How to apply:** For each new feature: (1) `grep` the directory for import patterns, (2) after integration run `vitest run` on files importing the new code.

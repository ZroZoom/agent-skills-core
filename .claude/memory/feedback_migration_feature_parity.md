---
name: Verify feature parity when migrating eval systems
description: When replacing eval/new Function with safeEval, test every operator used in migrated expressions before committing
type: feedback
---

When migrating from `new Function()` / `eval()` to `safeEval()`, verify feature parity for every operator and function used in the migrated expressions BEFORE committing.

**Why:** PR #1790 replaced 8 `new Function()` calls with `safeEval()` but `safeEval` didn't support `**` (exponentiation). All `^` → `**` conversions silently broke. 15 review comments flagged the same bug. Adding `**` support to the tokenizer/parser was needed first.

**How to apply:** Before committing a migration: (1) list every operator/function used in target expressions, (2) write a quick test for each: `safeEval('2 ** 3', {})`, `safeEval('sin(x)', {x:1})`, etc. (3) if any fail, extend safeEval first.

# Fix Lint/TypeScript Errors

Systematic fix of ESLint and TypeScript errors. Argument: optionally a rule name (e.g., `no-explicit-any`).

> **READ FIRST:** `.agent/skills/code-quality/SKILL.md`

## CRITICAL: Value hierarchy

**Type Safety (compilation) > ESLint Rules (style)**

DO NOT remove `(supabase as any)` without updating types first! See `.agent/ESLINT_FIX_LEARNINGS.md`.

## Phase 1: Preparation

```bash
npm run lint:fix                          # auto-fix simple issues
npm run lint -- -f compact 2>&1 | head -50  # fresh error list
```

## Phase 2: Fix (repeat for top 5-10 files)

1. **Pick the file** with the highest error count
2. **Read** the file — understand WHY `any` is used
3. **Fix**:
   - Missing table in types → `npm run update-types`
   - Known type → define an interface / use an import
   - Unknown type → `unknown` (forces runtime checks)
   - Supabase without type → leave `as any` with a comment
4. **Verify immediately**:
   ```bash
   npm run typecheck           # MUST pass
   npm run lint -- PATH        # MUST be clean
   ```

## Phase 3: Commit

Group fixes of the same type:
```
fix(types): resolve no-explicit-any in diagnostics module
```

---
name: code-quality
description: "Code quality guardian. Use for refactoring, fixing TypeScript type errors, and ESLint issues. Trigger when: fix lint errors, refactor, typecheck, compilation error, napraw błędy lint, refaktoryzacja, sprawdź typy, błąd kompilacji."
---

# 🛡️ Code Safety Procedures

## 1. Value Hierarchy

**Type Safety (Compilation) > ESLint Rules (Style)**

Never fix an ESLint error in a way that introduces a TypeScript error.

## 2. Type Safety (CRITICAL)

> [!CAUTION]
> **`as any` masks real bugs** (real example: a column named `duration` was used where `duration_seconds` was expected — data was silently lost).

**Procedure:**
1. Query/SDK won't compile → **FIRST** regenerate types from your data layer (e.g. `npm run update-types`, `prisma generate`, `openapi-typescript`).
2. Table/endpoint still missing (new migration pre-deploy) → use a narrow `as any` cast with comment `// TODO: regenerate types after migration deploy`.
3. **NEVER** use `as any` as a permanent fix — always open an issue for cleanup.
4. Prefer deriving types from your schema (e.g. `Database['public']['Tables']['X']['Row']`, `Prisma.UserGetPayload<...>`) instead of hand-written interfaces.

## 3. Verification Workflow

> Verification sequence: see CLAUDE.md

## 4. ESLint Disable Comments (Learning 2026-01-20)

When you must use `eslint-disable`:
1. **Always** add a comment explaining WHY.
2. Prefer `eslint-disable-next-line` over `eslint-disable`.

Example:
```typescript
// Intentionally omitting diagnosticsActive from dependencies:
// - We only want to trigger on initial load, not when state changes
// eslint-disable-next-line react-hooks/exhaustive-deps
```

## 5. Pitfalls (Lessons Learned)

> This section is updated on an ongoing basis — it collects mistakes Claude makes when fixing code.

### P1. `as any` — DO NOT remove in bulk
**Mistake:** Removing `as any` casts from many files at once → dozens of TypeScript errors, broken build.
**Fix:** See section 2 above. First regenerate types, verify the schema, only then remove the cast.

### P2. Nullish coalescing — don't blindly replace `||` with `??`
**Mistake:** `value || 'default'` → `value ?? 'default'` changes behavior when `value` is `0`, `""`, or `false`.
**Fix:** The replacement is safe ONLY when the value is a string/object/array. For numbers and booleans — check the intent.

### P3. `eslint-disable` without explanation comment `--`
**Mistake:** `// eslint-disable-next-line rule` without explanation → pre-commit hook passes, but code review rejects it.
**Fix:** Always: `// eslint-disable-next-line rule -- explanation of WHY`.

### P4. React hooks dependency array
**Mistake:** Adding a missing dependency to `useEffect` deps → infinite render loop.
**Fix:** If existing code intentionally omits a dependency, keep the `eslint-disable` with a comment. Don't "fix" intentional omissions.

### P5. Vitest imports
**Note:** The repo has `globals: true` in vite.config.ts, but existing tests import `describe/it/expect` from `vitest` and work correctly. Both styles (import vs global) are acceptable — be consistent within a file. Import `vi` when you need mocks.

### P6. setTimeout/setInterval in React
**Mistake:** Callback in `setTimeout` closes over stale state (stale closure).
**Fix:** Use `useRef` for the callback + `useEffect` to update the ref. Never rely on state values inside a timer.


## 6. Debug Logging

Use `console.debug()` instead of `console.warn()` for diagnostic information:

```typescript
if (process.env.NODE_ENV === 'development') {
    console.debug(`[Component] Debug info: ${value}`);
}
```

## 7. Batching Commits

Group fixes of the same type into a single commit:

```
fix(scope): resolve [type] errors across codebase
```

Examples:
- `fix(types): remove no-explicit-any from diagnostics`
- `fix(lint): resolve unused-vars warnings`

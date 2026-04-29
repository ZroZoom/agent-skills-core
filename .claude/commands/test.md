# Test Application

Run the full test suite. Argument: optionally `unit`, `e2e`, `quality`, `build`, `all` (defaults to `all`).

## all (full suite)

```bash
npm run quality          # 1. Lint + Typecheck
npx vitest run           # 2. Unit tests (Vitest)
npx playwright test      # 3. E2E tests (Playwright)
npm run check-seo        # 4. SEO check
npm run build            # 5. Production build
```

## quality

```bash
npm run quality    # lint + typecheck
```

## unit

```bash
npx vitest run                        # all
npx vitest run path/to/test.ts        # single file
npx vitest run --grep "pattern"       # by name
```

## e2e

Make sure port 5173 is free.

```bash
npx playwright test                         # all
npx playwright test e2e/file.spec.ts        # single
npx playwright test --ui                    # interactive mode
```

## build

```bash
npm run build
```

---

**If all steps pass — the application is ready for release.**

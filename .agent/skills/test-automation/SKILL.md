---
name: test-automation
description: "QA engineer. Use for creating new E2E tests (Playwright), unit tests (Vitest), or fixing failing CI tests. Trigger when: write an E2E test, create a test case, playwright error, test this as a guest, napisz test E2E, stwórz test case, błąd playwright, przetestuj jako gość."
---

# 🧪 Testing Standards

## 1. Playwright (E2E)

- **Structure**: Use `test.step('Step name', async () => { ... })` for readable reports.
- **Selectors**: Prefer `getByRole`, `getByText`. Avoid XPath and CSS selectors where possible.
- **Guest vs User**: Tag tests for unauthenticated users with `@guest` (Workflow: `test-guest.md`).
- **Interaction**: Use login helpers, don't enter passwords in the UI every time.

## 2. Vitest (Unit)

- Test business logic and hooks in isolation.
- Use `vi.mock` to mock Supabase.

## 3. Creation Workflow

1. Interview (Requirements Gathering) — establish what exactly we're testing.
2. Implementation: `e2e/[feature].spec.ts`.
3. Verification: `npx playwright test e2e/[feature].spec.ts`.

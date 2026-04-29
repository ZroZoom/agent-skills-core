---
name: frontend-system
description: "UI/UX expert. Use for creating components, styling (Tailwind), accessibility, and translations (I18n). Trigger when: create a component, change appearance, add a chart, translate, stwórz komponent, zmień wygląd, dodaj wykres, przetłumacz."
---

# 🎨 Frontend & Design System

## 1. Internationalization (I18n)



> [!CAUTION]
> **ZERO HARDCODED STRINGS!**
> Every user-visible text must use the `useTranslation` hook / `t()` (or your project's i18n equivalent).

**Required languages:** define the project's locale list in your i18n config (e.g. `pl.json`, `en.json`, ...).

**Key structure:**
```json
{
  "component.action.state": "Text"
}
```

## 3. Styling

- **Framework**: Tailwind CSS
- **Animations**: Framer Motion (for UI interactions) or CSS Transitions
- **Responsiveness**: Mobile-first (`sm:`, `md:`, `lg:`)
- **Dark mode**: Supported via `dark:` classes

## 4. SEO

New public pages **MUST** include the `<SEO />` component:

```tsx
<SEO 
  title="Page title" 
  description="Description for search engines" 
/>
```

## 5. Accessibility (a11y)

- Use semantic HTML (`<nav>`, `<main>`, `<article>`)
- All interactive elements must have `aria-label` or visible text
- Colors: minimum 4.5:1 contrast ratio (WCAG AA)

## 6. Pitfalls (Lessons Learned)

### P1. Runtime fetch of static files
**Mistake:** Files fetched via `fetch()` at runtime (not imported) reside outside `public/` → they don't end up in `dist/`.
**Fix:** Runtime files MUST be in `public/`. Only `public/` is copied to the build output.

### P2. Config defensiveness
**Mistake:** Missing field in a JSON config (e.g., `xRange`) → `TypeError` crash in the renderer.
**Fix:** Always use optional chaining with defaults: `config?.xRange ?? [-5, 5]`.

### P3. useIsMobile — matchMedia vs resize
**Mistake:** `addEventListener('resize')` + `innerWidth` — less performant and off-by-one at the breakpoint.
**Fix:** `matchMedia('(max-width: ${breakpoint - 1}px)')` — performant, no overlap.

### P4. PWA cache — large chunks
**Mistake:** Default workbox `maximumFileSizeToCacheInBytes` limit (2MB) silently skips large chunks.
**Fix:** Increase the limit when the bundle grows. Without this, offline mode loses critical resources.

### P5. Ratings / nullable values: null vs 0
**Mistake:** Missing rating mapped as `?? 0` → renders 0 stars (grey), as if someone rated it 0.
**Fix:** Use `?? undefined` — triggers the "no rating" state (yellow default).

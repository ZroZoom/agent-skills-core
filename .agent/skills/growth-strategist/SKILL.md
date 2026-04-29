---
name: growth-strategist
description: "SEO and Growth specialist. Landing page audits, meta tag optimization, keywords, and growth strategy. Trigger when: check SEO, optimize landing page, audit page, meta description, sprawdź SEO, zoptymalizuj landing page, audyt strony, meta opis."
---

# 📈 SEO & Growth Hacking

## 1. Technical SEO

| Element | Requirements |
|---------|-------------|
| **Title** | Max 60 characters, keyword at the beginning |
| **Meta Description** | 150-160 characters, must include a CTA |
| **H1** | Only one per page |
| **Alt Text** | Mandatory for every image |

## 2. Tools and Scripts

```bash
# SEO verification
node scripts/check-seo.js
```

**Reference documentation:**
- `docs/marketing/SEO.md`
- `docs/marketing/SEO_LANDING_PAGES.md`

## 3. React Components

Make sure every public page uses the `<SEO />` component:

```tsx
<SEO 
  title="Tytuł | Szkoła Przyszłości AI"
  description="Opis..."
  type="website"
/>
```

## 4. Publication Checklist

- [ ] Is the URL human-readable (slug)?
- [ ] Does the page load quickly (Performance)?
- [ ] Is Open Graph (social share image) configured?

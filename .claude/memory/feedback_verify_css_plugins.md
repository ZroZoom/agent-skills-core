---
name: Verify CSS plugin before using animation classes
description: Check tailwind.config and package.json before using animation utility classes — uninstalled plugins fail silently
type: feedback
---
Before using CSS animation utility classes (`animate-in`, `fade-in`, `slide-in-from-*`), verify the plugin is installed in `package.json` and configured in `tailwind.config`.

**Why:** On PR #1892, `animate-in fade-in slide-in-from-top-1` classes were added without `tailwindcss-animate` being installed. No build error — classes are silently ignored. Gemini caught it in review.

**How to apply:** `grep tailwindcss-animate package.json` before using those classes. If not installed, use native Tailwind (`transition-all duration-200`) or Framer Motion.

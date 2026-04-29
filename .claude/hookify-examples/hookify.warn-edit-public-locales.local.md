---
name: warn-edit-public-locales
enabled: false
event: file
conditions:
  - field: file_path
    operator: regex_match
    pattern: public[/\\]locales[/\\].*\.json$
---

⚠️ **Editing a generated localization file**

> **Customize for your project.** This hook is disabled by default; enable it (`enabled: true`) and adjust the regex if your i18n pipeline emits generated JSON files into a tracked path.

The matched JSON files under `public/locales/` (or your equivalent) are **build artifacts**.

**Do not edit them directly — your changes will be overwritten on the next build.**

Edit the source files instead:
- `src/locales/{lang}/{namespace}.json` (or wherever your i18n source lives)
- Translations must exist in all configured languages.

Run your build / dev server to regenerate the public locales.

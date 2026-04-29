---
name: warn-checkout-new-branch
enabled: true
event: bash
pattern: git\s+(checkout|switch)\s+(-b|-B|-c|-C|--create|--force-create)\b
---

⚠️ **Tworzysz nową gałąź — zweryfikuj bazę**

Reguła z pamięci: `branch-base-verification` — zła baza kosztuje cały PR.

**Zanim utworzysz gałąź, potwierdź:**

```bash
git branch --show-current   # z czego odchodzę?
git status                   # czyste drzewo? niezacommitowane zmiany?
```

Nowa gałąź dziedziczy commity z aktualnej. Jeśli jesteś na feature branchu a chcesz odbić od `main`:

```bash
git checkout main && git pull
git checkout -b feature/<name>
```

Kontynuuj, jeśli baza się zgadza.

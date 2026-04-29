---
name: warn-git-commit-branch
enabled: true
event: bash
pattern: \bgit\s+commit(?:\s|$)(?![^\n]*\s--amend\b)
---

⚠️ **Zweryfikuj gałąź przed commitem**

Zasada CLAUDE.md: **nigdy nie commituj do `main`** — zawsze używaj feature brancha.

Zanim ten commit trafi do repo, potwierdź aktualną gałąź:

```bash
git branch --show-current
```

Powinna być `feature/*` albo `fix/*`. Jeśli pokazuje `main`:

```bash
git checkout -b feature/<short-name>   # przenieś WIP na feature brancha
```

I spróbuj commita ponownie.

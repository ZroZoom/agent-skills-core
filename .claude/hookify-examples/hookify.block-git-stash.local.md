---
name: block-git-stash
enabled: true
event: bash
pattern: git\s+([^\n]*\s)?stash\b(?!\s+(list|show))
action: block
---

🚫 **`git stash` zablokowany**

Zasada CLAUDE.md: **nigdy nie używaj `git stash`**.

Zmiany w stash-u znikają z working tree i łatwo je zgubić. Zamiast tego **zapytaj użytkownika**:

> "Masz niezacommitowane zmiany. Zachować jako WIP commit czy odrzucić?"

- Zachować → `git add -A && git commit -m "wip: ..."`
- Odrzucić → `git checkout -- <files>` (po potwierdzeniu)

Reguła łapie też wywołania po globalnych opcjach, np. `git -c color.ui=always stash`.

(Formy tylko-do-odczytu `git stash list` / `git stash show` są dozwolone.)

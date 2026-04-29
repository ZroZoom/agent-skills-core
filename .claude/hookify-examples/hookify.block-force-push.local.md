---
name: block-force-push
enabled: true
event: bash
pattern: git\s+([^\n]*\s)?push\b[^\n]*?(--force\b|--force-with-lease\b|--force-if-includes\b|\s-[a-zA-Z]*f[a-zA-Z]*\b|\s\+\S+)
action: block
---

🚫 **Zablokowano force push**

Reguła z pamięci `no-force-push-after-rebase`: w tym projekcie **nie używamy force push** — synchronizacja z `main` odbywa się przez `gh pr update-branch` tuż przed mergem, nie przez rebase+force.

**Co jest blokowane:**
- `git push --force` / `git push --force-with-lease` / `git push --force-if-includes`
- `git push -f` oraz kombinacje krótkich flag (`-fu`, `-uf` itp.)
- `git push origin +main` (prefiks `+` w refspecu wymusza push)
- Powyższe także po globalnych opcjach, np. `git -c color.ui=always push --force`

**Zamiast force push:**
- Synchronizacja feature branch z main: `gh pr update-branch <PR_NUMBER>` lub przycisk *Update branch* w UI GitHuba
- PR Merge Supervisor obsługuje to automatycznie przed mergem

Jeśli użytkownik jawnie autoryzował force push (np. naprawa zepsutej historii), poproś o potwierdzenie przed ponowną próbą.

---
name: block-no-verify
enabled: true
event: bash
pattern: git\s+([^\n]*\s)?(--no-verify\b|--no-gpg-sign\b)|git\s+-c\s+commit\.gpgsign=false\b|git\s+([^\n]*\s)?commit\b[^\n]*\s-[a-z]*n[a-z]*\b
action: block
---

🚫 **Próba ominięcia git hooków / podpisu**

Zasada projektu (CLAUDE.md): **nigdy nie omijaj hooków** bez wyraźnej zgody użytkownika.

**Co jest blokowane (zawężone do poleceń `git`):**
- `git ... --no-verify` / `--no-gpg-sign` (także po globalnych opcjach, np. `git -c color.ui=always commit --no-verify`)
- `git commit -n` oraz klastrowane krótkie flagi zawierające `n` (`-nm`, `-anm` itp.)
- `git -c commit.gpgsign=false ...`

**Jeśli hook pre-push nie przechodzi:**
- Zdiagnozuj przyczynę (zwykle: regenerowane pliki jak `public/locales/*.json`, `src/generated/*.json`)
- Dodaj zmiany do commitu zamiast je omijać
- Błędy lintera/typecheck napraw, nie pomijaj

**Jeśli użytkownik jawnie autoryzował pominięcie** w tej turze, poproś o potwierdzenie przed ponowną próbą.

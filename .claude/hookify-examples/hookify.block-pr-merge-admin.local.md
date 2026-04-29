---
name: block-pr-merge-admin
enabled: true
event: bash
pattern: gh\s+pr\s+merge\b[^\n]*--admin\b
action: block
---

🚫 **`gh pr merge --admin` zablokowany**

Zasada CLAUDE.md: **nigdy nie używaj `--admin`** — omija ochronę gałęzi oraz merge queue.

**Użyj PR Merge Supervisor:**
```bash
npx tsx tools/pr-merge-supervisor.ts <PR_NUMBER>
```

Albo ręcznie:
```bash
gh pr merge <PR> --squash --auto
```

`--auto` kolejkuje PR w merge queue; poczekaj na CI i kolejkę. Nigdy nie omijaj ochrony gałęzi.

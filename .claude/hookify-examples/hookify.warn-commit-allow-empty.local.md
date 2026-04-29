---
name: warn-commit-allow-empty
enabled: true
event: bash
pattern: git\s+commit(?:\s|$)[^\n]*--allow-empty\b
---

⚠️ **Pusty commit wykryty**

Jeśli próbujesz **ponownie odpalić CI** po transientnej awarii, lepiej:

```bash
gh run rerun <run-id> --failed
```

To ponowi tylko nieudane joby bez zaśmiecania historii pustymi commitami. Reguła z pamięci: `ci-rerun-not-empty-commit`.

**Sensowne powody dla `--allow-empty`:**
- CI faktycznie nie startuje po `gh pr close && gh pr reopen` (ostatnia deska ratunku wg CLAUDE.md)
- Oznaczenie punktu release'u

Jeśli żaden z powyższych — `gh run rerun <run-id> --failed` jest prawie zawsze właściwym wyborem.

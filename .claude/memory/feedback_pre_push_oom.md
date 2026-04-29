---
name: Pre-push hook OOM on Windows
description: Build in pre-push hook can fail with OOM at "computing gzip size" — fix with NODE_OPTIONS="--max-old-space-size=8192"
type: feedback
---

The pre-push hook (`.husky/pre-push`) runs a full production build. On Windows, it can fail at the "computing gzip size..." phase with `Build failed! Fix errors before pushing.` due to insufficient memory.

**Why:** Observed 2026-04-04 and 2026-04-06. The build's image optimization + zlib compression spikes memory. The husky hook may not inherit the `--max-old-space-size=8192` from package.json's cross-env wrapper.

**How to apply:**
- If `git push` fails with OOM, use: `NODE_OPTIONS="--max-old-space-size=8192" git push` — this passes the memory limit to all child processes including the pre-push hook build
- Simple retry sometimes works but is unreliable; explicitly setting 8192 is the reliable fix
- Build artifacts (`public/locales/`, `src/generated/`, `src/config/prerender-routes.json`) may be left dirty after failed hook — run `git checkout --` on them before `git pull --rebase`
- Do NOT use `--no-verify` without user's explicit permission (CLAUDE.md rule)

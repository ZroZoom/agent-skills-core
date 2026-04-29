---
name: Run self-analysis at end of session
description: Run /self-analysis before ending every session with PR review — feedback_*.md matters more than SESSION_LEARNINGS
type: feedback
---

Run `/self-analysis` at the end of every session that included a PR review loop.

**Why:** Almost every PR gets 10-30+ review comments (Copilot, Gemini, Codex) — friction is the norm, not the exception. Context is ephemeral — after `/clear` or a new session, the full picture is gone. This is the only moment to extract learnings.

**How to apply:** Before ending a session (before `/clear`), run `/self-analysis`. Prioritize saving to `memory/feedback_*.md` (auto-loaded every session) over `SESSION_LEARNINGS.md` (requires manual reading). Don't wait until end of day — each session has its own context.

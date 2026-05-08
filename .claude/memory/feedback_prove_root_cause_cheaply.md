---
name: Prove root cause with the cheapest probe first
description: Before validating a fix through slow CI or E2E, verify the root-cause hypothesis with a fast direct probe
type: feedback
---

When a bug's full validation path is slow, do not iterate blindly through CI. Reproduce and confirm the suspected root cause with the fastest probe that isolates the failing layer: a curl request, unit test, shell one-liner, small script, or direct function call.

**Why:** Slow E2E/CI loops are useful confirmation, but they are expensive as discovery tools. A two-second probe can tell you whether the problem is an HTTP response, parser output, generated file, environment variable, or function return before you push.

**How to apply:**
- Convert the hypothesis into one observable: response header/body, function output, file content, SQL result, or process exit code.
- Run the probe before committing and after the fix.
- Pair the probe with the failing CI log so "what CI sees" and "what my probe sees" match.
- If the probe passes but E2E fails, your hypothesis may be incomplete. Go back to evidence gathering.

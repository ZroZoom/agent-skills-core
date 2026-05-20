---
name: session-self-analysis
description: "Agent session self-analysis workflow. Use at the end of a session or after user feedback to identify process failures, perform 5 Whys, and record durable learnings without duplicates. Trigger when: /self-analysis, self analysis, session retrospective, session learnings."
---

# Session Self-Analysis Skill

Analyze the current agent session and record durable lessons when needed.

## Contract

- Input: current session context and optional user feedback.
- Output: concise self-analysis and any memory/skill updates.
- Side effects: may edit `.claude/memory/`, a project session-learnings
  file (if one exists), or a relevant `.agent/skills/*/SKILL.md` after
  deduplication.

## Workflow

### 1. Review Signals

Look for:

- user had to clarify the request
- user asked for format/style changes
- factual correction was needed
- repeated instructions were missed
- CI/review bots caught issues from this session
- repo rules were missed or applied late

If no friction occurred, say so briefly and stop.

### 2. Categorize

Use:

- Format: structure, length, style
- Substance: factual error or missed repo pattern
- Tone: too formal/casual or wrong language
- Logic: flawed reasoning or missed instruction
- Process: wrong tool order, missing pre-flight, bad Git/PR flow

### 3. 5 Whys

For the most important issue, ask why until the root cause is specific and
actionable. Three to five steps are enough.

### 4. Formulate Rule

Good rule format:

```text
[Trigger/context] -> [Expected behavior]
```

Rules must be concrete and testable. Avoid vague rules like "be more
careful".

### 5. Deduplicate Before Writing

Search:

```bash
ls .claude/memory
rg -n "keyword|concept" .claude/memory .agent/skills
```

Destination:

| Type | Destination |
|---|---|
| process/workflow feedback | `.claude/memory/feedback_*.md` |
| code-level gotcha | project session-learnings file (if maintained) |
| domain-specific rule | relevant `.agent/skills/*/SKILL.md` |

If an existing file covers the concept, update it rather than creating a
duplicate.

### 6. Memory File Format

```markdown
---
name: short-rule-name
description: One-line description
type: feedback
---

Rule statement.

**Why:** Incident that caused this rule.

**How to apply:** Trigger and concrete behavior.
```

After creating a memory file, add a one-line pointer to
`.claude/memory/MEMORY.md` (or the equivalent index in your project).

## Rules

- Use bullet points, not numbered lists, inside memory files.
- Do not create root-level docs.
- Do not record generic preferences that are already covered by the repo's
  `AGENTS.md` / `CLAUDE.md`.
- Memory recorded in `.claude/memory/` is the **repo SSOT** shared across
  Claude / Codex / Copilot sessions. Per-machine user memory
  (`~/.claude/projects/.../memory/` for Claude Code) is invisible to other
  agents — only sync rules worth sharing.

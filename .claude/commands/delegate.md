# Delegate Issue To Agent

Generate a complete Claude/Codex prompt from a GitHub issue and move the issue to `In progress`.

Load `.agent/skills/delegate/SKILL.md` and follow it exactly.

## Arguments

- Required: issue number or URL.
- Optional: target agent (`claude`, `codex`, `copilot`) and extra focus notes.

## Required flow

1. Resolve the issue with `gh issue view`.
2. Read `AGENTS.md`, `.agent/context/project-ids.md`, and all relevant skill files.
3. Move the issue's Project item to `In progress`.
4. Search likely files with `rg`; include only useful context.
5. Output one ready-to-paste prompt in a fenced `markdown` block.

## Output

````markdown
Status moved to In progress: yes/no

```markdown
# Task
...
```

Missing context / risks:
- ...
````

Do not edit code from this command. Its job is delegation context only.

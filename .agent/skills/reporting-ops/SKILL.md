---
name: reporting-ops
description: "Use when generating operational reports, release notes, demo readiness checks, stakeholder updates, infrastructure cost/expiry checks, or bilingual changelogs. Triggers: /release-notes, /investor-report, /demo-check, /cost-check, changelog, release notes, stakeholder report, monthly metrics, demo readiness, before demo, infrastructure costs, cost monitoring, certificate expiry."
---

# Reporting Ops

Use this for evidence-backed reporting workflows that summarize project
state, releases, demo readiness, stakeholder metrics, or infrastructure
cost and expiry risk. These workflows are read-only unless the user
explicitly asks to publish, create issues, or change services.

## Mode Router

| Request | Mode | Detail file |
|---|---|---|
| `/release-notes`, changelog, release summary | Release notes | `.agent/skills/release-notes/SKILL.md` |
| `/investor-report`, stakeholder report, monthly metrics | Stakeholder report | `.agent/skills/investor-report/SKILL.md` |
| `/demo-check`, demo readiness, presenter script | Demo readiness | `.agent/skills/demo-check/SKILL.md` |
| `/cost-check`, infrastructure costs, domain/SSL/API risk | Cost and expiry | `.agent/skills/cost-check/SKILL.md` |

Each detail file owns its workflow steps, inputs, outputs, and report
template. Load the relevant detail file when the request matches its mode.

## Shared Rules (apply to every mode)

- Separate measured facts from interpretation.
- Do not fabricate user metrics, impact numbers, dates, or deploy status.
- Prefer exact dates over relative phrases like "today".
- Never print secrets, tokens, billing card details, or service-role keys.
- Do not change paid plans, renew domains, publish releases, email reports,
  or create/close issues unless explicitly asked.
- Polish-first reports are the project default unless `--target investors`
  or `--lang en` is specified; translate to English on request.
- For EdTech projects, keep AI Act language conservative: do not present
  AI grading, profiling, adaptive learning, or behavioral monitoring as
  product capabilities unless they are actually implemented and compliant.

## Why a single router

Before consolidation, four separate skills (`release-notes`, `demo-check`,
`investor-report`, `cost-check`) each registered their own triggers. This
made it harder for a model to pick the right one for fuzzy requests like
"podsumuj wydanie" or "ile wydaliśmy na infra w tym miesiącu". The router
catches the fuzzy form and dispatches to the right detail file. The detail
files keep the full workflow so they remain useful as standalone
references.

## Placeholders

The detail files reference these placeholders (defined in
`.agent/context/project-ids.md`):

- `<OWNER>/<REPO>` — GitHub repository
- `<DOMAIN_PRIMARY>` / `<DOMAIN_SECONDARY>` — production domains
- `<SITE_NAME_PRIMARY>` / `<SITE_ID_PRIMARY>` — hosting site identifiers
- `<PRODUCT_STATS_FILE>` — generated stats file used by stakeholder report
- `<DEMO_MILESTONE>` — default milestone used by demo-check

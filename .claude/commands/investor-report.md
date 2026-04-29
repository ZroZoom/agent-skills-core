# Investor Report

Generate a PDF-ready stakeholder report from platform metrics, milestones, and delivery highlights.

Load `.agent/skills/investor-report/SKILL.md` and follow it.

## Arguments

- Optional reporting period, for example `--since 2026-04-01 --until 2026-04-28`.
- Optional `--en` for an English executive version.
- Optional `--with-db` to attempt user/usage metrics from your data layer.

## Required flow

1. Read your project's product stats file (configure in `.agent/skills/investor-report/SKILL.md`).
2. Fetch GitHub milestone progress.
3. Fetch merged PR highlights for the period.
4. Query the DB / analytics only when credentials/tools are available and safe.
5. Produce PDF-ready markdown with sources for every metric.

Separate measured facts from interpretation. If a metric is unavailable, say so.

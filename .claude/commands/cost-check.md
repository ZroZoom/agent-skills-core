# Cost Check

Check infrastructure costs, plan/quota signals, domains, SSL expiry, and AI/API cost risk.

Load `.agent/skills/cost-check/SKILL.md` and follow it.

## Arguments

- Optional service filter: `netlify`, `supabase`, `domains`, `api`.
- Optional domain list.

## Required flow

1. Check Netlify site/deploy/domain status when MCP or CLI access is available.
2. Check Supabase project/plan/quota status when CLI access is available.
3. Check SSL dates and WHOIS/registrar expiry where possible.
4. Search AI/API call sites and rate-limit protections.
5. Produce an alerts-first Polish report.

Never print secrets, billing details, API keys, or auth tokens. Never change paid plans automatically.

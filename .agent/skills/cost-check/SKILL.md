---
name: cost-check
description: "Infrastructure cost and expiry monitor. Checks Netlify, Supabase, domains, SSL, and API-cost risk signals. Trigger when: /cost-check, cost monitoring, infrastructure costs, domeny, wygasanie, koszty."
---

# Cost Check Skill

Report infrastructure cost, plan, quota, and expiry risks.

## Contract

- Inputs: optional domain list or service filter.
- Output: a Polish cost and expiry report with alerts.
- Side effects: none. Do not change billing plans, renew domains, rotate secrets, or cancel services.

## Known Services

> **Configure for your project.** Maintain the list of services below in `.claude/memory/reference_<provider>.md` (or equivalent) and reference it from here.

| Service | Identifier |
|---|---|
| Hosting (e.g. Netlify/Vercel) primary | `<SITE_NAME>`, site ID `<SITE_ID>` |
| Hosting secondary (if any) | `<SITE_NAME>`, site ID `<SITE_ID>` |
| Database (e.g. Supabase/Postgres) | project ref / connection string |
| Domains | `<DOMAIN_PRIMARY>`, `<DOMAIN_SECONDARY>`, plus any domains in hosting |

## Workflow

### 1. Check Netlify

Use Netlify MCP when available:

- project/service lookup for both known sites
- latest deploy status
- plan/team information if exposed
- domain list and SSL status

If MCP is unavailable, use Netlify CLI/API only if already authenticated. Do not request or print tokens.

### 2. Check Supabase

```bash
test -f supabase/.temp/project-ref && cat supabase/.temp/project-ref
if command -v supabase >/dev/null 2>&1; then
  supabase projects list
else
  npx supabase projects list
fi
```

If Supabase CLI is not authenticated, report that billing/quota status was not checked.

### 3. Check domains and SSL

Use the safest available command:

```bash
openssl s_client -servername <DOMAIN_PRIMARY> -connect <DOMAIN_PRIMARY>:443 </dev/null 2>/dev/null | openssl x509 -noout -dates
openssl s_client -servername <DOMAIN_SECONDARY> -connect <DOMAIN_SECONDARY>:443 </dev/null 2>/dev/null | openssl x509 -noout -dates
```

For registrar expiry, use `whois` if available:

```bash
whois <DOMAIN_PRIMARY>
whois <DOMAIN_SECONDARY>
```

If WHOIS is unavailable or redacted, say so and rely on Netlify/registrar data supplied by the user.

### 4. Check API cost risks

Look for AI/API usage points:

```bash
rg -n "OPENAI|ANTHROPIC|GEMINI|GOOGLE|AI_GATEWAY|generate-quiz|chat-with-ai|rate-limit" supabase src netlify .env.example
```

Report whether rate limiting exists before expensive calls. Look for guards such as `rate-limit`, `throttle`, `quota`, or `model-strategy` in your backend / serverless functions / API routes.

### 5. Output

```markdown
## Cost check

**Checked at:** YYYY-MM-DD HH:mm Europe/Warsaw
**Verdict:** ok / watch / action needed

### Alerts
| Severity | Service | Finding | Action |
|---|---|---|---|

### Netlify
- Primary: ...
- Secondary: ...

### Supabase
- Project: ...
- Plan/quota: checked / unavailable

### Domains and SSL
| Domain | DNS/SSL | Registrar expiry | Notes |
|---|---|---|---|

### API cost risk
- ...
```

## Rules

- Never paste secrets, auth tokens, API keys, or billing card details.
- Never change paid plans automatically.
- Treat expiry within 30 days as `action needed`; within 60 days as `watch`.
- If a source cannot be checked, report it as unknown rather than guessing.

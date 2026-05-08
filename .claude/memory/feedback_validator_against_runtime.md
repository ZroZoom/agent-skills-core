---
name: Validator rules must match runtime behavior
description: When building a checker for app content or data, read the runtime code paths it claims to validate against
type: feedback
---

When building a validator or checker for application content, read the runtime code paths that consume the same fields before shipping the rule. Specs and audits often miss UI special-cases, parser fallbacks, or answer-checking behavior.

**Why:** A validator implemented from an abstract rule can become over-aggressive or under-aggressive. Runtime code may exempt yes/no choices, support extra field shapes, treat units specially, or parse templates differently than the written spec implies.

**How to apply:**
- Before writing a detection rule, grep runtime consumers: `rg "<field>|<type>" src components lib`.
- Match regexes and predicates to runtime behavior, including case-sensitivity and special literals.
- Document the runtime file reference in the rule docs or fix hint.
- Run the validator on real data before opening a PR and sample several violations across categories.
- Treat an audit count as a sample, not the universe.

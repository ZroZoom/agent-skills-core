---
name: For testing flow in Kanban and Jira
description: After merge, move issues to "For testing" (not "Done") and create QA tickets in Jira
type: feedback
---

After merging a PR, don't leave issues in "Done" — move them to "For testing" on GitHub Kanban and create QA tickets in Jira (project <JIRA_PROJECT_KEY>) with test plans.

**Why:** The workflow requires a testing phase before closure. GitHub auto-sets "Done" on close, but the tester needs "For testing" + a Jira ticket with a checklist.

**How to apply:** After merge: (1) move issues to "For testing" on Kanban, (2) create QA tickets in Jira with change description, PR link, and test plan. Do this proactively.

# Contributing

This repo accepts outside teardown submissions and single-finding additions to existing pattern files. Submissions are reviewed by the maintainer and merged after a check against the methodology and the anonymization rules.

---

## What's in scope

- **Full teardown.** A complete audit of one app shipped from one named stack (Lovable, v0, Bolt.new, Cursor, Replit Agent). Use [`teardowns/_TEMPLATE.md`](teardowns/_TEMPLATE.md) as the canonical format.
- **Pattern-file addition.** A new pattern observation backed by your teardown plus at least one existing teardown in the repo. Pattern claims get promoted from "observation" to "pattern" once three teardowns show the same failure.
- **Correction or retraction** of an existing finding. False-positive corrections are welcomed and documented in-place.

## What's not in scope

- Theoretical advisories without a real audit behind them.
- Generic AI-code checklist items. Those live in [`patterns/cross-stack-failures.md`](patterns/cross-stack-failures.md) and that file is intentionally slim.
- Audits of apps the owner did not consent to publishing.
- Audits that name a real app or operator.
- Sponsored content, vendor pitches, paid submissions.

---

## Consent — non-negotiable

Every audited app falls into one of two categories. State which one in your PR.

**Category A — owner-authorized.** The app's owner has agreed in writing (email is fine) to a published audit. The PR includes a short note confirming consent. The app name stays redacted unless the owner explicitly waives that.

**Category B — public-demo audit.** The audit targets a tool's published demo, a marketing example, or a clone you built yourself using the tool's default flow. No owner consent needed — but the audit is of *the tool's output pattern*, not a specific operator's app.

PRs without one of these designations are closed without review.

---

## Anonymization

Before submission, redact:

- App name, brand, and any marketing-side identifiers
- Operator name and any handles
- Domain names and URLs
- Database / table / API names that contain identifiable strings
- Any data values from the production database (use `[REDACTED]` or invented placeholder data)
- Stripe and payment-processor account identifiers
- API key values (the *finding* — that a service-role key was exposed — stands; the actual key string is redacted)

Code excerpts: keep enough to make the finding clear. Drop identifying variable names, comments, and branding.

---

## Severity rubric

Full version at [`methodology/severity-rubric.md`](methodology/severity-rubric.md). Quick reference:

- **CRITICAL** — exploitable in production with a publicly-known technique. Examples: service-role key in client bundle, RLS disabled on a user-data table, SQL injection in an open endpoint.
- **HIGH** — exploitable with effort, or guaranteed exploitable once an attacker knows the surface. Examples: env vars in client bundle, no rate limiting on auth, auth tokens in localStorage.
- **MED** — production-quality miss. The app works; an operator with operational maturity wouldn't ship it this way. Examples: no max_tokens cap on LLM calls, no observability, no error tracking.
- **LOW** — code smell. Doesn't directly break anything. Examples: outdated SDK pattern, unused dependency, naming drift.

If a finding sits between CRITICAL and HIGH, file HIGH and let the maintainer escalate if warranted. Severity inflation is the failure mode that kills repo credibility fastest.

---

## PR template

Open the PR with this body:

```
**Submission type:** Full teardown / Pattern-file addition / Correction

**Stack:** Lovable / v0 / Bolt.new / Cursor / Replit Agent

**Consent category:** A (owner-authorized) / B (public-demo)

**Anonymization checklist:**
- [ ] App name and brand redacted
- [ ] Operator name and handles redacted
- [ ] Domain and URLs redacted
- [ ] Database/table/API names checked
- [ ] No real data values from production
- [ ] Payment processor identifiers redacted
- [ ] API key values redacted (findings retained)

**Findings count and severity distribution:** N CRITICAL / N HIGH / N MED / N LOW

**Net verdict:** SHIPPABLE-AS-IS / SHIPPABLE-AFTER-FIXES / SCRAP-AND-RESTART

**Pattern observation (optional):** One or two sentences naming a stack-default failure the audit surfaces.
```

---

## Review timeline

PRs are reviewed within seven days. The maintainer checks for consent designation, anonymization completeness, severity scoring against the rubric, and whether the audit cites enough surface to back its verdict. PRs that pass merge; PRs that need work get a single round of comments.

## After merge

Your name or handle goes on the audit and on the contributors list. If your audit crosses the three-teardown threshold for a pattern claim and a pattern file gets promoted from "observation" to "pattern," your audit is cited there too.

## Questions

Open a GitHub issue with the `question` label, or post in the repo's Discussions tab. Response within seven days.

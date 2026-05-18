# Severity rubric — CRITICAL / HIGH / MED / LOW

How findings get graded in this library. Same rubric applied to every finding in every teardown.

The rubric is **five questions**. The answers determine the grade. The rubric is intentionally simple — complex rubrics generate edge-case arguments instead of grades.

---

## 30-second summary

Quick reference for graders and PR reviewers. The full rubric below this section is the rigorous application of the same four tiers.

- **CRITICAL** — exploitable in production with a publicly-known technique. Examples: service-role key in client bundle, RLS disabled on a user-data table, SQL injection in an open endpoint.
- **HIGH** — exploitable with effort, or guaranteed exploitable once an attacker knows the surface. Examples: env vars in client bundle, no rate limiting on auth, auth tokens in localStorage paired with any XSS vector.
- **MED** — production-quality miss. The app works; an operator with operational maturity wouldn't ship it this way. Examples: no max_tokens cap on LLM calls, no observability, no error tracking, missing webhook idempotency.
- **LOW** — code smell. Doesn't directly break anything. Examples: outdated SDK pattern, unused dependency, naming drift, verbose error messages without paired exploitability.

If a finding sits between CRITICAL and HIGH, file HIGH and let the maintainer escalate if warranted. **Severity inflation is the failure mode that kills repo credibility fastest.**

The 5-question rubric below converts each finding into one of these four grades reproducibly.

---

## The five rubric questions

For each finding, answer five questions. Each is binary (or a small enum). The answer-pattern determines the severity.

### Q1 — Is the data class involved regulated, personal, or business-sensitive?

| Answer | Description |
| - | --- |
| **Regulated** | Falls under GDPR, HIPAA, PCI-DSS, SOC2 scope, or sector-specific regulation. Examples: health data, payment-card data, EU-resident PII, child data. |
| **Personal** | Identifies or could identify a natural person. Examples: email + name, contact info, account history, user-generated content tied to identity. |
| **Business-sensitive** | Not personal but valuable to the business or competitors. Examples: pricing models, customer lists (as B2B), internal metrics. |
| **Public** | No confidentiality expectation. Examples: published marketing content, public blog posts. |

### Q2 — What is the access scope an exploit grants?

| Answer | Description |
| - | --- |
| **Full admin** | Read + write + delete + privilege escalation. Includes service-role credentials, root-on-server, full-database write. |
| **Full read** | Read of all relevant data without authorization. E.g., RLS-disabled table reads. |
| **Targeted read or write** | Reaches specific data the attacker chooses but not arbitrary data. E.g., IDOR on a specific resource. |
| **Bounded effect** | Specific narrow capability without broader spread. E.g., file upload abuse limited to attacker's own storage quota. |

### Q3 — From what session state is the finding exploitable?

| Answer | Description |
| - | --- |
| **Unauthenticated** | Anyone with the URL can exploit. No login required. |
| **Authenticated, any role** | Any logged-in user can exploit. Includes free-tier users, demo accounts. |
| **Authenticated, specific role** | Requires a particular role the attacker would need to first obtain. |
| **Privileged insider only** | Requires existing privileged access (admin, internal staff). |

### Q4 — Exploitation complexity?

| Answer | Description |
| - | --- |
| **Single step** | One request, one paste of a URL, one DevTools action. Trivially scriptable. |
| **Multi-step, no special tools** | Chain of 2–5 actions using only browser + standard knowledge. |
| **Multi-step, specialized tooling** | Requires non-trivial tooling (Burp, custom scripts, etc.) or specialized knowledge. |
| **Novel research required** | Requires discovery of new technique; not currently exploitable by following a recipe. |

### Q5 — Mitigations in place?

| Answer | Description |
| - | --- |
| **None** | No detection, no rate limiting, no monitoring, no rollback path. |
| **Defense-in-depth fails but boundary holds** | One layer compromised but another intact (e.g., backend authorization bypassed but data is also encrypted client-side). |
| **Active mitigation reduces blast radius** | E.g., rate-limited so exploitation is slow; alerting fires on patterns; rollback is fast. |
| **Robust mitigation** | Multiple effective controls; finding is meaningful but not currently exploitable to its full theoretical extent. |

---

## Severity grade derivation

The grade follows from the answer pattern. There's no algorithm; there's a decision table.

### CRITICAL

**Issue ANY of these:**

- Q1 = Regulated OR Personal **AND** Q2 = Full admin OR Full read **AND** Q3 = Unauthenticated OR Authenticated-any-role **AND** Q5 = None
- Q2 = Full admin **AND** Q3 = Unauthenticated (regardless of Q1)
- Q4 = Single step **AND** Q2 = Full read of regulated-or-personal data **AND** Q5 = None

**Canonical example:** Supabase `service_role` JWT in client bundle.
- Q1: depends on data, but in any app with users → at least Personal
- Q2: Full admin (service_role bypasses RLS)
- Q3: Unauthenticated (key extractable by anyone who loads the page)
- Q4: Single step (copy key, use anywhere)
- Q5: None (no rotation, no IP allowlist, no monitoring on a typical vibe-coded app)
- **Grade: CRITICAL.**

### HIGH

**Issue ANY of these:**

- Q1 = Regulated OR Personal **AND** Q2 = Full read OR Targeted read/write **AND** Q3 = Authenticated-any-role **AND** Q5 = None OR Defense-in-depth-fails
- Q1 = Business-sensitive **AND** Q2 = Full admin OR Full read **AND** Q3 = Unauthenticated OR Authenticated-any-role
- Authentication / authorization bypass that doesn't reach full admin but reaches significant data
- Webhook signature missing on payment-grant endpoint (forged events grant paid access)
- Q4 = Single step OR Multi-step-no-special-tools **AND** Q2 = Targeted write to other-user data

**Canonical example:** Authorization-checked-at-UI-only — admin-only mutation accessible to any authenticated user via direct API call.
- Q1: depends on what mutation does; assume Personal
- Q2: Targeted write (to admin-protected resource)
- Q3: Authenticated-any-role
- Q4: Single step (curl with auth header)
- Q5: None
- **Grade: HIGH.** (Could escalate to CRITICAL if the mutation is full-admin scope.)

### MED

**Issue ANY of these:**

- Q1 = Personal OR Business-sensitive **AND** Q2 = Bounded effect **AND** Q3 = Authenticated-any-role
- Q1 = Regulated OR Personal **AND** Q2 = Targeted read/write **AND** Q4 = Multi-step-with-specialized-tooling **AND** Q5 = Active-mitigation-reduces-blast-radius
- Missing rate limiting on non-critical endpoints
- CORS wide open without paired cookie-based auth
- Webhook idempotency missing (replay-amplification risk, but signature verification holds)

**Canonical example:** No rate limiting on password-reset endpoint of a free-tier signup app.
- Q1: Personal (email enumeration via password-reset response timing)
- Q2: Bounded effect (enumerates which emails exist; does not access account data)
- Q3: Unauthenticated
- Q4: Multi-step (scripted but trivial)
- Q5: None
- **Grade: MED.** (Note: Q3 = Unauthenticated would push toward HIGH if Q2 were broader; the bounded effect anchors it at MED.)

### LOW

**Issue ANY of these:**

- Defensible default that should be tightened but isn't actively exploitable today
- Verbose error messages leaking minor details (stack traces, library versions) without paired exploitability
- Session tokens in localStorage in absence of XSS
- Q5 = Robust mitigation reduces an otherwise-MED finding to LOW

**Canonical example:** Session tokens in localStorage on an app with no XSS surface confirmed in the audit.
- Q1: Personal (the tokens themselves)
- Q2: Bounded effect (only exploitable via paired XSS — currently absent)
- Q3: Requires paired XSS
- Q4: Multi-step requiring novel chain
- Q5: Defense-in-depth-fails-but-boundary-holds
- **Grade: LOW.** (Recommendation: still fix, because absent XSS today doesn't mean absent XSS tomorrow.)

---

## Edge cases

### "It's CRITICAL theoretically but the app has 12 users"

The rubric does not weight by user count. A finding is graded by the failure shape, not by current blast radius. An app with 12 users today may have 12,000 tomorrow; the CRITICAL stays CRITICAL.

### "It's MED on this app but HIGH on a similar app I audited last month"

The rubric applies per-app. If the same finding grades differently on different apps, it's because the answer to one of Q1–Q5 differs (typically Q1 — different data class).

### "The owner says the data is public"

The owner's claim about data class is one input; verify. If the owner says "all the data on this table is public" but the table includes email addresses → email is Personal regardless of the owner's framing. Grade by what the data actually is.

### "Two findings are related — do I grade them together?"

No. Grade each separately. The teardown's overall severity is "at least the highest individual finding," but each finding gets its own row in the rubric.

---

## The rubric in the specialist's hands

The specialist (per `rules.md` Job 3 — Severity Q&A) walks users through the rubric question-by-question when they have a specific finding to grade. The specialist does NOT certify ("this is CRITICAL"); the specialist applies the rubric and surfaces the grade the rubric produces, citing this document.

Users who want the rubric verdict on findings in their own code apply it themselves, hire someone to apply it, or use Job 4 (pre-flight checklist) — which surfaces patterns + typical severity grades for their stack but does not look at their code.

---

## Cross-references

- The 6-step audit methodology: [`how-we-audit.md`](how-we-audit.md)
- Anonymization + consent: [`how-we-anonymize.md`](how-we-anonymize.md)
- Cross-stack patterns (with typical severity grades): [`../patterns/cross-stack-failures.md`](../patterns/cross-stack-failures.md)

---

_Last updated: 2026-05-18 (initial scaffold; 5-question rubric; decision-table-based, not algorithmic)._

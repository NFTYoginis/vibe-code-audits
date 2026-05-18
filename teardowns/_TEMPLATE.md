# TD-<STACK>-<NNN> — <one-line generalized app descriptor>

> **This is the canonical teardown template.** Copy this file to `teardowns/TD-<STACK>-<placeholder>.md` and fill it in. Maintainer assigns the final ID number at merge time.
>
> Every section below is required unless explicitly marked optional. If a section doesn't apply, write "Not applicable" with one line explaining why — don't delete the section.
>
> Anonymization gate: before submitting, re-read the filled template as a stranger who knows the live app personally. Could they recognize it? If yes, re-anonymize per [`../methodology/how-we-anonymize.md`](../methodology/how-we-anonymize.md). The gate is refusal-grade.

---

## Header

| Field | Value |
| - | --- |
| Teardown ID | `TD-<STACK>-<NNN>` (assigned at merge) |
| Stack | One of: Lovable / v0 / Bolt.new / Cursor / Replit Agent |
| Audit date | `YYYY-MM-DD` |
| Auditor | Your name, handle, or "Anonymous Contributor" |
| App type | Generalized descriptor — e.g., "B2B directory site," "subscription content gating product," "small SaaS dashboard with auth + payments" |
| Audit duration | Total clock-time in hours |

---

## Severity summary

| Severity | Count |
| - | --- |
| CRITICAL | _N_ |
| HIGH | _N_ |
| MED | _N_ |
| LOW | _N_ |

**Overall teardown severity:** _(at least the highest individual finding; if any CRITICAL exists, overall = CRITICAL)._

---

## Findings

Each finding follows the structure below. Order findings by severity (CRITICAL first), and within severity, by the order they were discovered.

### Finding 1 — `<SEVERITY>` — <one-line title>

**Severity:** CRITICAL / HIGH / MED / LOW

**Severity rubric application:**

| Rubric Q | Answer | Notes |
| - | --- | --- |
| Q1 — data class | Regulated / Personal / Business-sensitive / Public | _(brief justification)_ |
| Q2 — access scope | Full admin / Full read / Targeted / Bounded | _(brief justification)_ |
| Q3 — session state | Unauth / Auth-any / Auth-specific / Insider | _(brief justification)_ |
| Q4 — exploit complexity | Single step / Multi-step-no-tools / Multi-step-tools / Novel | _(brief justification)_ |
| Q5 — mitigations | None / DiD-fails / Active / Robust | _(brief justification)_ |

**Evidence (anonymized):**

```
<paraphrased or shape-preserving code excerpt, with identifiers genericized per how-we-anonymize.md>
```

OR

```
<request/response excerpt, with identifiers redacted>
```

Include just enough to make the finding legible. Verbatim quotes are NOT preferred when paraphrase serves; verbatim quotes are searchable back to source repos and break anonymization.

**Root cause:**

_(One paragraph. What is the underlying misconception or default that produced the failure? Not "the code did X" — "the code did X because the AI's default for this prompt is Y, which fails to consider Z.")_

**Fix-pattern shape:**

_(One paragraph. The structural change that addresses the root cause. NOT a specific code patch — patches go stale; structures don't. Example: "Move authorization check from UI conditional to backend-route guard; assert the requesting user's identity matches the resource owner before any data read." Not: "Replace line 42 with `if (req.user.id === resource.userId) ...`.")_

**Cross-references:**

- Related pattern: `../patterns/<stack>-default-failures.md` Pattern X (if a pattern exists)
- Related cross-stack baseline: `../patterns/cross-stack-failures.md` CS-XX (if relevant)
- Severity rubric: `../methodology/severity-rubric.md` (always)

### Finding 2 — `<SEVERITY>` — <one-line title>

_(repeat the structure above)_

### Finding 3 — `<SEVERITY>` — <one-line title>

_(repeat)_

_(...etc., one block per finding. Most teardowns have 3–8 findings; some have more.)_

---

## Methodology adherence

Per [`../methodology/how-we-audit.md`](../methodology/how-we-audit.md), which steps were performed:

| Step | Performed? | Notes (if applicable) |
| - | --- | --- |
| 1. Intake | Yes / No | _(if No: why)_ |
| 2. Reachability map | Yes / No | _(if No: why)_ |
| 3. Credential surface scan | Yes / No | _(if No: why)_ |
| 4. Data-isolation check | Yes / No | _(if No: why — and if Yes, confirm second-identity test account was used)_ |
| 5. Input-handling check | Yes / No | _(if No: why — list which input surfaces were tested)_ |
| 6. Write-up | Yes | _(this document)_ |

**Scope-out exclusions:** _(anything in the agreed scope-out from intake. If nothing, write "none.")_

**Time spent vs. methodology baseline:** _(actual hours vs. the ~6-hour baseline; explain any large deviation.)_

---

## Consent + responsible disclosure

**Consent:** Obtained on `YYYY-MM-DD`. Format: _(email thread / signed document — do not include the record itself; this statement confirms it exists)_.

**Anonymization standard:** Read by submitter as a hypothetical reader who knows the live app. Standard met per [`../methodology/how-we-anonymize.md`](../methodology/how-we-anonymize.md).

**Responsible disclosure window observed:**

| Field | Value |
| - | --- |
| Disclosure to owner date | `YYYY-MM-DD` |
| Agreed window length | _N_ days |
| Patch confirmed date | `YYYY-MM-DD` OR "patch pending; published at window expiry" |
| Days from disclosure to publication | _N_ |

---

## What changed about the app between audit and publication

_(Optional. If the owner patched between audit and publication, briefly note what changed. This helps readers understand whether the teardown reflects a current state or a historical state. Do NOT include details that re-identify the app.)_

Example: "Between audit and publication, the owner enabled RLS on the affected tables and rotated the exposed credential. The pattern documented here was current on the audit date; it is no longer exploitable on this specific app."

---

## Contributor note

_(Optional. Anything you want a future reader of the teardown to know. Keep it short. Do NOT use this space to market your audit services — that's grounds for rejection per `../CONTRIBUTING.md`.)_

---

_Submission instructions: see [`../CONTRIBUTING.md`](../CONTRIBUTING.md). Anonymization gate, consent record, methodology adherence statement are all required before merge._

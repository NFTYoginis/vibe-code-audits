# How we anonymize — redaction rules + consent model

The library publishes anonymized teardowns of real apps. "Anonymized" means: no reader who didn't already know about the audit can deanonymize the app from the teardown alone. This document is how that standard gets met.

The anonymization gate is a refusal-grade requirement. Teardowns that fail it don't ship.

---

## Why anonymization matters

Three reasons:

1. **App owner consent is conditional on it.** Most app owners agree to audit + publication on the explicit condition that the teardown doesn't name them or make them identifiable. If anonymization fails, consent is retroactively violated.

2. **Library integrity depends on it.** The library is about pattern recognition, not naming-and-shaming. A teardown that identifies its target reads as a hit-piece on that target; the same teardown anonymized reads as evidence of a pattern. The latter is what the library exists for.

3. **User safety depends on it.** Many teardowns document live-exploitable findings during the responsible-disclosure window. Naming the app while the finding is still live can directly harm that app's end users.

---

## Consent model

Every audited app falls into one of two categories. The category determines the consent record the contributor needs. Both categories are documented in [`../CONTRIBUTING.md`](../CONTRIBUTING.md); this file is the methodology-side detail.

### Category A — owner-authorized audit

The audit targets a real shipped app owned by someone other than the auditor. Owner consent is mandatory.

A documented agreement covering four things:

| What | Why |
| - | --- |
| Permission to perform the audit | Without this, the audit is unauthorized testing. |
| Permission to publish anonymized findings | Without this, even findings already in the public bundle can't go into the library. |
| Agreement on anonymization standard | The standard described below; the owner should understand it and agree it's sufficient. |
| Disclosure window for any CRITICAL or HIGH finding before publication | Commonly 90 days; can be shorter or longer by mutual agreement. The teardown publishes after the window OR after the owner confirms the issue is patched, whichever is later. |

### Category B — public-demo audit (no owner consent needed)

The audit targets one of:

- A vibe-coding tool's own published demo or marketing example
- A scaffold the auditor built themselves using the tool's default onboarding flow (self-cloned audit)
- A publicly-available reference app the tool's documentation explicitly invites users to audit, fork, or extend

The audit subject is *the tool's output pattern*, not a specific operator's deployment. The auditor IS the owner (for self-clones) or the artifact is public-domain demo (for vendor-published examples), so the Category A consent record doesn't apply.

Category B still requires:

| What | Why |
| - | --- |
| Statement of category in the PR | So maintainer can verify; PRs without category designation are closed without review. |
| Anonymization of any third-party deployment details that leaked into the demo (analytics IDs, etc.) | Demos sometimes carry incidental identifiers; strip them. |
| No mention of any real user / customer / operator who interacted with the demo | The audit is of the tool, not anyone who tried it. |

Category B does NOT require:

- Owner consent (the auditor is the owner, or there's no specific owner)
- A disclosure window (the audit subject is published, not deployed to real users at scale)
- Vendor consent from the tool itself (auditing a tool's public default behavior is fair commentary; it's not penetration-testing a service)

Format suggestion (email thread suffices):

> Subject: Audit + teardown publication consent — [date]
>
> I, [owner name], owner of [app name, kept private], consent to:
> 1. [Auditor name] performing a security audit of [app name] following the methodology at [URL of how-we-audit.md].
> 2. Publication of anonymized findings in the vibe-code-audit-teardown library at [repo URL], per the anonymization standard at [URL of how-we-anonymize.md].
> 3. A [90-day or other agreed length] disclosure window for any CRITICAL or HIGH-severity finding before publication, OR publication earlier if I confirm in writing that the issue is patched.
>
> I understand that the published teardown will not name [app name], me, or the app's distinguishing customer-facing details, and that the published artifact will be reviewed against the anonymization standard before going live.
>
> [Date, signature or email-thread acknowledgment]

The consent record **stays with the contributor**. The library does NOT ingest consent records — the contributor's PR statement confirms consent exists.

### What disqualifies a contribution from acceptance

For Category A (owner-authorized):

- No documented consent (the email thread or signed doc)
- Consent that doesn't cover publication
- Consent that doesn't cover the anonymization standard
- Audit performed before consent was obtained (post-hoc consent is not retroactively valid for unauthorized testing)

For Category B (public-demo):

- Category claim doesn't fit (e.g., the "demo" is actually a third-party operator's app you've recharacterized as a demo)
- Demo carries identifiable third-party deployment details that weren't anonymized
- Audit names real users / customers / operators who interacted with the demo

---

## What gets redacted

### Always redacted (no exceptions)

| Item | Replacement |
| - | --- |
| App name | Generic descriptor: "a B2B directory site," "a subscription content gating product," "a small SaaS dashboard" |
| App URL / domain | Removed entirely; never replaced with a fake URL (fake URLs sometimes resolve to real sites) |
| Owner identity | "App owner" or "the contributor's client" |
| Specific industry niche | Generalized one rung up: "a niche tools-and-services marketplace" → "a B2B marketplace"; "a yoga-studio-management tool" → "a small-business management tool" |
| Specific geographic region (if narrowly distinctive) | Generalized or removed: "a wine-bar booking app in a French city" → "a hospitality booking app" |
| Distinctive customer-list specifics | "Used by [named brands]" → removed entirely |
| Identifiers in code excerpts: table names, column names, route paths, env-var names that hint at the app | Genericized: `tbl_yogastudios` → `tbl_<entity>`; `/api/wine-bar/booking` → `/api/<resource>/<action>`; `STUDIO_API_KEY` → `<SERVICE>_API_KEY` |
| User IDs in evidence excerpts (even hashed) | `<user-uuid-a>`, `<user-uuid-b>` |
| Email addresses (real or test) | `user-a@example.test`, `user-b@example.test` |
| Stripe / Supabase / other-tenant project identifiers | `<project>.supabase.co`, `acct_<redacted>`, etc. |
| Server response excerpts containing real user data | Replaced with shape-preserving placeholders: `{"email": "<real-email>"}` → `{"email": "<redacted-email-string>"}` |

### Sometimes redacted (judgment call)

| Item | When to redact | When it can stay |
| - | --- | --- |
| Specific library/framework versions | If the version is narrow enough that combined with other details it identifies the app | If the version is broad ("Next.js 14.x") |
| Date of audit | If the audit followed a known public event the app was associated with | Otherwise; date is useful evidence |
| Stack composition exact details | If the combo is unique enough to identify (e.g., "Lovable + Pinecone + Anthropic" might be one of ~3 apps) | If the combo is common ("Lovable + Supabase + Stripe") |

### Never redacted

| Item | Why kept |
| - | --- |
| Stack name (Lovable / v0 / Bolt / Cursor / Replit) | The library is **stack-specific** by design; redacting the stack defeats the point |
| Severity grades | Grades are evidence; readers need them |
| Root-cause descriptions | The library's value is conveying these; redaction destroys the value |
| Fix-pattern shapes | Same reason as root cause |
| Methodology adherence statement | Reproducibility depends on knowing what was done |

---

## The anonymization gate — pre-submission self-check

Before submitting a teardown, the contributor reads the teardown as a hypothetical reader who knows the live app personally. The question is binary:

> Could this reader recognize the app from the teardown alone — using nothing the reader doesn't already know from outside the teardown?

If yes: re-anonymize. Common gaps that fail this check:

- Industry niche left too specific
- Customer-list detail left in
- A distinctive feature combination described accurately enough to triangulate
- Geographic region left in when audience size for that region is small
- Code excerpt containing a string that's also visible on the live app's public marketing page

If no: gate passed.

Maintainer reviews this gate again at PR time. PRs that fail the maintainer's pass are bounced back with specific concerns.

---

## Responsible disclosure

### What it is

For any CRITICAL or HIGH-severity finding discovered during the audit, the app owner gets a private disclosure window before the teardown publishes. The owner uses the window to patch.

### Default workflow

1. **Day 0:** audit completes; teardown drafted but NOT submitted to library.
2. **Day 0:** auditor sends private write-up of CRITICAL/HIGH findings to owner. Severity grade included; fix-pattern shape included.
3. **Day 0–90 (or agreed window):** owner patches. Owner can confirm patching at any point; once confirmed, the disclosure window closes immediately.
4. **Day 90 (or end of agreed window) OR upon owner confirmation of patch, whichever is later:** auditor submits teardown to library.
5. **At submission:** the teardown's "Methodology adherence" section notes that responsible disclosure was observed, and the timeline (without naming the owner or app).

### When the window can be shorter

- Owner explicitly confirms patch and waives the remainder of the window
- Finding becomes publicly known by another channel (e.g., the app was breached and the breach is public)

### When the window can be longer

- Owner is making good-faith progress but needs more time, and the finding isn't being actively exploited
- The finding requires architectural change, not a code patch

### What's not negotiable

- The teardown does NOT publish while the finding is still actively exploitable in production AND the owner is still in good-faith remediation.
- If the owner refuses to patch and refuses to acknowledge: the auditor still does not publish a still-exploitable finding. The pattern can be added to a per-stack pattern file in generalized form (without the specific evidence), and the specific teardown sits in the contributor's private records until the issue is either resolved by other means (app shut down, owner relents, etc.) or the underlying vulnerability becomes inert.

---

## What's NOT covered by anonymization but matters anyway

### Aggregation risk

A single teardown can be perfectly anonymized. Five teardowns from the same auditor on apps in adjacent niches can be deanonymizable in aggregate (the auditor's client portfolio narrows the candidate set).

**Mitigation:** the library aggregates contributions from many auditors. If a single auditor contributes a high volume in a narrow niche, the maintainer may ask them to delay or alternate stack-coverage to avoid aggregation-fingerprinting.

### Search-engine indexing

Code excerpts in teardowns are searchable. If a code excerpt is too distinctive — even after identifier renaming — it can be searched back to its source repo (if the repo is public).

**Mitigation:** for code excerpts, prefer shape-preserving paraphrase over verbatim quote when the verbatim has distinctive variable-naming or comment styles. The point is to show the failure shape, not to forensically reproduce the source.

---

## Cross-references

- The 6-step audit methodology: [`how-we-audit.md`](how-we-audit.md)
- Severity grades: [`severity-rubric.md`](severity-rubric.md)
- Submission process: [`../CONTRIBUTING.md`](../CONTRIBUTING.md)

---

_Last updated: 2026-05-18 (initial scaffold; anonymization gate is refusal-grade for library inclusion)._

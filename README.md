# Vibe-Code Audit Teardowns

Empirical, named-stack audits of real apps shipped from Lovable, v0, Bolt.new, Cursor, and Replit Agent. Anonymized findings, severity-scored, free and MIT-licensed.

---

## What this is

- **Stack-specific.** Each teardown audits one named tool. Findings are filed under the stack that produced them, not against a generic AI-code checklist.
- **Empirical.** Every claim cites a real audit. No theoretical advisories, no checklist-by-deduction.
- **Anonymized.** App identities are redacted. Consent rules are documented and enforced before publication.

## Browse teardowns

| Teardown | Stack | Archetype | Audit date | Highest severity | Findings |
| --- | --- | --- | --- | --- | --- |
| [`TD-LOVABLE-PLACEHOLDER-self-clone-habit`](teardowns/TD-LOVABLE-PLACEHOLDER-self-clone-habit.md) | Lovable + Supabase | Habit-tracker scaffold | 2026-05-19 | MED | 3 (1 MED, 2 LOW) |
| [`TD-BOLT-PLACEHOLDER-event-mgr`](teardowns/TD-BOLT-PLACEHOLDER-event-mgr.md) | Bolt.new + Supabase | Event-management SaaS scaffold | 2026-05-19 | **CRITICAL** | 4 (2 CRITICAL, 1 MED, 1 LOW) |

Both are self-cloned methodology validations by the repo author, not third-party client work. Three of the five scoped stacks — v0, Cursor, Replit Agent — are not yet audited. Teardown IDs are the placeholder IDs carried in the files; each document states that a final `TD-<STACK>-<NNN>` is assigned at merge, and that assignment is still outstanding.

Every entry follows the same format, set by [`teardowns/_TEMPLATE.md`](teardowns/_TEMPLATE.md): a header (stack, audit date, app type), a severity summary counted by level, severity-ordered findings that each apply the five-question rubric and carry anonymized evidence, a methodology-adherence table recording which of the six steps ran and where the audit deviated, and a consent + responsible-disclosure record.

## Stack pattern libraries

| Pattern library | Teardowns in evidence | State |
| --- | --- | --- |
| [`lovable-default-failures.md`](patterns/lovable-default-failures.md) | 1 | Scaffolded — awaits teardown-grounded fill |
| [`v0-default-failures.md`](patterns/v0-default-failures.md) | 0 | Scaffolded — awaits teardown-grounded fill |
| [`bolt-default-failures.md`](patterns/bolt-default-failures.md) | 1 | Scaffolded — awaits teardown-grounded fill |
| [`cursor-default-failures.md`](patterns/cursor-default-failures.md) | 0 | Scaffolded — awaits teardown-grounded fill |
| [`replit-default-failures.md`](patterns/replit-default-failures.md) | 0 | Scaffolded — awaits teardown-grounded fill |
| [`cross-stack-failures.md`](patterns/cross-stack-failures.md) | n/a — baseline | 12 patterns (CS-01–CS-12) |

Each stack accumulates its own pattern library as audits land. A pattern claim requires at least three teardowns showing the same failure mode; until that threshold is met, observations stay in the individual teardowns. **No per-stack library has reached N=3, so all five hold their scaffolded structure with no filled patterns** — an empty slot is correct here, an invented pattern is not. The filled slots each name the tool default that produces the failure, the teardown IDs grounding it, and the fix-pattern shape. The cross-stack file is the baseline rather than differentiated content, and says so: it collects the twelve failure shapes that recur regardless of tool, most of which also appear in OWASP and NIST material.

## Methodology

> Audits run a fixed six-step process documented at [`methodology/how-we-audit.md`](methodology/how-we-audit.md). Severity follows the rubric at [`methodology/severity-rubric.md`](methodology/severity-rubric.md): CRITICAL means exploitable in production with a publicly-known technique, HIGH means exploitable with effort, MED means a production-quality miss, LOW means a code smell. Anonymization and consent rules are at [`methodology/how-we-anonymize.md`](methodology/how-we-anonymize.md). The methodology is reproducible — an outside auditor can run the same steps and submit findings.

## Contribute

Outside auditors can submit full teardowns, single-finding additions to existing pattern files, and corrections to published findings. Consent and anonymization rules are non-negotiable. The PR template, severity-scoring guide, and review timeline are at [`CONTRIBUTING.md`](CONTRIBUTING.md).

<!-- TODO: Angle D activation -->

## License

MIT — see [`LICENSE`](LICENSE). Free to use, fork, and build on. Attribution appreciated; required for redistribution.

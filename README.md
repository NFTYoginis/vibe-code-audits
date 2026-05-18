# Vibe-Code Audit Teardowns

Empirical, named-stack audits of real apps shipped from Lovable, v0, Bolt.new, Cursor, and Replit Agent. Anonymized findings, severity-scored, free and MIT-licensed.

---

## What this is

- **Stack-specific.** Each teardown audits one named tool. Findings are filed under the stack that produced them, not against a generic AI-code checklist.
- **Empirical.** Every claim cites a real audit. No theoretical advisories, no checklist-by-deduction.
- **Anonymized.** App identities are redacted. Consent rules are documented and enforced before publication.

## Browse teardowns

<!-- specialist-builder injects the linked teardown table here: Stack / Archetype / Date / Verdict / Findings count -->

Every entry follows the same format: a verdict (shippable-as-is / shippable-after-fixes / scrap-and-restart), severity-ordered findings with anonymized code excerpts, a stack-pattern summary naming the tool defaults that produced the failures, and a net assessment of whether the issue is a tool problem, an operator problem, or both.

## Stack pattern libraries

<!-- specialist-builder injects the linked grid of pattern files — one card per stack — here -->

Each stack accumulates its own pattern library as audits land. A pattern claim requires at least three teardowns showing the same failure mode; until that threshold is met, observations stay in the individual teardowns. Pattern files name the tool default that produces the failure, the audits-in-evidence count, and the detection method an outside reader can use to spot it themselves.

## Methodology

> Audits run a fixed six-step process documented at [`methodology/how-we-audit.md`](methodology/how-we-audit.md). Severity follows the rubric at [`methodology/severity-rubric.md`](methodology/severity-rubric.md): CRITICAL means exploitable in production with a publicly-known technique, HIGH means exploitable with effort, MED means a production-quality miss, LOW means a code smell. Anonymization and consent rules are at [`methodology/how-we-anonymize.md`](methodology/how-we-anonymize.md). The methodology is reproducible — an outside auditor can run the same steps and submit findings.

## Contribute

Outside auditors can submit full teardowns, single-finding additions to existing pattern files, and corrections to published findings. Consent and anonymization rules are non-negotiable. The PR template, severity-scoring guide, and review timeline are at [`CONTRIBUTING.md`](CONTRIBUTING.md).

<!-- TODO: Angle D activation -->

## License

MIT — see [`LICENSE`](LICENSE). Free to use, fork, and build on. Attribution appreciated; required for redistribution.

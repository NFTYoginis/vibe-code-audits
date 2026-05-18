# Cross-stack failure patterns

Failure patterns that show up across multiple vibe-coding stacks, regardless of which tool generated the code. Included for completeness — you've seen most of these elsewhere (OWASP, NIST, common security checklists).

**You are here for the named-stack teardowns.** This file is the slim baseline. The teardowns and the per-stack pattern files are the substance of the library.

This file holds **12 patterns** observed recurring in vibe-coded apps across two or more stacks. The list intentionally stops at ~12–15 — the per-stack files are where stack-specific nuance lives.

---

## Severity legend

Per [`../methodology/severity-rubric.md`](../methodology/severity-rubric.md):

- **CRITICAL** — unauthorized access to regulated/personal data OR full admin from unauthenticated session OR exploitable in a single step with no mitigation
- **HIGH** — significant data exposure OR authentication/authorization bypass OR exploitable with one prerequisite
- **MED** — meaningful failure but bounded blast radius OR requires non-trivial chain
- **LOW** — defensible default that should be tightened but isn't actively exploitable today

---

## The 12 cross-stack patterns

### CS-01 — Secrets / API keys in client bundle

**Severity (typical):** CRITICAL (if the key is a privileged credential — service-role, admin, write-scope) / HIGH (if read-scope only)

The single most-observed cross-stack failure. Vibe-coding tools default to embedding API keys in the client because the prompt was "build me an app that calls X" and the tool wired the simplest path. Includes Supabase service-role JWTs, Stripe secret keys, OpenAI keys, AWS access keys, third-party API keys with billing attached.

**Where it shows up:** Lovable (Supabase service-role), v0 (third-party API keys in client components), Bolt.new (anything in `.env` that gets shipped to the browser bundle), Cursor (when Composer generates a "quick API call" without backend), Replit (env vars unintentionally exposed via client-side imports).

### CS-02 — Authorization checked at UI, not at data layer

**Severity (typical):** CRITICAL (regulated/personal data) / HIGH (otherwise)

UI hides admin buttons from non-admin users. Backend endpoints accept the request regardless of caller role. Trivially exploitable with `curl` or DevTools.

**Where it shows up:** Universal. Any stack that lets the AI generate UI + API in one shot tends to put the auth check in the UI ("if user.isAdmin show this button") and forget the API-side enforcement.

### CS-03 — No rate limiting on signup, password-reset, or expensive endpoints

**Severity (typical):** MED to HIGH

Vibe-coding tools default to no rate-limiting middleware. Signup endpoints get bot-abused. Password-reset endpoints become enumeration oracles. Expensive endpoints (LLM calls, large queries) become billing-attack vectors.

**Where it shows up:** All stacks. Especially severe on stacks that wire in LLM APIs or per-call paid services.

### CS-04 — Webhook handlers with no signature verification

**Severity (typical):** HIGH

Stripe / GitHub / generic-third-party webhook handlers scaffolded without verifying the inbound signature. Anyone who knows the endpoint URL can POST forged events. For Stripe specifically: forged `payment_succeeded` events that grant paid access without payment.

**Where it shows up:** Lovable, Bolt, Replit (any stack where the tool scaffolds a webhook handler from "set up Stripe payments").

### CS-05 — Webhook handlers without idempotency

**Severity (typical):** MED to HIGH

Even when signature verification is present, the handler processes the same event multiple times if the third party retries. Stripe and most payment processors WILL retry. Without idempotency, one payment can grant access twice (or once and refund once and still grant access).

**Where it shows up:** Same as CS-04. Often paired.

### CS-06 — CORS wide open (`Access-Control-Allow-Origin: *`)

**Severity (typical):** MED (CRITICAL if paired with cookie-based auth)

Vibe-coded backends frequently ship with permissive CORS to "make the frontend work" during development. The `*` ships to production. Paired with cookie-based auth, this enables cross-origin credentialed requests.

**Where it shows up:** Universal. Particularly common on Bolt and Replit because their preview environments make CORS friction visible early.

### CS-07 — User input concatenated into SQL, shell, or HTML

**Severity (typical):** CRITICAL to HIGH depending on context

The classic injection trifecta. Vibe-coding tools generate parameterized queries most of the time, but slip into string concatenation when the prompt is unusual ("filter by this dynamic column"). Shell injection appears when the AI generates code that shells out (e.g., file conversion utilities). HTML injection appears when the AI renders user-provided strings via `dangerouslySetInnerHTML` or equivalent.

**Where it shows up:** Universal. Frequency varies; severity does not.

### CS-08 — No CSRF protection on state-changing endpoints

**Severity (typical):** MED to HIGH

Modern frameworks (Next.js App Router, SvelteKit) have CSRF protection available but not always default. Vibe-coding tools don't always wire it up.

**Where it shows up:** v0, Cursor (when generating Next.js code). Less common on stacks that use API tokens in headers exclusively.

### CS-09 — Verbose error messages leaking stack traces, table names, or library versions

**Severity (typical):** LOW to MED

Helpful in development; bad in production. Vibe-coded apps frequently ship with development-mode error pages live. Stack traces reveal framework + version + sometimes file paths. Table names reveal schema. Library versions enable targeted CVE lookups.

**Where it shows up:** Universal.

### CS-10 — File upload endpoints accepting arbitrary file types or sizes

**Severity (typical):** MED to HIGH

Vibe-coded upload endpoints often skip: file-type validation, size limits, virus scanning, storage-path sanitization. Each absence has its own failure mode (XSS via SVG upload, storage cost-attack, path traversal, malware redistribution).

**Where it shows up:** Bolt, Lovable, Replit — anywhere the tool scaffolds "let users upload an image."

### CS-11 — Session tokens stored in localStorage instead of httpOnly cookies

**Severity (typical):** MED

XSS becomes session takeover. Vibe-coding tools default to localStorage because it's the most-prompted pattern in JS-heavy codebases. httpOnly cookies require backend cooperation that the tool may skip.

**Where it shows up:** Universal. Severity is bounded by whether XSS is also present (CS-07); if both are present, severity escalates.

### CS-12 — Environment-variable validation absent; missing vars fail silently or expose defaults

**Severity (typical):** LOW to MED (occasional HIGH)

`process.env.STRIPE_SECRET_KEY` undefined in production → app silently falls back to test mode → users charged a test card OR test-card numbers accepted as real payments. Variations: missing OAuth client secret → app falls back to a hard-coded default the AI invented.

**Where it shows up:** Universal. The hard-coded-default variant is more common in Lovable and Bolt (which optimize for "it just works in preview" and sometimes inline defaults).

---

## What's NOT in this list

The 12 above are the cross-stack baseline because they appear in teardowns across multiple stacks. Patterns that appear in one stack's teardowns but not others live in the per-stack pattern files.

Patterns that are theoretical (in OWASP / NIST but not yet in any teardown the library has produced) are also not here. The cross-stack list is **empirically observed**, not theoretically compiled. Theoretical patterns belong in the source documents (OWASP Top 10, NIST guidance, etc.); the library's value is what's been confirmed in real audits.

---

## How to use this list

- **Doing a pre-flight checklist (Job 4)?** The specialist cross-references this file plus the per-stack file for your tool. The combination gives a personalized checklist.
- **Doing a teardown?** Run through this file as part of `methodology/how-we-audit.md` step 4 (data-isolation) and step 5 (input-handling). Don't claim these as novel findings — they're the baseline. Novel findings are the stack-specific patterns.
- **Reading for general knowledge?** Fine, but the per-stack files are where the differentiated content lives. This file is here so you don't ask the specialist "what about SQL injection" and get back "we cover that, see CS-07."

---

## Cross-references

- Per-stack pattern files: [`lovable-default-failures.md`](lovable-default-failures.md), [`v0-default-failures.md`](v0-default-failures.md), [`bolt-default-failures.md`](bolt-default-failures.md), [`cursor-default-failures.md`](cursor-default-failures.md), [`replit-default-failures.md`](replit-default-failures.md)
- Audit methodology: [`../methodology/how-we-audit.md`](../methodology/how-we-audit.md)
- Severity rubric: [`../methodology/severity-rubric.md`](../methodology/severity-rubric.md)

---

_Last updated: 2026-05-18 (initial scaffold; 12 empirically-attested cross-stack patterns. Per-stack pattern files are where the differentiated content lives.)_

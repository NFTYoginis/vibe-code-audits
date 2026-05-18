# How we audit — the 6-step methodology

Every teardown in the library follows this process. The point is reproducibility — anyone who follows the 6 steps on the same target should produce a comparable teardown. If you want to audit your own app, hire someone to audit your app, or contribute a teardown to the library — this is what you'd do or have done.

The methodology is **stack-agnostic** at the structural level. Stack-specific notes appear inline; the spine is the same regardless of whether the target is a Lovable, v0, Bolt.new, Cursor, or Replit Agent app.

---

## Before step 1 — preconditions

| Precondition | Why it's mandatory |
| - | --- |
| Documented consent from the app owner | Auditing without consent isn't research; it's unauthorized testing. Library refuses contributions without consent regardless of finding severity. See [`how-we-anonymize.md`](how-we-anonymize.md) §"Consent model." |
| A test account on the live app | Audit happens against the live production target, not a code snapshot. Code snapshots miss runtime configuration. Test account scope: enough to exercise the full user flow the audit covers. |
| A separate test account from a second identity | Data-isolation testing (step 4) requires two accounts to confirm cross-tenant boundaries. |
| Time-box agreement with the app owner | Typical: 6 working hours for a small SaaS. Pre-agreed so the owner knows when to expect the write-up. |
| Scope agreement | What's in (auth, data isolation, payments, file uploads, etc.) and what's out (third-party integrations the owner doesn't own, etc.). |

If any precondition isn't met, do not proceed.

---

## Step 1 — Intake (stack-agnostic)

**Goal:** characterize what the target is before touching it.

**Time:** 20–40 minutes.

**Inputs:**
- App URL
- Stack confirmation (the owner says "Lovable + Supabase + Stripe" but verify by inspecting the page source / network traffic / `package.json` if accessible)
- App owner's description of: data classes handled, user types, auth flow, payment flow (if any), third-party integrations

**Outputs:** an intake document. Format suggestion:

```
TARGET: <anonymized identifier>
STACK: <confirmed stack>
DATA CLASSES: [list — e.g., user PII, billing data, user-generated content, payment data via Stripe]
USER TYPES: [list — e.g., end-users, admins]
AUTH FLOW: [one paragraph]
PAYMENT FLOW: [one paragraph, "none" if applicable]
THIRD-PARTY INTEGRATIONS: [list]
SCOPE IN: [list of audit targets]
SCOPE OUT: [list of explicit exclusions]
TIME-BOX: <hours>
```

**Stack-specific intake notes:**
- **Lovable apps:** confirm whether Supabase is the data layer (it usually is). Confirm whether RLS is the intended access-control mechanism. Verify what the owner *thinks* about RLS — many owners don't know it exists, which is itself a finding.
- **v0 apps:** confirm framework (Next.js typically; React-only sometimes). Confirm whether server actions, route handlers, or both carry the API surface.
- **Bolt.new apps:** confirm the deployment target (Netlify / Vercel / self-hosted). Bolt's preview env differs from production.
- **Cursor apps:** confirm what Composer generated vs. what the human wrote. Audits of mostly-human code with Composer-touched-up sections are different from audits of mostly-Composer-generated code.
- **Replit Agent apps:** confirm whether the app runs on Replit Deployments or elsewhere. Replit-hosted has different env-var and secret-handling defaults than self-hosted.

---

## Step 2 — Reachability map

**Goal:** enumerate the externally-reachable surface.

**Time:** 30–60 minutes.

**Method:**
- Navigate the live app as a regular user. Capture every distinct route in DevTools Network tab.
- Capture every distinct request type per route (auth, data fetch, mutation, file upload, etc.).
- Log out, capture which routes remain reachable (some always do — landing, login, signup).
- For each unauthenticated reachable route: note what data it exposes.

**Outputs:** a route table. Each row: route, method, auth-required (yes/no), data class exposed, third-party endpoints called.

**Stack-specific notes:**
- **Lovable + Supabase:** the Supabase JS client makes the data layer's URL pattern fully visible. Look for `<project>.supabase.co/rest/v1/<table>` calls in DevTools — the table name list IS the schema reveal.
- **v0 / Next.js:** server actions appear as `POST /` requests with a `Next-Action` header. Enumerate distinct actions by header value.
- **Bolt.new:** WebContainers preview runs in-browser, but production deploys to a real backend. The reachability map applies to the production deploy, not the WebContainer preview.

---

## Step 3 — Credential surface scan

**Goal:** find credentials reachable from the browser or otherwise leaked.

**Time:** 30–60 minutes.

**Method:**
- View page source. Grep for `key`, `secret`, `token`, `service_role`, `sk_`, `pk_live`, AWS key prefixes (`AKIA`, `ASIA`), `eyJ` (JWT prefix), `password`.
- Inspect the JavaScript bundle (DevTools Sources tab, or download and grep). Same patterns.
- Inspect localStorage and sessionStorage for the test account. Note what's stored.
- Inspect cookies. Note `httpOnly`, `Secure`, `SameSite` flags on auth-bearing cookies.
- Check the `Authorization` header on outbound requests. Decode any JWT — note `role`, `aud`, `exp`, `iss` claims. A `service_role` claim in a JWT reachable from the browser is the canonical finding.
- Check public GitHub for the app's repo (if open-source or accidentally public). Grep history for keys (Trufflehog or similar; manual `git log -p | grep` for the patterns above suffices for a quick pass).

**Outputs:** a credential table. Each entry: where found, type, scope, severity per rubric.

**Stack-specific notes:**
- **Lovable:** `service_role` JWTs in the client bundle are the most-attested finding in this library. Always look. Also check for hard-coded API keys to OpenAI / Anthropic / similar (Lovable AI-feature scaffolds sometimes inline these).
- **Bolt:** WebContainer envs sometimes leak `.env` contents into the browser bundle during preview. Check whether this leaks to production too.

---

## Step 4 — Data-isolation check (cross-tenant)

**Goal:** confirm that user A cannot read or write user B's data.

**Time:** 60–120 minutes (the longest step on most audits).

**Method:**
- Create data as user A in the test account.
- As user B (the second identity), attempt to read user A's data via:
  - The normal app UI (controlled experiment — should fail)
  - Direct API calls with user B's auth, requesting user A's resource IDs (the main test)
  - Direct database client calls (e.g., Supabase JS client) if the data layer is browser-reachable
  - Enumeration: change ID parameters, increment numeric IDs, swap UUIDs
- Repeat for write: as user B, attempt to modify user A's data.
- Repeat for delete: as user B, attempt to delete user A's data.

**Outputs:** an isolation table. Each row: data class, read-as-other-user verdict, write-as-other-user verdict, delete-as-other-user verdict, severity per rubric.

**Stack-specific notes:**
- **Lovable + Supabase:** if RLS is disabled on a table, ALL reads/writes from any authenticated user succeed. Check RLS state per table (Supabase dashboard → table → policies). If you can't access the dashboard, infer from behavior: a successful read of another user's row with the JS client and no policy filter is a strong signal.
- **v0 / Next.js with server actions:** authorization checks live in server-action bodies. Test each action with mismatched IDs.
- **Replit Agent apps with the bundled Replit DB:** check whether keys are scoped per user or globally accessible.

---

## Step 5 — Input-handling check

**Goal:** confirm that user inputs are validated, escaped, and rate-limited.

**Time:** 60–90 minutes.

**Method:**
- For every form / API input identified in step 2, test:
  - SQL/NoSQL injection payloads (parameterized? error messages?)
  - HTML/script injection (does the input render anywhere unescaped?)
  - File upload abuse if applicable (oversize file, executable file type, SVG with script, path-traversal filename)
  - Rate-limit testing (rapid-fire 50 signup attempts, 100 password-reset requests for the same email)
  - For webhooks: send a forged event with no signature, with a wrong signature, with a replayed event
- For each finding: severity per rubric.

**Outputs:** an input-handling table. Each row: input surface, attack class, observed behavior, severity per rubric.

**Stack-specific notes:**
- **All stacks:** check Stripe webhook handlers for signature verification AND idempotency (separate checks; both can fail independently). See `cross-stack-failures.md` CS-04 and CS-05.

---

## Step 6 — Write-up

**Goal:** produce the teardown document.

**Time:** 60–120 minutes.

**Method:**
- Start from `teardowns/_TEMPLATE.md`.
- For each finding from steps 3–5:
  - Title (one line, severity-prefixed)
  - Evidence excerpt (anonymized per `how-we-anonymize.md`)
  - Why it fails (root cause, not just symptom)
  - Fix-pattern shape (the structural change needed, not a specific code patch — patches go stale; structures don't)
- Aggregate severity counts at the top.
- Add a "methodology adherence" line: which of the 6 steps were performed; if any skipped, why.
- Add a "consent" line: confirms consent obtained (does not include the consent record).
- Submit per `CONTRIBUTING.md`.

**Anonymization gate before submission:** read the teardown as a stranger who knows the live app personally. Can you recognize it? If yes, the anonymization isn't done. Re-anonymize. See `how-we-anonymize.md`.

---

## Total time per audit

Typical small-SaaS audit: **6 working hours** end-to-end, distributed:

- Step 1 (intake): 30 min
- Step 2 (reachability): 45 min
- Step 3 (credentials): 45 min
- Step 4 (data isolation): 90 min
- Step 5 (input handling): 75 min
- Step 6 (write-up): 90 min
- Buffer / re-checks: 45 min

Larger apps take longer; smaller apps don't take meaningfully less because intake and write-up have a fixed floor.

---

## What this methodology does NOT cover

- **Penetration testing of infrastructure** — server hardening, network-level attacks, DDoS resilience. Those are separate disciplines.
- **Source-code-only static analysis** — the methodology is dynamic, against the live target. Pure SAST is complementary, not a substitute.
- **Compliance audit** — per `rules.md` Refusal Gate 3, compliance certification is attorney / compliance-officer work. The methodology surfaces technical findings that inform compliance; it doesn't certify.
- **Long-term monitoring** — the audit is a snapshot. Apps drift after audit.

If the scope you need isn't covered by this methodology, name that — the library doesn't pretend the methodology covers everything.

---

## Cross-references

- Consent + anonymization: [`how-we-anonymize.md`](how-we-anonymize.md)
- Severity grading: [`severity-rubric.md`](severity-rubric.md)
- Cross-stack baseline patterns: [`../patterns/cross-stack-failures.md`](../patterns/cross-stack-failures.md)
- Per-stack patterns: [`../patterns/lovable-default-failures.md`](../patterns/lovable-default-failures.md) (and siblings)
- Teardown format: [`../teardowns/_TEMPLATE.md`](../teardowns/_TEMPLATE.md)

---

_Last updated: 2026-05-18 (initial scaffold; 6-step methodology, ~6 working hours per small-SaaS audit)._

# TD-BOLT-PLACEHOLDER — small self-cloned event-management SaaS scaffold

> Placeholder ID; maintainer assigns final `TD-BOLT-<NNN>` at merge.

---

## Header

| Field | Value |
| - | --- |
| Teardown ID | `TD-BOLT-PLACEHOLDER-event-mgr` |
| Stack | Bolt.new on `bolt.host` preview hosting + Supabase (Auth + PostgREST) |
| Audit date | 2026-05-19 |
| Auditor | Repo author (self-cloned methodology validation) |
| App type | Small event-management SaaS scaffold; email + password auth; per-user event creation; public-by-default event listing; no payments, no file uploads, no LLM features |
| Audit duration | ~3 working hours (compressed scope-appropriate run) |

---

## Severity summary

| Severity | Count |
| - | --- |
| CRITICAL | 2 |
| HIGH | 0 |
| MED | 1 |
| LOW | 1 |

**Overall teardown severity:** CRITICAL.

The two CRITICAL findings share a root cause: RLS is enabled on the `events` table and policies exist for `SELECT` and `INSERT` (both correctly scoped to `auth.uid()`), but the `UPDATE` and `DELETE` paths are governed by policies that do not tie the operation to row ownership. The effect is that any holder of the public anon key — i.e., anyone who loads the homepage — can edit or delete any event row, regardless of authentication status. The verb-by-verb shape of the failure is the canonical "partial RLS" pattern; it's what makes this teardown worth recording.

A noteworthy positive: the highest-frequency Bolt/Lovable CRITICAL — a Supabase `service_role` JWT inlined in the client bundle (see [`../patterns/cross-stack-failures.md`](../patterns/cross-stack-failures.md) CS-01) — does **not** appear here. The bundle ships only the public `anon` key, which is what the platform intends. The `events.INSERT` policy correctly enforces `auth.uid() = organizer_id`, so users cannot create events attributed to other users. `profiles` and `registrations` SELECT correctly returns empty to the anon role. The data-shape findings are concentrated on two specific verbs of one specific table — not a wholesale "RLS off" failure.

---

## Findings

### Finding 1 — `CRITICAL` — Anon role can UPDATE any row on `events` table

**Severity:** CRITICAL

**Severity rubric application:**

| Rubric Q | Answer | Notes |
| - | --- | --- |
| Q1 — data class | Personal (organizer-attributed user-generated content tied to identifiable user UUIDs); Business-sensitive in any deployment where event content carries operational value | Events carry title, description, location, dates, capacity, and `organizer_id` linking to a user identity |
| Q2 — access scope | Targeted write across all rows | Any field on any row can be modified by referencing its UUID; full enumeration is unnecessary because the row IDs are visible to authenticated users in the public listing |
| Q3 — session state | Unauthenticated | Only the public `apikey` (anon JWT) is required, which is hardcoded in the client bundle and downloadable by anyone |
| Q4 — exploit complexity | Single step | One `curl PATCH` request with the anon `apikey` header, no Authorization header, and a JSON body |
| Q5 — mitigations | None | No rate limit observed on PostgREST writes; no application-level audit log surfaced; no row-version or optimistic-concurrency check; the application UI's "no edits after publish" workflow is enforced only in client code |

**Evidence (anonymized):**

```
PATCH https://<project>.supabase.co/rest/v1/events?id=eq.<event-uuid-of-other-user>
Headers:
  apikey: <anon-jwt-with-role=anon>      # the public anon key from the JS bundle
  Content-Type: application/json
  # NO Authorization header sent
Body:
  {"title": "<arbitrary new value>"}

Response:
  HTTP 204 No Content
```

The PATCH was sent against an event row whose `organizer_id` belongs to a different user than the caller — and indeed the caller was unauthenticated entirely. The row was modified successfully. The same shape works for any column on `events`, including `status` (so a malicious caller could toggle other users' events to `draft`/`published`), `start_at` / `end_at` (date manipulation), `organizer_id` (reassign ownership), or `description` (content defacement / phishing payload injection).

**Root cause:**

PostgreSQL row-level security operates per verb. When RLS is enabled on a table, each of `SELECT`, `INSERT`, `UPDATE`, `DELETE` requires its own policy to permit the operation. If a verb has no policy, the operation is denied. If a verb has a permissive policy with no row-ownership predicate (for example `FOR UPDATE USING (true)`), the operation is permitted for every caller including the unauthenticated `anon` role. The scaffold's `events` table has policies that correctly scope `SELECT` (`anon` gets empty) and `INSERT` (caller's `auth.uid()` must equal supplied `organizer_id`), but the `UPDATE` policy — whatever its exact form — does not tie the operation to row ownership. The AI scaffold generator wrote a partial policy set. The result is that the `UPDATE` verb is reachable by any holder of the anon key, which is by design a public credential.

The application UI's "no edits allowed after an event is published" rule, observable in the operator's intake answers, is a UI-side workflow constraint. PostgREST does not see the UI; it sees a PATCH request that satisfies the (permissive) policy, and complies.

**Fix-pattern shape:**

The fix is at the data layer, not the application code. On the `events` table, redefine the UPDATE policy so that it requires the caller to own the row and (separately) that the post-update row also satisfies ownership. In PostgreSQL terms: `USING (auth.uid() = organizer_id)` to scope WHICH rows can be updated, AND `WITH CHECK (auth.uid() = organizer_id)` to prevent ownership-transfer via UPDATE. Both predicates are necessary; the `USING` predicate alone permits a row owner to reassign their event to someone else (effectively a write to another user's surface). Equivalent fix shape applies to the DELETE policy in Finding 2.

Independent of the RLS fix, the application UI's "no edits after publish" rule, if it is intended to be enforceable rather than a UX convention, must be expressed as a policy predicate as well: for example, an UPDATE policy that further restricts allowed transitions when `OLD.status = 'published'`. UI-side workflow rules that aren't reflected in policy are not security boundaries; they are conventions an attacker bypasses by going around the UI.

**Cross-references:**

- Cross-stack pattern: [`../patterns/cross-stack-failures.md`](../patterns/cross-stack-failures.md) CS-02 (Authorization checked at UI, not at data layer). This finding is a sharp instance of CS-02 with the additional twist that the data layer also has a permissive policy, so the failure is double-layer: UI says "no" and the data layer says "yes regardless."
- Severity rubric: [`../methodology/severity-rubric.md`](../methodology/severity-rubric.md). Canonical-CRITICAL example: `Q2 = Full admin AND Q3 = Unauthenticated`. This finding sits just shy of full-admin (it's targeted write, not full schema control), but Q3 Unauthenticated + Q4 Single-step + Q5 None still drives the grade to CRITICAL via the "single-step full read OR write of personal data" path.

---

### Finding 2 — `CRITICAL` — Anon role can DELETE any row on `events` table

**Severity:** CRITICAL

**Severity rubric application:**

| Rubric Q | Answer | Notes |
| - | --- | --- |
| Q1 — data class | Personal / Business-sensitive (same as Finding 1) | Deletion destroys the user-generated content; the destruction itself is the harm |
| Q2 — access scope | Targeted destructive write across all rows | Equivalent reach to Finding 1 but irreversible from outside a database backup |
| Q3 — session state | Unauthenticated | Same as Finding 1 |
| Q4 — exploit complexity | Single step | One `curl DELETE` request |
| Q5 — mitigations | None | No soft-delete pattern observed; the row is gone after the call returns. No application-level deletion audit log surfaced |

**Evidence (anonymized):**

```
DELETE https://<project>.supabase.co/rest/v1/events?id=eq.<event-uuid-of-other-user>
Headers:
  apikey: <anon-jwt-with-role=anon>
  # NO Authorization header sent

Response:
  HTTP 204 No Content
```

Confirmed by accidental destruction of a real test-account event during methodology validation; subsequent SELECT confirmed the row was gone. Restoration via the API was blocked by the (correctly-configured) INSERT policy — recreation required the row owner to log in and rebuild the event through the UI. That asymmetry — anyone can destroy, only the owner can rebuild — sharpens the operational impact.

**Root cause:**

Same shape as Finding 1: the `events` table's DELETE policy does not tie the operation to row ownership. The AI scaffold generator produced INSERT and SELECT policies grounded in `auth.uid()` but generated an UPDATE/DELETE permission surface that is effectively unrestricted at the data layer. This pattern is consistent with how Bolt.new's per-prompt SQL migration generation can produce partial coverage when the prompt focuses on "let users create and view their events" without explicitly naming the destructive verbs.

**Fix-pattern shape:**

On the `events` table, redefine the DELETE policy to require `auth.uid() = organizer_id`. Optionally, replace hard-delete with a soft-delete column (`deleted_at` timestamp) so that any unauthorized DELETE is recoverable by an operator with backend access; this is defense-in-depth, not a substitute for fixing the policy.

**Cross-references:**

- Cross-stack pattern: CS-02 (same as Finding 1).
- This finding and Finding 1 are best understood as a paired root cause: the partial-RLS shape. A future Bolt pattern file entry might describe it as "Bolt scaffolds frequently scope SELECT/INSERT correctly but leave UPDATE/DELETE unscoped," contingent on additional teardowns observing the same shape (current N=1; pattern claim awaits N=3+).

---

### Finding 3 — `MED` — No application-layer rate limit on `/auth/v1/token` at small-burst scale

**Severity:** MED

**Severity rubric application:**

| Rubric Q | Answer | Notes |
| - | --- | --- |
| Q1 — data class | Personal | Authentication endpoint; the credentials it gates are personal |
| Q2 — access scope | Bounded | Absence of throttle enables credential-guessing attempts; each attempt still requires a correct password to reach data |
| Q3 — session state | Unauthenticated | Pre-auth endpoint by definition |
| Q4 — exploit complexity | Multi-step, no special tools | `curl` loop |
| Q5 — mitigations | Active mitigation reduces blast radius | Cloudflare CDN sits in front of the Supabase auth endpoint and provides downstream bot-management; no specific application-layer brake observed at 10-request burst |

**Evidence (anonymized):**

Ten consecutive `POST <project>.supabase.co/auth/v1/token?grant_type=password` calls with synthetic non-existent emails and randomized passwords, issued in approximately four seconds. All ten returned:

```
HTTP 400
{
  "code": 400,
  "error_code": "invalid_credentials",
  "msg": "Invalid login credentials"
}
```

Response headers carried Cloudflare identifiers (`cf-ray`) and Supabase project headers (`sb-project-ref`, `sb-request-id`), but no `retry-after` header, no `429`, and no observable backoff in response time across the burst. The response was structurally uniform regardless of whether the email belonged to an existing account or had never been registered, which means email-enumeration via response shape is not available (a real positive — flagged as evidence-of-absence).

**Root cause:**

Supabase's default project-level rate limits on `/auth/v1/token` are loose enough that a ten-request burst passes without throttle response, and the application owner did not tighten them. Cloudflare bot management is in path and would likely engage at higher scale, but this is downstream of the application boundary and not a substitute for an application-aware rate limit (Cloudflare cannot, for instance, distinguish a sophisticated low-rate credential-stuffing campaign from legitimate traffic without app-side signal).

**Fix-pattern shape:**

Tighten the Supabase project's auth rate-limit settings (configurable in the Supabase dashboard under Authentication → Rate Limits). The structural change is to define an explicit per-IP rate threshold for the password-grant endpoint and a separate threshold for password-reset, sign-up, and OTP endpoints. Threshold values are operator-judgment; the structural finding is "no project-level rate limit configured beyond platform defaults."

**Cross-references:**

- Cross-stack pattern: [`../patterns/cross-stack-failures.md`](../patterns/cross-stack-failures.md) CS-03 (No rate limiting on signup, password-reset, or expensive endpoints).
- Severity rubric: matches the canonical "no rate limit on password-reset" MED example.

---

### Finding 4 — `LOW` — Supabase session tokens (access + refresh) and user email stored in localStorage

**Severity:** LOW

**Severity rubric application:**

| Rubric Q | Answer | Notes |
| - | --- | --- |
| Q1 — data class | Personal | The access token carries the user's email and full_name in its JWT payload; the refresh token grants session re-issuance for up to its TTL |
| Q2 — access scope | Bounded effect | Token misuse requires an XSS chain to extract from localStorage; absent that chain, the tokens are not reachable to other origins |
| Q3 — session state | Requires paired XSS | Not standalone-exploitable |
| Q4 — exploit complexity | Multi-step, novel chain | Requires a stored-XSS vector elsewhere in the app, which Step 5 of the audit confirmed absent on the surfaces tested |
| Q5 — mitigations | Defense-in-depth fails but boundary holds | React's default text-node escaping is in effect for event title rendering, so the most-likely XSS vector is closed; localStorage tokens remain in place but no extraction path was found |

**Evidence (anonymized):**

Browser DevTools → Application → Local Storage shows three keys persisted by the Supabase JS client (default `persistSession: true` behavior):

```
access_token   = "<JWT>"
                 # JWT payload (decoded) includes:
                 #   sub: <user-uuid>
                 #   aud: "authenticated"
                 #   email: <user-email>
                 #   user_metadata: { full_name: <name>, ... }
                 #   exp: <epoch>
                 #   session_id: <uuid>
refresh_token  = "<short-opaque-string>"
expires_at     = <epoch>
user           = { id, aud: "authenticated", role: "authenticated", ... }
```

No auth-bearing cookies are set; the session lives entirely in localStorage. A stored-XSS test (Step 5) injected payloads into the event title and description fields via the legitimate authenticated UI, then viewed the resulting event from a second account; the payloads rendered as literal text. No XSS vector available on the surfaces tested.

**Root cause:**

`supabase-js` defaults to persisting sessions in localStorage so that page reloads preserve login. This is intentional platform behavior, not a Bolt-specific issue. The exposure is conditional on the application having an XSS vector — which this scaffold does not, on the surfaces tested.

**Fix-pattern shape:**

Two structural alternatives, neither of which is strictly required at LOW severity:

1. Reconfigure the supabase-js client to store the session in `httpOnly` cookies via a server-side handler (Supabase Auth Helpers offers this for Next.js / SvelteKit; for a Bolt SPA, this requires introducing a backend proxy that the SPA does not currently have).
2. Accept the localStorage default as platform-intended and rely on the absence of XSS — but verify continuously, because every new user-input surface added to the app (e.g., a future "event comments" feature) is a new opportunity for the LOW to escalate to HIGH via paired XSS.

The honest operator answer for this scaffold today is option 2 with vigilance.

**Cross-references:**

- Cross-stack pattern: [`../patterns/cross-stack-failures.md`](../patterns/cross-stack-failures.md) CS-11 (Session tokens stored in localStorage instead of httpOnly cookies).
- Severity rubric: matches the canonical "session tokens in localStorage in absence of XSS" LOW example.

---

## Methodology adherence

Per [`../methodology/how-we-audit.md`](../methodology/how-we-audit.md), which steps were performed:

| Step | Performed? | Notes |
| - | --- | --- |
| 1. Intake | Yes | Twelve characterization questions answered by the operator; one contradiction (events public vs paid privacy tier) resolved before Step 2 (no privacy feature in deployed code). |
| 2. Reachability map | Yes | Driven from a HAR export of a full logged-in user flow (104 entries). Note: Chrome's HAR export omitted the `Authorization` header on supabase-js requests, leading to an initial false hypothesis ("client never attaches the user JWT") that was corrected once direct curl tests showed RLS was enabled on INSERT. This is a methodology lesson: HAR header omissions should be cross-checked against a direct request-replay before drawing conclusions about which credentials a client carries. |
| 3. Credential surface scan | Yes | Bundle (~313 KB) downloaded and grep'd for canonical patterns. Only the public anon JWT was present; no `service_role`, no Stripe / AWS / OpenAI / Anthropic key patterns. localStorage shape captured from the operator's browser. No auth-bearing cookies present. |
| 4. Data-isolation check | Yes; with caveat | Direct curl tests against the live PostgREST endpoints with anon-only headers were run against the `events` table. The destructive DELETE test was executed against a real test-account event row (one belonging to the second test identity) rather than a canary, because the canary-POST step failed (correctly, due to RLS). The DELETE result is genuine evidence for Finding 2 but the destroyed row had to be recreated by its owner. **Methodology note**: when an early-step canary creation fails for a legitimate-protection reason, the downstream destructive tests should be skipped or rerouted to a freshly created in-UI canary; running them against real rows is a documentable methodology slip. UPDATE and DELETE on `profiles` and `registrations` were NOT tested (no safe canary path), so the Finding 1 / Finding 2 shape may or may not also be present on those tables; treat as "potentially present, untested." |
| 5. Input-handling check | Yes; with caveat | Stored XSS test against event title field, viewed cross-account, rendered as literal text — confirming Finding 4 stays at LOW. Description rendering on the event-detail page was NOT observed (the canary event was deleted before the operator navigated to the detail page); a future re-run should re-test the description field on the detail view. A 10-request burst against `/auth/v1/token` characterized the auth rate-limit absence (Finding 3). Webhook handling, file-upload abuse, CORS, and signup/password-reset rate limits were NOT tested (no observed surface, or scope-out). |
| 6. Write-up | Yes | This document. |

**Scope-out exclusions:** profiles + registrations write paths; event-detail-page description XSS; password-reset rate-limit; signup rate-limit; CORS configuration; email-verification bypass; role-elevation paths (the UI exposes an "Attendee" role concept, with "Organizer" implied by event creation, but no role logic was inspected); third-party integrations (none observed in the HAR); WebContainer-preview leakage (audit was against the production `bolt.host` deployment, not the preview).

**Time spent vs. methodology baseline:** ~3 working hours against the ~6-hour baseline. The compression is appropriate for a scaffold this size — the reachability surface is small (one backend, three tables, no payment / file-upload / webhook complexity), the credential surface scan returned cleanly (no service_role finding to investigate), and the data-isolation findings landed quickly with direct curl tests once the HAR's header-omission artifact was corrected for.

---

## Consent + responsible disclosure

**Consent:** self (self-cloned audit by repo author for methodology validation). Category B per [`../methodology/how-we-anonymize.md`](../methodology/how-we-anonymize.md). No third-party operator is affected by this audit; the auditor is the row owner of every row tested.

**Anonymization standard:** the scaffold app's brand name, deployment subdomain, Supabase project reference, user UUIDs, user emails, and event-row UUIDs have been redacted to generic placeholders. Event content (titles, descriptions, geographic specifics) was test data not corresponding to any real event; nevertheless, generalized in evidence excerpts. The Bolt.new stack identifier is retained per anonymization standard (stack stays; the library is stack-specific by design).

**Anonymization gate self-check:** read the teardown as a hypothetical reader who knows the live scaffold personally. Could they recognize it? Answer: only if they were the operator themselves; the published teardown removes the project ref, the bolt.host subdomain, the brand name, the user identifiers, and the event UUIDs. Gate passed.

**Responsible disclosure window observed:**

Not applicable — self-cloned, no separate owner. No disclosure window required; the findings are usable as published evidence as soon as anonymized.

---

## What changed about the app between audit and publication

Not applicable at submission time — the scaffold is a methodology-validation artifact; the operator may or may not patch the findings. If patched, the patterns documented here remain valid as evidence of the scaffold's default state at audit date `2026-05-19`.

---

## Contributor note

Self-cloned audit by repo author for methodology validation; part of the launch-article cohort. The two CRITICAL findings on `events.UPDATE` / `events.DELETE` are the load-bearing evidence: they demonstrate that the canonical Lovable/Bolt "service_role in bundle" CRITICAL is not the only way RLS misconfiguration breaks down in AI-scaffolded apps. The partial-RLS shape — correct policies on SELECT/INSERT, permissive policies on UPDATE/DELETE — is its own pattern, and on this run it would not have surfaced via bundle inspection alone; it required Step 4's direct-curl test against the live PostgREST endpoint to confirm. That is the methodology's point: dynamic verification against the live target catches what static bundle inspection misses.

A methodology slip is also documented honestly in the adherence table — running the destructive DELETE against a real row rather than a canary was a deviation from the published plan. The finding stands on its evidence; the slip stands as a note future contributors can learn from.

---

_Submission instructions: see [`../CONTRIBUTING.md`](../CONTRIBUTING.md). Anonymization gate, consent record, methodology adherence statement are all required before merge._

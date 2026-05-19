# TD-LOVABLE-PLACEHOLDER — small self-cloned habit-tracker scaffold

> Placeholder ID; maintainer assigns final `TD-LV-<NNN>` at merge.

---

## Header

| Field | Value |
| - | --- |
| Teardown ID | `TD-LOVABLE-PLACEHOLDER-self-clone-habit` |
| Stack | Lovable + Supabase (Auth + PostgREST) |
| Audit date | 2026-05-19 |
| Auditor | Repo author (self-cloned methodology validation) |
| App type | Small habit-tracker scaffold; email-password + Google OAuth via Supabase Auth; one tier; no payments, no uploads, no LLM features |
| Audit duration | ~3 working hours (compressed scope-appropriate run) |

---

## Severity summary

| Severity | Count |
| - | --- |
| CRITICAL | 0 |
| HIGH | 0 |
| MED | 1 |
| LOW | 2 |

**Overall teardown severity:** MED.

A noteworthy positive: the canonical Lovable CRITICAL finding (Supabase `service_role` JWT in the client bundle) does **not** appear here, and RLS on every user-data table (`habits`, `habit_completions`, `profiles`) is correctly configured for read, write, delete, and insert (with `WITH CHECK` on `user_id`). This scaffold ships with the default protection the platform intends to provide. The findings below are inherited platform defaults and missing input validation — not data-layer compromise.

---

## Findings

### Finding 1 — `MED` — Email enumeration via `/auth/v1/signup` response shape

**Severity:** MED

**Severity rubric application:**

| Rubric Q | Answer | Notes |
| - | --- | --- |
| Q1 — data class | Personal | Emails are PII |
| Q2 — access scope | Bounded | Enumeration only; does not access account data |
| Q3 — session state | Unauthenticated | Anyone can POST to `/auth/v1/signup` with just the public anon key |
| Q4 — exploit complexity | Multi-step, no special tools | One request per email candidate; trivially scriptable |
| Q5 — mitigations | Active mitigation reduces blast radius | The platform returns a synthetic-looking 200 to obfuscate, but the obfuscation is partial — three fields leak |

**Evidence (anonymized):**

Two requests with identical method, headers, and password strength, varying only the email value:

Request A — `POST <project>.supabase.co/auth/v1/signup` with body `{"email":"<existing-user-email>","password":"<strong>"}`:

```
HTTP/2 200
{
  "id":"<new-uuid>",          # new UUID, not the existing user's
  "role":"",                  # EMPTY
  "user_metadata":{},         # EMPTY
  "identities":[],            # EMPTY
  "confirmation_sent_at":"<timestamp>",
  ...
}
```

Request B — same request, with `<never-registered-email>`:

```
HTTP/2 200
{
  "id":"<new-uuid>",
  "role":"authenticated",     # populated
  "user_metadata":{"email":"...","email_verified":false,"sub":"<uuid>"},
  "identities":[{"identity_id":"...","provider":"email",...}],
  "confirmation_sent_at":"<timestamp>",
  ...
}
```

An attacker comparing the two responses can sort an email list into "already-registered" vs "new" by checking whether `identities` is empty, whether `role` is `""`, and whether `user_metadata` is `{}`.

The companion `/auth/v1/recover` endpoint does NOT leak — both existing and non-existent emails return identical `{}` + 200.

**Root cause:**

The Supabase GoTrue signup endpoint attempts to obfuscate "user already exists" by returning a synthetic 200 with a fresh UUID instead of an error, but the synthesis is incomplete — `role`, `user_metadata`, and `identities` are computed differently for the "already-exists" path than for the "new-user" path. The intent is right; the execution is partial. The app inherits this default behavior unchanged.

A secondary effect of the obfuscation: it sends a "confirm your account" email to the existing address whenever someone attempts signup with it, which is mildly user-hostile (legitimate user receives a confusing email triggered by a third party) but is not itself a security finding.

**Fix-pattern shape:**

Two structural options; the app picks the trade-off:

1. **Accept the inherited platform behavior and document the trade-off.** Suitable when the user-existence question is low-stakes (most consumer SaaS); the enumeration is detectable but only useful for an attacker already targeting a specific user list, and the partial obfuscation discourages casual scrapes.
2. **Proxy the signup through an edge function** that returns byte-identical responses regardless of email existence (and ideally adds a CAPTCHA or proof-of-work gate at the same time). Suitable when user-existence is sensitive (e.g., the app's user base is socially identifying — a recovery community, a regulated profession, a closed B2B tool).

The current scaffold does neither; choosing one is an architectural decision, not a code patch.

**Cross-references:**

- Severity rubric: [`../methodology/severity-rubric.md`](../methodology/severity-rubric.md) — canonical MED example is "no rate limiting on password-reset endpoint of a free-tier signup app"; this is the same shape applied to signup-conflict instead of password-reset

---

### Finding 2 — `LOW` — No server-side length or format validation on user-input fields

**Severity:** LOW

**Severity rubric application:**

| Rubric Q | Answer | Notes |
| - | --- | --- |
| Q1 — data class | Personal | User's own data only |
| Q2 — access scope | Bounded | Self-only impact; RLS isolation means the user can only break their own dashboard |
| Q3 — session state | Authenticated, any role | Standard user session |
| Q4 — exploit complexity | Single step | One POST with large payload |
| Q5 — mitigations | None | No length check at DB, app server, or client; rendering has no overflow protection on emoji slot |

**Evidence (anonymized):**

Two write probes against `/rest/v1/habits` as an authenticated user:

```
POST <project>.supabase.co/rest/v1/habits
Authorization: Bearer <user-jwt>
Content-Type: application/json
Body: {"user_id":"<self>","name":"<10240-char-A-string>","emoji":"📏","color":"violet"}

HTTP/2 201 Created   # row persisted with full 10KB name
```

```
POST <project>.supabase.co/rest/v1/habits
Authorization: Bearer <user-jwt>
Content-Type: application/json
Body: {"user_id":"<self>","name":"emoji-test","emoji":"<script>alert('x')</script>","color":"violet"}

HTTP/2 201 Created   # 32-char string accepted into a field intended for one emoji char
```

Visual result in the rendered dashboard: the long name shows with CSS ellipsis truncation but still pushes container boundaries; the multi-character "emoji" overflows its fixed-size emoji circle and overlaps the row's day-grid labels. React's default `{value}` interpolation escapes HTML safely (no XSS), but the size/length is unconstrained at both layers.

**Root cause:**

The Lovable scaffold provisions Supabase tables with TEXT columns and no CHECK constraints, and the generated React components do not impose `maxLength` on the input controls or overflow-clipping CSS on the rendered output. The result is "any string goes" at every layer: DB accepts it, REST API accepts it, render renders it. For high-trust single-user contexts this is fine; for multi-tenant or shared-render contexts (e.g., if a future iteration adds a "shared habit" or "leaderboard" feature) it becomes a vector for visual disruption of other users' views.

**Fix-pattern shape:**

Add the constraint at the most-defensible layer (the database). For the `name` field: a `CHECK (char_length(name) BETWEEN 1 AND 80)` constraint. For the `emoji` field: either a `CHECK` that the value is a single grapheme cluster, or refactor the data model so `emoji` references a fixed enum or a user-pickable list rather than a free-text field. Defense-in-depth: add `maxLength` props on the React inputs and `text-overflow: ellipsis; overflow: hidden` on the rendering surface (the screenshot suggests partial ellipsis CSS is already present on the name field; consistent application across both fields would close the gap).

**Cross-references:**

- Severity rubric: [`../methodology/severity-rubric.md`](../methodology/severity-rubric.md) — LOW because exploit is self-only and bounded

---

### Finding 3 — `LOW` — Session tokens in browser localStorage

**Severity:** LOW

**Severity rubric application:**

| Rubric Q | Answer | Notes |
| - | --- | --- |
| Q1 — data class | Personal | The session token itself, granting access to the holder's data |
| Q2 — access scope | Bounded effect | Only exploitable via paired XSS — none confirmed in this audit (Step 5 XSS probes were escaped by React's default interpolation) |
| Q3 — session state | Requires paired XSS to extract | No direct path |
| Q4 — exploit complexity | Multi-step requiring novel chain | Would require discovering an XSS sink first |
| Q5 — mitigations | Defense-in-depth fails but boundary holds | React's escaping is the present boundary; no XSS surface found, so the localStorage placement is not currently exploitable |

**Evidence (anonymized):**

Browser DevTools → Console → `JSON.stringify(localStorage)` while logged in returns a key named `sb-<project>-auth-token` containing the user's `access_token` (Supabase user JWT, ES256-signed, 1 hour expiry), `refresh_token`, and full user profile including email, identities, and timestamps. All values are plaintext-readable by any JavaScript executing on the origin.

**Root cause:**

The Supabase JS client (v2.x) stores session state in localStorage by default. This is the documented default behavior and is what every Lovable scaffold inherits unless explicitly reconfigured. The trade-off is: easier SPA wiring vs httpOnly-cookie protection against script-side theft.

**Fix-pattern shape:**

If the app evolves to include any HTML-rendering surface that could host an XSS sink (a markdown-rendered note field, a `dangerouslySetInnerHTML` block, an admin tools page), upgrade to Supabase's SSR variant that writes httpOnly cookies, or interpose a backend-for-frontend that holds the token server-side. Until then, the recommendation is to treat React's default escaping as the load-bearing control and audit any future code addition that bypasses it.

Maps to the rubric's canonical LOW example almost exactly: "Session tokens in localStorage on an app with no XSS surface confirmed in the audit."

**Cross-references:**

- Severity rubric: [`../methodology/severity-rubric.md`](../methodology/severity-rubric.md) — verbatim match for the LOW canonical example

---

## What WAS tested and did NOT surface a finding

This section is unusual — most teardowns only list findings — but for a methodology-validation audit it matters to enumerate the tests that returned negative results, because "we tested for it and didn't find it" is more useful than the absence of a mention.

| Probe | Result |
| - | --- |
| `service_role` JWT in JS bundle | Not present (grep across 8 bundle files) |
| Third-party API keys in JS bundle (Stripe / OpenAI / Anthropic / AWS) | Not present |
| Anonymous (no user JWT) read of `habits` | RLS filtered to `[]` |
| Anonymous read of `habit_completions` | RLS filtered to `[]` |
| Anonymous read of `profiles` | RLS filtered to `[]` |
| Anonymous INSERT into `habits` | 401, "violates row-level security policy" |
| Anonymous DELETE on a specific habit row | 204 returned but row verified still present (RLS hid the row from the delete scope) |
| User B reading user A's habits (by ID, by user_id filter, no filter) | `[]` in all three cases |
| User B reading user A's check-ins by `habit_id` | `[]` |
| User B UPDATE user A's habit | 0 rows affected; verify-read confirms unchanged |
| User B DELETE user A's habit | 0 rows affected; verify-read confirms still present |
| User B INSERT habit with `user_id` set to user A's UUID (identity spoofing) | 403, "violates row-level security policy" — `WITH CHECK` clause enforced |
| User B INSERT habit_completion targeting user A's habit_id | 403, "violates row-level security policy" |
| PostgREST root schema introspection (`/rest/v1/` with `Accept: application/openapi+json`) | 401, requires `service_role` |
| `/auth/v1/admin/users` as a regular user | 403, "not_admin" |
| `/auth/v1/user` as user B | Returns B's own profile only |
| Table-name enumeration probes (`users`, `settings`, `accounts`, `admins`, `user_profiles`) | 404 each |
| XSS via `habits.name` rendering | React escaped; literal text rendered, no execution |
| XSS via `habits.emoji` rendering | React escaped; literal text rendered, no execution |
| `javascript:` URL injected into `habits.color` | Stored but not used as `href` or executable context by current UI |
| Password-reset email enumeration (`/auth/v1/recover` existing vs non-existing email) | Identical `{}` + 200 responses |
| Login rate-limit probe (5 wrong-password attempts in a single burst) | All 5 returned standard 400 invalid-credentials; no throttling at this volume. Deeper threshold characterization was out of scope per engagement rules |
| Weak-password rejection on signup | Active — HIBP-based check returns 422 with `weak_password: pwned` |

---

## Methodology adherence

Per [`../methodology/how-we-audit.md`](../methodology/how-we-audit.md):

| Step | Performed? | Notes |
| - | --- | --- |
| 1. Intake | Yes | Operator-self characterization; scope locked to in-app surfaces, infrastructure attacks excluded |
| 2. Reachability map | Yes | HAR capture + bundle URL fetch; 10 distinct route+method combinations identified |
| 3. Credential surface scan | Yes | 8 JS bundles grep'd for service_role / AWS / Stripe / OpenAI / Anthropic / JWT patterns; localStorage inspected; only finding was the documented Supabase anon JWT (expected, not a finding on its own) |
| 4. Data-isolation check | Yes | Two test identities used (user A + user B); cross-tenant read/write/delete/insert tested on `habits`, `habit_completions`, `profiles` |
| 5. Input-handling check | Yes | XSS payloads on `name`, `emoji`, `color`; oversized field test; auth rate-limit single-burst probe; signup-enumeration probe; password-reset enumeration probe |
| 6. Write-up | Yes | This document |

**Scope-out exclusions:**

- Deeper rate-limit threshold characterization (would require sustained traffic against the live target, beyond the single-burst probe authorized in Step 5)
- Server hardening / infrastructure posture (out of methodology scope per `methodology/how-we-audit.md` §"What this methodology does NOT cover")
- Google OAuth IdP posture (third-party integration; out of methodology scope)

**Time spent vs. methodology baseline:** ~3 hours actual against a 3-hour pre-agreed time-box (compressed from the 6-hour small-SaaS baseline due to the absence of payments, file uploads, LLM features, and admin role). No deviation from baseline.

---

## Consent + responsible disclosure

**Consent:** self (self-cloned audit by repo author for methodology validation). Category B per [`../methodology/how-we-anonymize.md`](../methodology/how-we-anonymize.md) — auditor IS owner.

**Anonymization standard:** Read by submitter as a hypothetical reader who knows the live app. The target is a generic Lovable scaffold with no distinguishing customer-facing characteristics; identifiers (project ref, table IDs, user UUIDs, emails, URLs) genericized per [`../methodology/how-we-anonymize.md`](../methodology/how-we-anonymize.md).

**Responsible disclosure window observed:**

| Field | Value |
| - | --- |
| Disclosure to owner date | Not applicable — self-cloned, no separate owner |
| Agreed window length | N/A |
| Patch confirmed date | N/A |
| Days from disclosure to publication | N/A |

---

## What changed about the app between audit and publication

Nothing structurally. The audit left four test rows in user B's account (the XSS payload rows, the oversized-name row) and one orphaned signup attempt for a generated `@example.test` address; the operator can clean those via the Supabase dashboard at any time. They do not affect any other user.

---

## Contributor note

Self-cloned audit by repo author for methodology validation; part of the launch-article cohort. Treated as a methodology smoke test rather than a representative-of-real-Lovable-apps sample — the scaffold here ships with RLS correctly configured because the operator did not customize it, which is the lucky default. Other self-cloned audits in this cohort may not replicate the same positive baseline; the methodology should be applied independently to each.

The two genuinely useful methodology observations from this run, for future contributors:

1. Chrome's HAR export can silently strip the `Authorization` header from captured requests, leading to false-positive readings of "no Bearer JWT was sent." The fix is to confirm cross-tenant behavior with direct API probes using the captured anon key + a freshly-pulled user JWT from localStorage, rather than inferring it from the HAR alone.
2. The methodology's distinction between "anon can't read" (which this scaffold passes) and "authenticated-as-other-user can't read" (which this scaffold also passes) is the load-bearing one for Step 4 — passing the first does not imply passing the second. Both probes must be run independently against every user-data table.

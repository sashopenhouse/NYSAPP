# Blocking validation: can a stage change reach Supabase within minutes?

**Answer: Yes — via Connecteam's Forms webhook, not the Jobs API.**

## What Connecteam actually exposes

Connecteam (the real upstream system — see correction in [BUILD_PLAN.md](../BUILD_PLAN.md); the original doc's "MarketSharp" references were wrong) has two relevant data shapes:

- **Jobs API** (`GET /jobs/v1/jobs`) — has `customFields`, but is pull-only. No job-level webhook exists. Polling is the only option here, so a Job custom field alone cannot back a live tracker.
- **Forms API** — supports a **Form Submission webhook** with three real-time events: `form_submission`, `form_submission_edited`, `manager_field_updated`. Forms support a `status` manager field type. Delivery is event-driven, not polling.
- **Tasks API** — also has a real-time webhook (`published`, `completed` events), but tasks are per-assignment, not per-project, so they're a weaker fit than forms for a 7-stage pipeline.

## Design implication

Model each project stage transition (measure, order placed, permit, install scheduled, install, punch list, final) as a **status field update on a per-job Connecteam form**, filled by office/crew staff. That triggers `manager_field_updated` (or `form_submission` for the initial fill) within Connecteam's normal webhook latency — real-time, not nightly batch.

This means:

- **Phase 1 ships as a live tracker**, per the build plan's "Yes" branch. No rescoping to coarse/photo-only status.
- The sync service is a **webhook receiver**, not a poller. It listens for Connecteam form events, maps `submittingUserId` + job linkage to a `contacts`/`projects` row (via a Connecteam job ID or job code stored against the project at deal-close time), and appends a `project_events` row.
- Job custom fields (via the Jobs API) remain useful for slower-moving attributes (product lines, crew assignment, install window) that don't need real-time push — synced on a periodic pull instead.

## Live infrastructure (2026-09-11)

- Supabase project: `NYSAPP`, ref `gbwhdieifcfrgzazpgas`, org "Sash Open House", region us-east-1.
- URL: `https://gbwhdieifcfrgzazpgas.supabase.co`
- Migration `0001_init.sql` applied — all 10 tables live with RLS enabled.
- Edge function `connecteam-webhook` deployed (JWT verification disabled — this endpoint is called by Connecteam, not a Supabase client, and authenticates via a shared-secret header instead). Endpoint: `https://gbwhdieifcfrgzazpgas.supabase.co/functions/v1/connecteam-webhook`.
- **TODO before pointing real Connecteam webhooks here:** set the `CONNECTEAM_WEBHOOK_SECRET` project secret. Until set, the function's signature check is skipped entirely (see `index.ts`), so it is currently open — acceptable only because nothing external points at it yet.
- **Auth switched from phone to email (2026-09-11):** phone OTP was blocked on a real paid Twilio account (trial accounts reject Supabase's default OTP SMS template — confirmed via `auth_logs`: `422 Error sending confirmation OTP to provider: Invalid template name. Trial accounts can only use predefined SMS templates`). Switching Supabase's provider to Twilio Verify was tried but not completed before the decision was made to drop SMS for now. **Auth is now email OTP only** — no third-party SMS provider needed. `contacts.email` is now `NOT NULL` + unique per tenant (migration `0006_contacts_email_required.sql`), and the custom access token hook matches on email instead of phone (migration `0005_auth_hook_email.sql`, superseding the phone-matching version in `0002_auth_hook.sql`). Phone can come back later as an additional sign-in path once SMS is sorted — it wasn't removed from the schema, just from the auth flow.
- **Auth Hook approach abandoned (2026-09-12):** the custom access token hook (`0002`/`0005_auth_hook_email.sql`) required a manual, dashboard-only toggle (Authentication → Hooks → Custom Access Token) with no way to verify from outside the dashboard whether it was actually active. It wasn't — the app stayed stuck in Prospect mode for a real, matching contact row already in the database, with no error anywhere to point at why. Replaced with `public.resolve_app_mode()` and `public.current_contact_id()` (`0007`–`0009` migrations), both plain `SECURITY DEFINER` SQL functions that read `auth.jwt() ->> 'email'` directly — this is always populated on an authenticated session regardless of any hook config, so there's no toggle left to silently be off. `AppModeResolver.swift` now calls the `resolve_app_mode` RPC instead of decoding a custom JWT claim, and every RLS policy that referenced `auth.jwt() ->> 'contact_id'` was rewritten to call `current_contact_id()` instead. The `custom_access_token_hook` function itself was left in place (harmless, unused) rather than dropped — no functional reason to remove it.
- Email auth itself needs no separate provider setup — Supabase sends confirmation/OTP emails via its own built-in mailer by default.
- **Connecteam API key:** the user has a Connecteam API key (for calling Connecteam's API — e.g. registering the webhook, or pulling Jobs custom fields on a polling cadence). Set it in the Supabase dashboard (Project Settings → Edge Functions → Secrets) as `CONNECTEAM_API_KEY`, never in the repo or chat. Not yet consumed by any function — `connecteam-webhook` only receives inbound webhooks and doesn't call back out to Connecteam yet. A future function (webhook self-registration, or the Jobs custom-field poller for slower-moving attributes) will read it via `Deno.env.get("CONNECTEAM_API_KEY")`.

## Open items to confirm with the Connecteam account / NYS ops before Phase 1 build-out

1. Exact webhook registration flow (`Setting up webhook via API` doc) and whether NYS's Connecteam plan tier includes API + webhooks (API access is Expert/Enterprise-plan gated).
2. Which existing NYS Connecteam form (if any) already tracks job stage, or whether a new form needs to be created for this pipeline.
3. How a Connecteam job/form submission is linked back to a specific homeowner (job code convention, or a custom field carrying the contact's phone/MarketSharp-equivalent ID).

## Sources

- https://developer.connecteam.com/docs/get-jobs
- https://developer.connecteam.com/docs/forms-webhook
- https://developer.connecteam.com/docs/authentication-1
- https://help.connecteam.com/en/articles/8259451-jobs-api-application-programming-interface
- https://help.connecteam.com/en/articles/9010821-webhook-documentation

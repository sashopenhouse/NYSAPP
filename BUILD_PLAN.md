# New York Sash Customer App — Build Plan

Working doc. Drop at repo root so Claude Code has context from the first prompt.

## Decisions locked

| Decision | Answer |
|---|---|
| Audience | Customers plus prospects |
| Product | Standalone, NYS-branded |
| Platform | Native SwiftUI, iOS only |
| Backend | Supabase, tenant-aware schema, single-tenant UI |
| Upstream | ConnectTeam, REST API with key (not MarketSharp — see note below) |

> **Note (2026-09-11):** This doc originally named MarketSharp as the upstream CRM. Confirmed MarketSharp API access will never be available. ConnectTeam — used the same way in prior portfolio apps, REST API with a key — is the actual upstream system for both reads (stage/status sync) and writes (new inquiries from the visualizer). Every "MarketSharp" reference below should be read as ConnectTeam.

## Open flag

iOS only cuts a large share of a Central New York homeowner base that skews Android. Acceptable for customers under contract (NYS hands them the app at the sale). Not acceptable as the only prospect channel. Resolution: the prospect leg is visualizer-led, everything else for prospects stays on the NYS website.

## Blocking validation

Can a stage change in ConnectTeam reach Supabase within minutes?

- Yes: timeline ships as a live tracker (Phase 1 as scoped).
- Nightly batch or manual only: rescope Phase 1 to documents and photos, show stage as a coarse status, no live tracker.

Do this before designing a screen.

## Architecture

One entry point, three states resolved by phone lookup after magic-link auth. State is derived from the Supabase mirror, never chosen by the user.

- No matching record: **Prospect mode** (visualizer, catalog, request estimate)
- Active job: **Project mode** (timeline, photos, documents, messages)
- Completed job: **Home file mode** (warranties, care guides, service, referral)

Prospect to customer transition fires a push notification on next sync.

## Scaffold reuse

Carries over from the portfolio apps:

- Shared signing certificate
- XcodeGen project generation
- Codemagic workflow conventions
- Tag-triggered pipeline: `beta-*` to TestFlight, `release-*` to App Store

Does not carry over:

- Design system. NYS brand, not Studio Florez.
- Solo shipping rhythm. Real backend dependency, real client stakeholder.

No `.netrc` secure file needed (that was a Huella/Mapbox CocoaPods requirement, Flutter only).

**Scaffold alignment (2026-09-11):** compared directly against the Vitaminly app's actual working scaffold and matched it — same Apple Developer Team ID (`64X5Z6TNJQ`), same `agvtool`-driven versioning (`VERSIONING_SYSTEM: apple-generic` at project scope), same manual Release-config code signing paired with a scripted `fetch-signing-files --create` Codemagic flow (not the declarative `ios_signing:` group, which Vitaminly's own comments note fails on a first-ever App ID), same `.gitignore` signing-material patterns, same `.swiftlint.yml` house rules. See `ios/NYSApp/project.yml` and `codemagic.yaml`.

## Data model

Core tables in Supabase:

- `contacts` — phone, email, name, connectteam_id, tenant_id
- `projects` — contact_id, stage, product_lines, sold_at, install_window, crew_ids
- `project_events` — project_id, stage, occurred_at, source (renders the timeline)
- `media` — project_id, url, caption, source, `approved_for_customer`
- `documents`, `messages`, `warranties`, `referrals`, `products`

`tenant_id` on every table from day one. Costs nothing now, saves a migration if FRONTDESK ever adopts this surface.

### Media approval is in scope

The Slack and ConnectTeam photo pipeline is an internal crew feed: dumpsters, rot behind old siding, mistakes, half-finished walls. Office staff must promote a photo before a homeowner sees it. Small internal web view, build it in Phase 1, not after the pilot.

## Phases

**Phase 1 — Auth and project mode**
- SMS magic link (Textla or Twilio), no passwords, no account creation
- Timeline: measure, order placed, permit, install scheduled, install, punch list, final
- Install day card: crew names, arrival window
- Approved photo feed
- Documents: contract, permit, product spec sheets
- Single message thread routing to the office
- Payment schedule, view only
- Internal media approval view

**Phase 2 — Visualizer (prospect leg)**
- ARKit placement of window and siding styles from the product catalog
- Capture, save, share
- Request Estimate CTA writes back to ConnectTeam as a new inquiry
- This is the App Store listing headline

**Phase 3 — Home file**
- Warranty registration with serial capture
- Care and cleaning guides by product type
- Service request with photo attachment
- Seasonal reminders

**Phase 4 — Referral and review**
- Tracked referral code
- Review prompt fired by the final walkthrough event, not a calendar date

## Retention

Nobody opens this daily. Notifications are the product. Each needs a defined upstream trigger in the sync layer, which is why the sync layer gets prototyped first.

Triggers: stage change, install morning reminder, crew en route, document ready, warranty milestone, seasonal maintenance.

## First session in VS Code

1. Prototype the ConnectTeam to Supabase sync and answer the blocking question above
2. Scaffold the Xcode project (XcodeGen spec, Codemagic workflow, signing)
3. Supabase schema and RLS policies
4. Magic-link auth and the three-state router
5. Timeline screen

Do not start at step 5.

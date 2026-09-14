-- MarketSharp as a second upstream alongside the Connecteam webhook.
--
-- MarketSharp has no outbound webhooks (verified against their public
-- Swagger specs at restapi.marketsharpm.com — 426 operations across both API
-- versions, zero event-subscription endpoints). So this upstream is a poller,
-- not a receiver, and it needs three things the push path never did:
-- idempotency, a durable cursor, and dedupe against the other source.

-- ---------------------------------------------------------------------
-- 1. Idempotency.
--
-- project_events had no uniqueness constraint of any kind, so re-reading the
-- same record inserted a second identical stage row and the timeline would
-- render "Install" twice. That was survivable with a webhook firing once per
-- change; it is not survivable with a poller that re-reads overlapping
-- windows by design.
--
-- Worse, MarketSharp's inquiries/filter returns the CURRENT datetime as
-- lastModifiedDateTime for records that have no modification date, so those
-- records look freshly-modified on every single poll, forever. Without this
-- constraint that is an unbounded duplicate-row generator.
--
-- external_id is the upstream record identity (MarketSharp inquiry or
-- appointment id). Partial index because the Connecteam rows have no such id
-- and must not collide with each other on NULL.
-- ---------------------------------------------------------------------
alter table project_events add column if not exists external_id text;

create unique index if not exists project_events_source_external_stage_idx
  on project_events(source, external_id, stage)
  where external_id is not null;

-- ---------------------------------------------------------------------
-- 2. Cross-source dedupe.
--
-- Both upstreams describe the same real-world job, so the same stage can
-- arrive twice from different systems. The timeline should show one entry
-- per stage per project regardless of which system reported it.
--
-- Deliberately NOT a unique constraint on (project_id, stage): a stage
-- legitimately recurring (a job returning to punch_list after a callback) is
-- real and should be visible. This is a guard against simultaneous
-- double-reporting, not against genuine repetition, so it is scoped to a
-- time window and applied in the poller rather than the schema.
-- ---------------------------------------------------------------------
create index if not exists project_events_dedupe_idx
  on project_events(project_id, stage, occurred_at desc);

-- ---------------------------------------------------------------------
-- 3. The polling cursor.
--
-- MarketSharp's lastModifiedDateTime is in COMPANY-LOCAL time, not UTC.
-- A naive cursor silently skips or double-reads records around a DST
-- transition, so the window is stored with its timezone recorded explicitly
-- and the poller converts deliberately.
--
-- One row per (tenant, upstream) so a second upstream can reuse this table.
-- ---------------------------------------------------------------------
create table if not exists sync_cursors (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id),
  source text not null,
  -- The high-water mark actually processed, stored as UTC.
  last_synced_at timestamptz,
  -- The IANA zone the upstream reports its timestamps in, so the conversion
  -- is explicit and auditable rather than assumed. MarketSharp reports in
  -- the company's configured timezone.
  upstream_timezone text not null default 'America/New_York',
  last_run_at timestamptz,
  last_error text,
  consecutive_failures integer not null default 0,
  created_at timestamptz not null default now(),
  unique (tenant_id, source)
);

alter table sync_cursors enable row level security;

-- Service-role only: this is sync plumbing, not customer or staff data.
-- RLS on with no policy means no client token can read it.

-- Contacts need a MarketSharp identity alongside the Connecteam one. The
-- existing connectteam_job_id is left untouched so both paths keep working.
alter table contacts add column if not exists marketsharp_contact_id text;
alter table contacts add column if not exists marketsharp_inquiry_id text;

create index if not exists contacts_marketsharp_contact_idx
  on contacts(marketsharp_contact_id) where marketsharp_contact_id is not null;
create index if not exists contacts_marketsharp_inquiry_idx
  on contacts(marketsharp_inquiry_id) where marketsharp_inquiry_id is not null;

-- Retention surface: offers the office can publish to a targeted audience,
-- and a review ask fired by the final walkthrough event.
-- BUILD_PLAN.md "Retention" — nobody opens this app daily, so the reasons
-- to come back are the product.

create table if not exists offers (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id),
  title text not null,
  body text,
  -- Which of the three app modes this offer is for. An offer may target
  -- several, so it's an array, not a single value: a seasonal promo can
  -- reasonably go to both prospects and finished jobs while skipping
  -- customers whose install is mid-flight.
  audiences text[] not null default '{}'
    check (audiences <@ array['prospect','project','home_file']::text[]),
  cta_label text,
  cta_url text,
  image_url text,
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  published boolean not null default false,
  sequence integer not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists offers_live_idx on offers(tenant_id, published, starts_at, ends_at);

alter table offers enable row level security;

-- Offers are marketing copy, not per-customer data: every signed-in user of
-- the tenant may read the live ones. Audience filtering is a client concern
-- (the app knows its own mode); RLS only enforces published + in-window, so
-- an unpublished draft or an expired promo can never leak.
create policy offers_live on offers
  for select to authenticated
  using (
    published = true
    and starts_at <= now()
    and (ends_at is null or ends_at > now())
  );

-- Review asks. One row per project, created when it reaches 'final'.
-- Tracked so the app can stop asking once handled, and so the office can
-- see who was asked without guessing from a calendar.
create table if not exists review_requests (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id),
  project_id uuid not null references projects(id),
  requested_at timestamptz not null default now(),
  -- 'opened' means we sent them to Google. We deliberately cannot record
  -- whether they actually left a review, or what it said: Google exposes no
  -- such callback, and gating on rating would violate Google's review
  -- policies and the FTC's rules on suppressed reviews. This column tracks
  -- our own prompt, never the customer's opinion.
  opened_at timestamptz,
  dismissed_at timestamptz,
  created_at timestamptz not null default now(),
  unique (project_id)
);

create index if not exists review_requests_project_idx on review_requests(project_id);

alter table review_requests enable row level security;

create policy review_requests_self on review_requests
  for select using (project_id in (select id from projects where contact_id = public.current_contact_id()));

-- The customer's own interaction with the prompt is the one thing they write:
-- opened (tapped through to Google) or dismissed (not now). Scoped to their
-- own project, and there is no insert policy — the row is created by the
-- trigger below, not the client.
create policy review_requests_update_self on review_requests
  for update to authenticated
  using (project_id in (select id from projects where contact_id = public.current_contact_id()))
  with check (project_id in (select id from projects where contact_id = public.current_contact_id()));

-- Fire the ask on the final walkthrough event, not a calendar date
-- (BUILD_PLAN.md Phase 4). project_events is append-only from the
-- connecteam-webhook, so the insert of a 'final' row is the trigger point.
create or replace function public.create_review_request_on_final()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.stage = 'final' then
    insert into review_requests (tenant_id, project_id)
    values (new.tenant_id, new.project_id)
    on conflict (project_id) do nothing;
  end if;
  return new;
end;
$$;

drop trigger if exists project_events_review_request on project_events;
create trigger project_events_review_request
  after insert on project_events
  for each row execute function public.create_review_request_on_final();

alter publication supabase_realtime add table public.offers;

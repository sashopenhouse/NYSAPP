-- Staff identity and role-aware policies, so office staff can work the
-- queues NYSAPP depends on (media approval, offers, agent handoffs) from an
-- internal console instead of someone running SQL by hand.
--
-- Until now every policy in this database keyed off current_contact_id() —
-- a homeowner's email matching a contacts row. Staff had no representation
-- at all, which is why approving a photo meant opening the SQL editor.

create table if not exists staff (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id),
  -- Matched on email like contacts, for the same reason: it is always
  -- present on an authenticated session with no dashboard-only auth hook
  -- to silently be off. See 0009's note.
  email text not null,
  name text,
  -- 'staff'  — office: work the queues, approve media, answer threads
  -- 'admin'  — additionally manage offers and other staff
  role text not null default 'staff' check (role in ('staff', 'admin')),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (tenant_id, email)
);

create index if not exists staff_email_idx on staff(lower(email)) where active;

alter table staff enable row level security;

-- Mirrors current_contact_id(). SECURITY DEFINER so it can read the staff
-- table while the caller's own policies are still being evaluated, which is
-- the same chicken-and-egg problem 0007 solved for contacts.
create or replace function public.current_staff_id()
returns uuid
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select id from staff
  where lower(email) = lower(auth.jwt() ->> 'email')
    and active
  limit 1;
$$;

create or replace function public.is_staff()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from staff
    where lower(email) = lower(auth.jwt() ->> 'email')
      and active
  );
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from staff
    where lower(email) = lower(auth.jwt() ->> 'email')
      and active
      and role = 'admin'
  );
$$;

grant execute on function public.current_staff_id to authenticated;
grant execute on function public.is_staff to authenticated;
grant execute on function public.is_admin to authenticated;
revoke execute on function public.current_staff_id from anon, public;
revoke execute on function public.is_staff from anon, public;
revoke execute on function public.is_admin from anon, public;

-- Staff can see the roster; only admins change it. No self-service insert:
-- a staff row is how someone gets access, so creating one is an admin act.
create policy staff_read on staff
  for select to authenticated
  using (public.is_staff());

create policy staff_admin_write on staff
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- ---------------------------------------------------------------------
-- Staff access to the customer-facing tables.
--
-- Added as SEPARATE policies rather than by editing the customer ones.
-- Postgres ORs multiple permissive policies together, so the existing
-- customer policies keep their exact meaning and a bug in a staff policy
-- can never widen what a homeowner sees.
-- ---------------------------------------------------------------------

create policy projects_staff on projects
  for select to authenticated using (public.is_staff());

create policy contacts_staff on contacts
  for select to authenticated using (public.is_staff());

create policy project_events_staff on project_events
  for select to authenticated using (public.is_staff());

create policy documents_staff on documents
  for select to authenticated using (public.is_staff());

create policy payments_staff on payments
  for select to authenticated using (public.is_staff());

-- Media approval: the whole point of the console. Staff see every photo
-- including unapproved crew shots (the customer policy still restricts
-- homeowners to approved_for_customer = true), and may flip the flag.
create policy media_staff_read on media
  for select to authenticated using (public.is_staff());

create policy media_staff_update on media
  for update to authenticated
  using (public.is_staff())
  with check (public.is_staff());

-- Staff reply to threads. sender must be 'office' — the mirror of the
-- customer policy pinning 'customer', so staff cannot post as the homeowner.
create policy messages_staff_read on messages
  for select to authenticated using (public.is_staff());

create policy messages_staff_insert on messages
  for insert to authenticated
  with check (public.is_staff() and sender = 'office');

-- The handoff queue stops being service-role-only: working it is a console
-- job. Still invisible to customers, whose token fails is_staff().
create policy agent_handoffs_staff on agent_handoffs
  for all to authenticated
  using (public.is_staff())
  with check (public.is_staff());

-- Offers are marketing: admins manage them. The customer-facing offers_live
-- policy is unchanged, so homeowners still only see published, in-window
-- rows while an admin can see and edit drafts.
create policy offers_admin on offers
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy review_requests_staff on review_requests
  for select to authenticated using (public.is_staff());

-- Drop the relic of the abandoned custom access token hook (0002/0005).
-- It granted a blanket `using (true)` read on contacts to supabase_auth_admin
-- for claim population; that approach was replaced in 0007-0009 and the
-- policy has been dead weight since.
drop policy if exists "Allow auth admin to read contacts for token claims" on contacts;

-- Replace JWT-custom-claim-based RLS with email-lookup-based RLS, mirroring
-- resolve_app_mode (0007). The custom access token hook that was meant to
-- supply auth.jwt()->>'contact_id' depends on a dashboard-only toggle
-- (Authentication -> Hooks -> Custom Access Token) that's easy to leave
-- off with no error surfaced anywhere — which is exactly what happened:
-- the app silently stayed in Prospect mode with a real, matching contact
-- row sitting right there in the database. A plain SQL function keyed on
-- auth.jwt()->>'email' needs no such toggle; email is always present on an
-- authenticated session regardless of hook config.
create or replace function public.current_contact_id()
returns uuid
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select id from contacts where lower(email) = lower(auth.jwt() ->> 'email') limit 1;
$$;

grant execute on function public.current_contact_id to authenticated;
revoke execute on function public.current_contact_id from anon, public;

drop policy if exists contacts_self on contacts;
drop policy if exists projects_self on projects;
drop policy if exists project_events_self on project_events;
drop policy if exists media_self on media;
drop policy if exists documents_self on documents;
drop policy if exists messages_self on messages;
drop policy if exists warranties_self on warranties;
drop policy if exists referrals_self on referrals;

create policy contacts_self on contacts
  for select using (id = public.current_contact_id());

create policy projects_self on projects
  for select using (contact_id = public.current_contact_id());

create policy project_events_self on project_events
  for select using (project_id in (select id from projects where contact_id = public.current_contact_id()));

create policy media_self on media
  for select using (
    approved_for_customer = true
    and project_id in (select id from projects where contact_id = public.current_contact_id())
  );

create policy documents_self on documents
  for select using (project_id in (select id from projects where contact_id = public.current_contact_id()));

create policy messages_self on messages
  for select using (project_id in (select id from projects where contact_id = public.current_contact_id()));

create policy warranties_self on warranties
  for select using (project_id in (select id from projects where contact_id = public.current_contact_id()));

create policy referrals_self on referrals
  for select using (contact_id = public.current_contact_id());

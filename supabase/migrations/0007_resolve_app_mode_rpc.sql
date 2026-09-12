-- Replaces the custom-access-token-hook approach for resolving contact_id.
-- That hook requires a manual, easy-to-miss dashboard toggle (Authentication
-- -> Hooks -> Custom Access Token) with no way to verify from outside the
-- dashboard whether it's actually active — and in practice it wasn't, so
-- the app was stuck in Prospect mode with no clear signal why. This RPC
-- does the same contact lookup, but as a plain authenticated call: it reads
-- auth.uid()/auth.jwt() itself (already always available, hook or not) and
-- returns the resolved mode/ids directly, bypassing the RLS chicken-and-egg
-- problem instead of depending on a claim that has to be pre-baked into the
-- JWT.
create or replace function public.resolve_app_mode()
returns table (contact_id uuid, tenant_id uuid, project_id uuid, stage text)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  jwt_email text;
begin
  jwt_email := auth.jwt() ->> 'email';

  return query
  select c.id, c.tenant_id, p.id, p.stage
  from contacts c
  left join lateral (
    select pr.id, pr.stage
    from projects pr
    where pr.contact_id = c.id
    order by pr.created_at desc
    limit 1
  ) p on true
  where jwt_email is not null and lower(c.email) = lower(jwt_email)
  limit 1;
end;
$$;

grant execute on function public.resolve_app_mode to authenticated;

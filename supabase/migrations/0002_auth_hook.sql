-- Custom access token hook: injects contact_id into the JWT by phone lookup
-- at token-issuance time, so RLS policies (which key off auth.jwt() ->> 'contact_id')
-- have something to check without the client ever querying contacts/projects
-- directly pre-auth. Runs for every token issuance, including phone OTP.
-- See docs/sync-validation.md and BUILD_PLAN.md step 4.
--
-- Must be wired up in the dashboard after this migration runs:
-- Authentication -> Hooks (Beta) -> Custom Access Token -> select
-- public.custom_access_token_hook.

create or replace function public.custom_access_token_hook(event jsonb)
returns jsonb
language plpgsql
stable
as $$
declare
  claims jsonb;
  matched_contact_id uuid;
  matched_tenant_id uuid;
  jwt_phone text;
begin
  claims := event->'claims';
  jwt_phone := claims->>'phone';

  if jwt_phone is not null and jwt_phone <> '' then
    select id, tenant_id into matched_contact_id, matched_tenant_id
    from public.contacts
    where phone = '+' || jwt_phone
    limit 1;
  end if;

  if matched_contact_id is not null then
    claims := jsonb_set(claims, '{contact_id}', to_jsonb(matched_contact_id::text));
    claims := jsonb_set(claims, '{tenant_id}', to_jsonb(matched_tenant_id::text));
  end if;

  event := jsonb_set(event, '{claims}', claims);
  return event;
end;
$$;

grant usage on schema public to supabase_auth_admin;
grant execute on function public.custom_access_token_hook to supabase_auth_admin;
revoke execute on function public.custom_access_token_hook from authenticated, anon, public;

grant select on public.contacts to supabase_auth_admin;

create policy "Allow auth admin to read contacts for token claims" on public.contacts
  as permissive for select to supabase_auth_admin using (true);

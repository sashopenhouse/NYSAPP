-- Switch the custom access token hook from phone to email lookup.
-- Phone auth is blocked on a real Twilio account (trial rejects Supabase's
-- default OTP template — see docs/sync-validation.md); email OTP needs no
-- third-party SMS provider, so auth switched to email-only for now. Phone
-- can come back as an additional path once SMS is sorted; this migration
-- only changes the lookup key, not the contacts table shape.
create or replace function public.custom_access_token_hook(event jsonb)
returns jsonb
language plpgsql
stable
set search_path = public, pg_temp
as $$
declare
  claims jsonb;
  matched_contact_id uuid;
  matched_tenant_id uuid;
  jwt_email text;
begin
  claims := event->'claims';
  jwt_email := claims->>'email';

  if jwt_email is not null and jwt_email <> '' then
    select id, tenant_id into matched_contact_id, matched_tenant_id
    from public.contacts
    where lower(email) = lower(jwt_email)
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

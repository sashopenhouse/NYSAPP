-- Email is now the auth identity key (see 0005_auth_hook_email.sql), so it
-- must be reliable: required and unique per tenant, same guarantee phone
-- already had. Table is empty at time of writing — no backfill needed.
alter table contacts
  alter column email set not null,
  add constraint contacts_tenant_email_unique unique (tenant_id, email);

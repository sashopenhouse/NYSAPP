-- NYSAPP initial schema. Every table carries tenant_id from day one.

create table if not exists tenants (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz not null default now()
);

create table if not exists contacts (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id),
  phone text not null,
  email text,
  name text,
  connectteam_job_id text,
  created_at timestamptz not null default now(),
  unique (tenant_id, phone)
);

create index if not exists contacts_connectteam_job_id_idx on contacts(connectteam_job_id);

create table if not exists projects (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id),
  contact_id uuid not null references contacts(id),
  stage text not null default 'measure'
    check (stage in ('measure', 'order_placed', 'permit', 'install_scheduled', 'install', 'punch_list', 'final')),
  product_lines text[] not null default '{}',
  sold_at timestamptz,
  install_window_start timestamptz,
  install_window_end timestamptz,
  crew_ids text[] not null default '{}',
  created_at timestamptz not null default now()
);

create index if not exists projects_contact_id_idx on projects(contact_id);

create table if not exists project_events (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id),
  project_id uuid not null references projects(id),
  stage text not null,
  occurred_at timestamptz not null,
  source text not null default 'connectteam',
  raw_payload jsonb,
  created_at timestamptz not null default now()
);

create index if not exists project_events_project_id_idx on project_events(project_id, occurred_at desc);

create table if not exists media (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id),
  project_id uuid not null references projects(id),
  url text not null,
  caption text,
  source text not null default 'connectteam',
  approved_for_customer boolean not null default false,
  approved_by uuid,
  approved_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists media_project_id_idx on media(project_id);
create index if not exists media_approved_idx on media(project_id, approved_for_customer);

create table if not exists documents (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id),
  project_id uuid not null references projects(id),
  kind text not null check (kind in ('contract', 'permit', 'spec_sheet', 'other')),
  url text not null,
  title text,
  created_at timestamptz not null default now()
);

create table if not exists messages (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id),
  project_id uuid not null references projects(id),
  sender text not null check (sender in ('customer', 'office')),
  body text not null,
  created_at timestamptz not null default now()
);

create table if not exists warranties (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id),
  project_id uuid not null references projects(id),
  product_name text not null,
  serial_number text,
  registered_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists referrals (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id),
  contact_id uuid not null references contacts(id),
  code text not null unique,
  created_at timestamptz not null default now()
);

create table if not exists products (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id),
  name text not null,
  category text not null,
  model_asset_url text,
  created_at timestamptz not null default now()
);

alter table tenants enable row level security;
alter table contacts enable row level security;
alter table projects enable row level security;
alter table project_events enable row level security;
alter table media enable row level security;
alter table documents enable row level security;
alter table messages enable row level security;
alter table warranties enable row level security;
alter table referrals enable row level security;
alter table products enable row level security;

-- RLS: a customer only sees rows tied to their own contact record.
-- auth.jwt() carries the contact_id set at magic-link verification time (see auth design in Phase 1, step 4).

create policy contacts_self on contacts
  for select using (id = (auth.jwt() ->> 'contact_id')::uuid);

create policy projects_self on projects
  for select using (contact_id = (auth.jwt() ->> 'contact_id')::uuid);

create policy project_events_self on project_events
  for select using (project_id in (select id from projects where contact_id = (auth.jwt() ->> 'contact_id')::uuid));

create policy media_self on media
  for select using (
    approved_for_customer = true
    and project_id in (select id from projects where contact_id = (auth.jwt() ->> 'contact_id')::uuid)
  );

create policy documents_self on documents
  for select using (project_id in (select id from projects where contact_id = (auth.jwt() ->> 'contact_id')::uuid));

create policy messages_self on messages
  for select using (project_id in (select id from projects where contact_id = (auth.jwt() ->> 'contact_id')::uuid));

create policy warranties_self on warranties
  for select using (project_id in (select id from projects where contact_id = (auth.jwt() ->> 'contact_id')::uuid));

create policy referrals_self on referrals
  for select using (contact_id = (auth.jwt() ->> 'contact_id')::uuid);

create policy products_public_read on products
  for select using (true);

-- Writes (messages insert, media approval, etc.) are handled by service-role
-- functions (edge functions / sync service), not direct client writes, so no
-- insert/update policies are granted to the authenticated role here.

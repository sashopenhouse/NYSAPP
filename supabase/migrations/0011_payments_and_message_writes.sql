-- Phase 1 gaps: the payment schedule table BUILD_PLAN.md calls for (view
-- only) and the insert path that lets a homeowner actually send a message.

create table if not exists payments (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id),
  project_id uuid not null references projects(id),
  label text not null,
  amount_cents bigint not null check (amount_cents >= 0),
  due_on date,
  paid_at timestamptz,
  sequence integer not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists payments_project_id_idx on payments(project_id, sequence);

alter table payments enable row level security;

-- View only, per the build plan: select is granted, no insert/update path
-- for the authenticated role. The office writes these via service role.
create policy payments_self on payments
  for select using (project_id in (select id from projects where contact_id = public.current_contact_id()));

-- The single message thread is the one place in Phase 1 where a customer
-- writes. Scoped tightly: they may only insert into their own project, and
-- only as sender='customer' — they cannot forge a message from the office.
-- There is deliberately no update/delete policy, so a sent message is
-- immutable from the client.
create policy messages_insert_self on messages
  for insert to authenticated
  with check (
    sender = 'customer'
    and project_id in (select id from projects where contact_id = public.current_contact_id())
    and tenant_id in (select tenant_id from projects where contact_id = public.current_contact_id())
  );

-- The thread updates live when the office replies.
alter publication supabase_realtime add table public.messages;

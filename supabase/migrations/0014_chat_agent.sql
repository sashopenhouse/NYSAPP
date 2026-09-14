-- Support for the status-only chat agent (supabase/functions/chat-agent).
--
-- The agent answers a homeowner's project-status questions from their own
-- Supabase rows and nothing else. When it can't answer from that context it
-- stays silent and records a handoff, so the office picks the thread up.

-- Disclosure, not decoration: a homeowner should be able to tell that a
-- reply was generated rather than typed by their project manager, and the
-- office needs to distinguish its own replies from the agent's.
alter table messages add column if not exists authored_by_agent boolean not null default false;
alter table messages add column if not exists in_reply_to uuid references messages(id);

create index if not exists messages_in_reply_to_idx on messages(in_reply_to);

-- Threads the agent declined. This is a work queue for the office, not
-- customer-facing: a handoff means a real person still owes an answer.
create table if not exists agent_handoffs (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id),
  project_id uuid not null references projects(id),
  message_id uuid not null references messages(id),
  reason text,
  resolved_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists agent_handoffs_open_idx on agent_handoffs(tenant_id, resolved_at, created_at);

alter table agent_handoffs enable row level security;

-- No policy for the authenticated role on purpose. Handoffs carry internal
-- notes about why the agent wouldn't answer ("customer sounds upset",
-- "asked about contract terms") and are written and read by the service
-- role only. RLS enabled with no policy means a customer's own token can
-- never read this table, which is the intent.

-- The customer insert policy from 0011 predates these columns. Rewrite it so
-- a client cannot set authored_by_agent — otherwise a homeowner could post a
-- message that renders as agent-authored, or mark their own message as
-- coming from the agent.
drop policy if exists messages_insert_self on messages;

create policy messages_insert_self on messages
  for insert to authenticated
  with check (
    sender = 'customer'
    and authored_by_agent = false
    and project_id in (select id from projects where contact_id = public.current_contact_id())
    and tenant_id in (select tenant_id from projects where contact_id = public.current_contact_id())
  );

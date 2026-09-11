-- Enable Realtime on the tables the timeline screen subscribes to, so a
-- stage change written by connecteam-webhook reaches a signed-in client
-- without polling. See BUILD_PLAN.md's blocking validation and
-- docs/sync-validation.md.
alter publication supabase_realtime add table public.project_events;
alter publication supabase_realtime add table public.projects;

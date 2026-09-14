-- create_review_request_on_final is a trigger function: Postgres invokes it
-- on insert into project_events, and nothing should ever call it directly.
-- Because it lives in the exposed `public` schema, PostgREST published it as
-- /rest/v1/rpc/create_review_request_on_final, callable by anon — a
-- SECURITY DEFINER function reachable without signing in (caught by the
-- Supabase security advisor right after 0012 was applied). Revoking EXECUTE
-- closes that without affecting trigger invocation, which runs as the table
-- owner and does not consult these grants.
revoke execute on function public.create_review_request_on_final() from anon, authenticated, public;

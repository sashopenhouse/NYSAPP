-- Fix: pin search_path on the access token hook to prevent search_path
-- hijacking (flagged by the Supabase security advisor after 0002_auth_hook.sql).
alter function public.custom_access_token_hook(jsonb) set search_path = public, pg_temp;

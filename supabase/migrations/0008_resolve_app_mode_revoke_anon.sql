-- resolve_app_mode reads auth.jwt(), so it's meaningless for an anonymous
-- caller (no email to match), but SECURITY DEFINER functions are callable
-- by anon by default unless revoked — flagged by the security advisor.
revoke execute on function public.resolve_app_mode from anon, public;

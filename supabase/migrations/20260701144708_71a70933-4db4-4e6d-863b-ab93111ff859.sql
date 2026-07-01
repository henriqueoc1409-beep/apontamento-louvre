
-- Fix search_path warning for trigger helpers
create or replace function public.tg_touch_updated_at()
returns trigger language plpgsql set search_path = public as $$
begin new.updated_at = now(); return new; end $$;

-- Restrict execution: trigger fns don't need direct callers
revoke execute on function public.handle_new_user() from public, anon, authenticated;
revoke execute on function public.tg_touch_updated_at() from public, anon, authenticated;

-- has_role/is_approved are called from RLS as the current user — keep authenticated, drop public/anon
revoke execute on function public.has_role(uuid, public.app_role) from public, anon;
revoke execute on function public.is_approved(uuid) from public, anon;

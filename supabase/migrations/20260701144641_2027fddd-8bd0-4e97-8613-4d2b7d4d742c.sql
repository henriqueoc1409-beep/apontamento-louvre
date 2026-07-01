
-- Roles enum
create type public.app_role as enum ('admin','user');

-- Profiles
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  nome text,
  approved boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
grant select, insert, update, delete on public.profiles to authenticated;
grant all on public.profiles to service_role;
alter table public.profiles enable row level security;

-- user_roles
create table public.user_roles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  role public.app_role not null,
  unique(user_id, role)
);
grant select on public.user_roles to authenticated;
grant all on public.user_roles to service_role;
alter table public.user_roles enable row level security;

-- has_role() security definer
create or replace function public.has_role(_user_id uuid, _role public.app_role)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.user_roles where user_id = _user_id and role = _role)
$$;

-- is_approved helper (avoids recursive RLS on profiles)
create or replace function public.is_approved(_user_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select approved from public.profiles where id = _user_id), false)
$$;

-- Profiles policies
create policy "own profile read" on public.profiles for select to authenticated
  using (auth.uid() = id or public.has_role(auth.uid(),'admin'));
create policy "own profile insert" on public.profiles for insert to authenticated
  with check (auth.uid() = id);
create policy "admin updates profiles" on public.profiles for update to authenticated
  using (public.has_role(auth.uid(),'admin')) with check (public.has_role(auth.uid(),'admin'));
create policy "admin deletes profiles" on public.profiles for delete to authenticated
  using (public.has_role(auth.uid(),'admin'));

-- user_roles policies
create policy "read own roles" on public.user_roles for select to authenticated
  using (user_id = auth.uid() or public.has_role(auth.uid(),'admin'));
create policy "admin manages roles" on public.user_roles for all to authenticated
  using (public.has_role(auth.uid(),'admin')) with check (public.has_role(auth.uid(),'admin'));

-- app_data (shared KV store)
create table public.app_data (
  key text primary key,
  value jsonb,
  updated_by uuid references auth.users(id),
  updated_at timestamptz not null default now()
);
grant select, insert, update, delete on public.app_data to authenticated;
grant all on public.app_data to service_role;
alter table public.app_data enable row level security;

create policy "approved read app_data" on public.app_data for select to authenticated
  using (public.is_approved(auth.uid()));
create policy "approved write app_data insert" on public.app_data for insert to authenticated
  with check (public.is_approved(auth.uid()));
create policy "approved write app_data update" on public.app_data for update to authenticated
  using (public.is_approved(auth.uid())) with check (public.is_approved(auth.uid()));
create policy "approved write app_data delete" on public.app_data for delete to authenticated
  using (public.is_approved(auth.uid()));

-- Auto profile + admin bootstrap on signup
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  is_admin boolean := lower(new.email) = 'henrique@tresincorporadora.com.br';
begin
  insert into public.profiles (id, email, nome, approved)
  values (new.id, new.email, coalesce(new.raw_user_meta_data->>'nome', split_part(new.email,'@',1)), is_admin)
  on conflict (id) do nothing;

  if is_admin then
    insert into public.user_roles(user_id, role) values (new.id, 'admin')
    on conflict do nothing;
  end if;
  return new;
end $$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

-- updated_at trigger for app_data
create or replace function public.tg_touch_updated_at()
returns trigger language plpgsql as $$ begin new.updated_at = now(); return new; end $$;
create trigger app_data_touch before update on public.app_data
for each row execute function public.tg_touch_updated_at();
create trigger profiles_touch before update on public.profiles
for each row execute function public.tg_touch_updated_at();

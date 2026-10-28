-- Account/setup data only. Simulated health data remains separate.
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  weight_kg text not null default '70',
  profile_complete boolean not null default false,
  consent_complete boolean not null default false,
  device_complete boolean not null default false,
  pairing_step integer not null default 0 check (pairing_step between 0 and 9),
  permissions jsonb not null default '{}'::jsonb check (jsonb_typeof(permissions) = 'object'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.profiles enable row level security;
revoke all on public.profiles from public, anon, authenticated;
grant select on public.profiles to authenticated;
grant insert (id) on public.profiles to authenticated;
grant update (full_name, weight_kg, profile_complete, consent_complete,
  device_complete, pairing_step, permissions) on public.profiles to authenticated;
drop policy if exists profiles_select_own on public.profiles;
create policy profiles_select_own on public.profiles for select to authenticated
  using ((select auth.uid()) = id);
drop policy if exists profiles_insert_own on public.profiles;
create policy profiles_insert_own on public.profiles for insert to authenticated
  with check ((select auth.uid()) = id);
drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles for update to authenticated
  using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

create or replace function public.ehealth_touch_profile()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end;
$$;
drop trigger if exists ehealth_profile_updated on public.profiles;
create trigger ehealth_profile_updated before update on public.profiles
for each row execute function public.ehealth_touch_profile();

create or replace function public.ehealth_create_profile()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, full_name)
    values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', ''))
    on conflict (id) do nothing;
  return new;
end;
$$;
revoke all on function public.ehealth_create_profile() from public, anon, authenticated;
revoke all on function public.ehealth_touch_profile() from public, anon, authenticated;
drop trigger if exists ehealth_auth_profile_created on auth.users;
create trigger ehealth_auth_profile_created after insert on auth.users
for each row execute function public.ehealth_create_profile();
-- Existing accounts get a fresh, incomplete setup record; no local flags trusted.
insert into public.profiles (id, full_name)
select id, coalesce(raw_user_meta_data ->> 'full_name', '') from auth.users
on conflict (id) do nothing;

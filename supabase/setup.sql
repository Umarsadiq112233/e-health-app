-- E-Health Supabase setup for project oamqpmqlydxmxeeipyha
-- Run this whole file once in Supabase Dashboard -> SQL Editor.
-- It is safe to run again because the statements are idempotent.
-- Never put the Supabase secret/service-role key in this file or in Flutter.


-- -----------------------------------------------------------------------------
-- supabase/migrations/202610060001_profiles.sql
-- -----------------------------------------------------------------------------

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

-- -----------------------------------------------------------------------------
-- supabase/migrations/202610070001_profile_avatars.sql
-- -----------------------------------------------------------------------------

-- New private bucket avoids changing any existing public/legacy avatar bucket.
alter table public.profiles add column if not exists avatar_path text;
alter table public.profiles add column if not exists avatar_url text;
grant update (avatar_path, avatar_url) on public.profiles to authenticated;

insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values ('ehealth-avatars','ehealth-avatars',false,2097152,array['image/jpeg'])
on conflict (id) do update set public = false, file_size_limit = 2097152,
  allowed_mime_types = array['image/jpeg'];

-- Stable object key only. Existing legacy references are preserved unless edited.
create or replace function public.ehealth_avatar_reference()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.avatar_path is distinct from old.avatar_path and new.avatar_path is not null then
    if new.avatar_path !~ ('^' || new.id::text || '/[a-zA-Z0-9_-]+\.jpg$') then
      raise exception 'Avatar path must be an owned JPEG object key' using errcode = '23514';
    end if;
  end if;
  if new.avatar_url is distinct from old.avatar_url and new.avatar_url is not null then
    raise exception 'New avatars must use stable avatar_path, not URLs' using errcode = '23514';
  end if;
  return new;
end;
$$;
revoke all on function public.ehealth_avatar_reference() from public, anon, authenticated;
drop trigger if exists ehealth_avatar_reference on public.profiles;
create trigger ehealth_avatar_reference before update of avatar_path, avatar_url on public.profiles
for each row execute function public.ehealth_avatar_reference();

-- Restrictive boundary also protects this bucket from any older broad policies.
drop policy if exists ehealth_avatar_boundary on storage.objects;
create policy ehealth_avatar_boundary on storage.objects as restrictive for all to public
using (bucket_id <> 'ehealth-avatars' or (
  (storage.foldername(name))[1] = (select auth.uid())::text
  and owner_id = (select auth.uid())::text))
with check (bucket_id <> 'ehealth-avatars' or (
  (storage.foldername(name))[1] = (select auth.uid())::text
  and owner_id = (select auth.uid())::text));

drop policy if exists ehealth_avatar_read on storage.objects;
create policy ehealth_avatar_read on storage.objects for select to authenticated
using (bucket_id = 'ehealth-avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);
drop policy if exists ehealth_avatar_upload on storage.objects;
create policy ehealth_avatar_upload on storage.objects for insert to authenticated
with check (bucket_id = 'ehealth-avatars' and (storage.foldername(name))[1] = (select auth.uid())::text
  and owner_id = (select auth.uid())::text and storage.extension(name) = 'jpg');
drop policy if exists ehealth_avatar_replace on storage.objects;
create policy ehealth_avatar_replace on storage.objects for update to authenticated
using (bucket_id = 'ehealth-avatars' and (storage.foldername(name))[1] = (select auth.uid())::text)
with check (bucket_id = 'ehealth-avatars' and (storage.foldername(name))[1] = (select auth.uid())::text
  and owner_id = (select auth.uid())::text and storage.extension(name) = 'jpg');
drop policy if exists ehealth_avatar_delete on storage.objects;
create policy ehealth_avatar_delete on storage.objects for delete to authenticated
using (bucket_id = 'ehealth-avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);

-- -----------------------------------------------------------------------------
-- supabase/migrations/202610290002_profile_birth_date.sql
-- -----------------------------------------------------------------------------

-- Store the date of birth as a typed, private profile field.
-- The wellness JSON fallback is retained for existing accounts and older clients.
alter table public.profiles
  add column if not exists date_of_birth date;

update public.profiles
set date_of_birth = to_date(
  permissions -> '_wellness' ->> 'birthday',
  'YYYY-MM-DD'
)
where date_of_birth is null
  and permissions -> '_wellness' ->> 'birthday' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
  and to_char(
    to_date(permissions -> '_wellness' ->> 'birthday', 'YYYY-MM-DD'),
    'YYYY-MM-DD'
  ) = permissions -> '_wellness' ->> 'birthday';

grant update (date_of_birth) on public.profiles to authenticated;


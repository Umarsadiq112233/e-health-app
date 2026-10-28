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

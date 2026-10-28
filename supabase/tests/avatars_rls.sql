-- Run as DB owner AFTER both migrations. All fixtures and test policies roll back.
-- This checks database RLS. Storage API MIME/byte enforcement needs API testing.
begin;
insert into auth.users(id,aud,role,email,raw_user_meta_data)
values ('b1000000-0000-0000-0000-000000000001','authenticated','authenticated','avatar-a@example.invalid','{}'),
       ('b1000000-0000-0000-0000-000000000002','authenticated','authenticated','avatar-b@example.invalid','{}');
insert into storage.objects(bucket_id,name,owner_id) values
('ehealth-avatars','b1000000-0000-0000-0000-000000000002/b.jpg','b1000000-0000-0000-0000-000000000002');
-- Simulate an old broad policy: the restrictive avatar boundary must still win.
create policy avatar_test_broad on storage.objects for all to authenticated using (true) with check (true);
set local role authenticated;
select set_config('request.jwt.claim.sub','b1000000-0000-0000-0000-000000000001',true);
do $$
declare affected integer;
begin
  insert into storage.objects(bucket_id,name,owner_id) values
    ('ehealth-avatars','b1000000-0000-0000-0000-000000000001/a.jpg','b1000000-0000-0000-0000-000000000001');
  if (select count(*) from storage.objects where bucket_id = 'ehealth-avatars') <> 1 then raise exception 'Cross-user avatar read allowed'; end if;
  update storage.objects set name = 'b1000000-0000-0000-0000-000000000002/stolen.jpg' where name like '%/b.jpg';
  get diagnostics affected = row_count;
  if affected <> 0 then raise exception 'Cross-user avatar update allowed'; end if;
  delete from storage.objects where name like '%/b.jpg';
  get diagnostics affected = row_count;
  if affected <> 0 then raise exception 'Cross-user avatar delete allowed'; end if;
  begin
    insert into storage.objects(bucket_id,name,owner_id) values ('ehealth-avatars','b1000000-0000-0000-0000-000000000002/attack.jpg','b1000000-0000-0000-0000-000000000001');
    raise exception 'Cross-user upload allowed';
  exception when insufficient_privilege then null;
  end;
  begin
    update storage.objects set owner_id = 'b1000000-0000-0000-0000-000000000002';
    raise exception 'Avatar ownership reassignment allowed';
  exception when insufficient_privilege then null;
  end;
  update public.profiles set avatar_path = 'b1000000-0000-0000-0000-000000000001/a.jpg' where id = (select auth.uid());
  begin
    update public.profiles set avatar_path = 'b1000000-0000-0000-0000-000000000002/b.jpg' where id = (select auth.uid());
    raise exception 'Foreign avatar reference allowed';
  exception when check_violation then null;
  end;
  begin
    update public.profiles set avatar_url = 'https://example.invalid/expiring?token=x' where id = (select auth.uid());
    raise exception 'Permanent signed URL storage allowed';
  exception when check_violation then null;
  end;
  delete from storage.objects where name like '%/a.jpg';
  get diagnostics affected = row_count;
  if affected <> 1 then raise exception 'Own avatar delete failed'; end if;
end;
$$;
select set_config('request.jwt.claim.sub','b1000000-0000-0000-0000-000000000002',true);
do $$
begin
  if (select count(*) from storage.objects where bucket_id = 'ehealth-avatars') <> 1 then raise exception 'User B isolation failed'; end if;
end;
$$;
reset role;
do $$
begin
  if not exists (select 1 from storage.buckets where id = 'ehealth-avatars' and public = false and file_size_limit = 2097152 and allowed_mime_types = array['image/jpeg']) then raise exception 'Avatar bucket constraints are incorrect'; end if;
end;
$$;
rollback;

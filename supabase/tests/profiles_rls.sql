-- Run as database owner after the migration (SQL Editor or psql).
-- Dedicated fixtures are rolled back; no email or external Auth API calls.
begin;
insert into auth.users (id, aud, role, email, raw_user_meta_data)
values ('a1000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'rls-a@example.invalid', '{}'),
       ('a1000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'rls-b@example.invalid', '{}');
set local role authenticated;
select set_config('request.jwt.claim.sub', 'a1000000-0000-0000-0000-000000000001', true);
do $$
declare affected integer;
begin
  if (select count(*) from public.profiles) <> 1 then
    raise exception 'RLS failed: another profile is visible';
  end if;
  update public.profiles set full_name = 'User A', pairing_step = 6
    where id = 'a1000000-0000-0000-0000-000000000001';
  get diagnostics affected = row_count;
  if affected <> 1 then raise exception 'Own profile update failed'; end if;
  update public.profiles set full_name = 'Attacked'
    where id = 'a1000000-0000-0000-0000-000000000002';
  get diagnostics affected = row_count;
  if affected <> 0 then raise exception 'Cross-user update allowed'; end if;
  begin
    insert into public.profiles (id) values ('a1000000-0000-0000-0000-000000000003');
    raise exception 'Cross-user insert allowed';
  exception when insufficient_privilege then null;
  end;
  begin
    update public.profiles set created_at = now();
    raise exception 'Protected column update allowed';
  exception when insufficient_privilege then null;
  end;
end;
$$;
select set_config('request.jwt.claim.sub', 'a1000000-0000-0000-0000-000000000002', true);
do $$
begin
  if (select count(*) from public.profiles) <> 1 or
     exists (select 1 from public.profiles where full_name = 'User A') then
    raise exception 'User B isolation failed';
  end if;
end;
$$;
rollback;

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

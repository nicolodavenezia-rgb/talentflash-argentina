-- Fixtures compartidos para la suite pgTAP. Este archivo corre primero y
-- confirma los datos; `supabase db reset` garantiza una base descartable.

begin;
select plan(1);

create schema if not exists tests;

create table if not exists tests.identifiers (
  identifier text primary key,
  id uuid not null unique
);

create or replace function tests.get_uuid(p_identifier text) returns uuid
language sql stable
set search_path = ''
as $$
  select i.id from tests.identifiers i where i.identifier = p_identifier;
$$;

create or replace function tests.authenticate_as(p_identifier text) returns void
language plpgsql
set search_path = ''
as $$
declare
  user_id uuid;
begin
  select i.id into strict user_id
  from tests.identifiers i
  where i.identifier = p_identifier;

  perform set_config('request.jwt.claim.sub', user_id::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  perform set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', user_id, 'role', 'authenticated')::text,
    true
  );
  execute 'set local role authenticated';
end;
$$;

grant usage on schema tests to anon, authenticated;
grant select on tests.identifiers to anon, authenticated;
grant execute on function tests.get_uuid(text) to anon, authenticated;
grant execute on function tests.authenticate_as(text) to anon, authenticated;

insert into tests.identifiers (identifier, id)
select 'user_cand_pub', id from auth.users where email = 'candidato1@dev.talentflash.test'
union all
select 'user_cand_priv', id from auth.users where email = 'candidato16@dev.talentflash.test'
union all
select 'user_empresa_ok', id from auth.users where email = 'empresa1@dev.talentflash.test'
union all
select 'user_empresa_pend', id from auth.users where email = 'empresa2@dev.talentflash.test'
union all
select 'user_empresa_otra', id from auth.users where email = 'empresa3@dev.talentflash.test'
on conflict (identifier) do update set id = excluded.id;

insert into tests.identifiers (identifier, id)
select 'cand_pub', cp.id
from public.candidate_profiles cp
join auth.users u on u.id = cp.profile_id
where u.email = 'candidato1@dev.talentflash.test'
union all
select 'cand_priv', cp.id
from public.candidate_profiles cp
join auth.users u on u.id = cp.profile_id
where u.email = 'candidato16@dev.talentflash.test'
on conflict (identifier) do update set id = excluded.id;

update public.company_profiles cp
set verification_status = 'pending'
from auth.users u
where cp.created_by = u.id and u.email = 'empresa2@dev.talentflash.test';

insert into tests.identifiers (identifier, id)
select 'company_ok', cp.id
from public.company_profiles cp
join auth.users u on u.id = cp.created_by
where u.email = 'empresa1@dev.talentflash.test'
union all
select 'company_pend', cp.id
from public.company_profiles cp
join auth.users u on u.id = cp.created_by
where u.email = 'empresa2@dev.talentflash.test'
on conflict (identifier) do update set id = excluded.id;

insert into tests.identifiers (identifier, id)
select 'job_A', j.id
from public.jobs j
join auth.users u on u.id = j.created_by
where u.email = 'empresa1@dev.talentflash.test'
order by j.created_at, j.id
limit 1
on conflict (identifier) do update set id = excluded.id;

insert into tests.identifiers (identifier, id)
select 'job_draft', j.id
from public.jobs j
join auth.users u on u.id = j.created_by
where u.email = 'empresa1@dev.talentflash.test'
  and j.id <> tests.get_uuid('job_A')
order by j.created_at, j.id
limit 1
on conflict (identifier) do update set id = excluded.id;

update public.jobs set status = 'draft' where id = tests.get_uuid('job_draft');

insert into public.job_applications (
  id, job_id, candidate_profile_id, cover_note
) values (
  'e1000000-0000-4000-8000-000000000001',
  tests.get_uuid('job_A'),
  tests.get_uuid('cand_pub'),
  'Postulación fixture'
)
on conflict (job_id, candidate_profile_id) do nothing;

insert into tests.identifiers (identifier, id)
select 'application_A', a.id
from public.job_applications a
where a.job_id = tests.get_uuid('job_A')
  and a.candidate_profile_id = tests.get_uuid('cand_pub')
on conflict (identifier) do update set id = excluded.id;

insert into public.conversations (
  id, company_id, candidate_profile_id, job_id, origin
) values (
  'e2000000-0000-4000-8000-000000000001',
  tests.get_uuid('company_ok'),
  tests.get_uuid('cand_pub'),
  tests.get_uuid('job_A'),
  'application'
)
on conflict (id) do nothing;

insert into public.messages (
  id, conversation_id, sender_profile_id, body
) values (
  'e3000000-0000-4000-8000-000000000001',
  'e2000000-0000-4000-8000-000000000001',
  tests.get_uuid('user_cand_pub'),
  'Mensaje fixture'
)
on conflict (id) do nothing;

insert into tests.identifiers (identifier, id) values
  ('conversation_A', 'e2000000-0000-4000-8000-000000000001'),
  ('message_from_candidate', 'e3000000-0000-4000-8000-000000000001')
on conflict (identifier) do update set id = excluded.id;

insert into public.notifications (
  id, profile_id, type, title, body
) values (
  'e4000000-0000-4000-8000-000000000001',
  tests.get_uuid('user_cand_pub'),
  'system',
  'Notificación fixture',
  'Contenido confiable'
)
on conflict (id) do nothing;

insert into tests.identifiers (identifier, id)
values ('notification_cand', 'e4000000-0000-4000-8000-000000000001')
on conflict (identifier) do update set id = excluded.id;

insert into public.payments (
  payer_profile_id, provider_payment_id, amount
) values (
  tests.get_uuid('user_cand_pub'), 'fixture-payment', 1000
)
on conflict (provider, provider_payment_id) do nothing;

-- El trigger debe degradar cualquier intento de alta admin desde metadata no
-- confiable a candidate, tanto en profiles como en app_metadata.
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values (
  '00000000-0000-0000-0000-000000000000',
  '90000000-0000-4000-8000-000000000001',
  'authenticated', 'authenticated', 'requested-admin@tests.local',
  crypt('password123', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{"role":"admin"}'::jsonb, now(), now()
)
on conflict (id) do nothing;

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values (
  '00000000-0000-0000-0000-000000000000',
  '90000000-0000-4000-8000-000000000002',
  'authenticated', 'authenticated', 'new-company@tests.local',
  crypt('password123', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{"role":"company"}'::jsonb, now(), now()
)
on conflict (id) do nothing;

insert into tests.identifiers (identifier, id) values
  ('user_requested_admin', '90000000-0000-4000-8000-000000000001'),
  ('user_company_new', '90000000-0000-4000-8000-000000000002')
on conflict (identifier) do update set id = excluded.id;

select pass('fixtures y helpers pgTAP creados');
select * from finish();
commit;

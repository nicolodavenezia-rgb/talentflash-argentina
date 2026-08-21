-- Generado desde docs/DATA_MODEL.md (fuente de verdad; §8 define el orden).
-- No editar sin actualizar el documento. Bloque A: T-005/T-006/T-007.

create or replace function is_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.profiles
                 where id = auth.uid() and role = 'admin' and deleted_at is null);
$$;

create or replace function is_company_member(p_company_id uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.company_members
                 where company_id = p_company_id and profile_id = auth.uid());
$$;

create or replace function is_verified_company_member() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1
                 from public.company_members cm
                 join public.company_profiles cp on cp.id = cm.company_id
                 where cm.profile_id = auth.uid()
                   and cp.verification_status = 'approved'
                   and cp.deleted_at is null);
$$;

create or replace function has_active_subscription(p_company_id uuid default null)
returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.subscriptions s
                 where s.status in ('trialing','active')
                   and s.current_period_end > now()
                   and ((p_company_id is not null and s.company_id = p_company_id)
                     or (p_company_id is null and s.profile_id = auth.uid())));
$$;

create or replace function are_blocked(p_a uuid, p_b uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.blocks
                 where (blocker_profile_id = p_a and blocked_profile_id = p_b)
                    or (blocker_profile_id = p_b and blocked_profile_id = p_a));
$$;

create or replace function candidate_id() returns uuid
language sql stable security definer set search_path = '' as $$
  select id from public.candidate_profiles where profile_id = auth.uid();
$$;

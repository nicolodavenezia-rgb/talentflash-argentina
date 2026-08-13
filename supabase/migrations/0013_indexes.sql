-- Generado desde docs/DATA_MODEL.md (fuente de verdad; §8 define el orden).
-- No editar sin actualizar el documento. Bloque A: T-005/T-006/T-007.

-- FKs consultadas (Postgres no indexa FKs automáticamente)
create index idx_candidate_profiles_profile on candidate_profiles(profile_id);
create index idx_company_members_company on company_members(company_id);
create index idx_company_members_profile on company_members(profile_id);
create index idx_jobs_company on jobs(company_id);
create index idx_applications_job on job_applications(job_id);
create index idx_applications_candidate on job_applications(candidate_profile_id);
create index idx_invitations_candidate on invitations(candidate_profile_id);
create index idx_matches_candidate on matches(candidate_profile_id);
create index idx_messages_conversation on messages(conversation_id, created_at desc);
create index idx_notifications_profile on notifications(profile_id, created_at desc)
  where read_at is null;                          -- badge de no leídas
create index idx_videos_owner on videos(owner_profile_id);
create index idx_payments_subscription on payments(subscription_id);
create index idx_payments_payer on payments(payer_profile_id, created_at desc);
create index idx_consents_latest on consents(profile_id, consent_type, created_at desc); -- estado vigente = última fila

-- Parciales por estado activo (feeds y búsqueda solo tocan lo vivo)
create index idx_jobs_active on jobs(published_at desc)
  where status = 'active' and deleted_at is null;
create index idx_jobs_active_geo on jobs(provincia_id, localidad_id)
  where status = 'active' and deleted_at is null;
create index idx_jobs_active_sector on jobs(sector_id)
  where status = 'active' and deleted_at is null;
create index idx_candidates_published on candidate_profiles(published_at desc)
  where is_published and deleted_at is null;
create index idx_subscriptions_active on subscriptions(profile_id, company_id)
  where status in ('trialing','active');
create index idx_videos_expiring on videos(expires_at)
  where status = 'ready';                          -- job de vencimiento (pg_cron)
create index idx_payment_events_pending on payment_events(received_at)
  where processed_at is null;                      -- cola de reintento de webhooks

-- Búsqueda de texto (pg_trgm, tolerante a tipeos)
create index idx_jobs_title_trgm on jobs using gin (title gin_trgm_ops);
create index idx_jobs_desc_trgm on jobs using gin (description gin_trgm_ops);
create index idx_candidates_headline_trgm on candidate_profiles using gin (headline gin_trgm_ops);
create index idx_candidates_skills on candidate_profiles using gin (skills);

-- Feeds por fecha
create index idx_jobs_created on jobs(created_at desc);
create index idx_conversations_last_msg on conversations(last_message_at desc nulls last);

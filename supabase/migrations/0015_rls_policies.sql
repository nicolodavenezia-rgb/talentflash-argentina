-- Generado desde docs/DATA_MODEL.md (fuente de verdad; §8 define el orden).
-- No editar sin actualizar el documento. Bloque A: T-005/T-006/T-007.

-- T-007 — deny-by-default: RLS habilitado en TODAS las tablas de public
-- (DATA_MODEL.md §5 lo exige en prosa; sin policy explícita = sin acceso).
do $$
declare t record;
begin
  for t in select tablename from pg_tables where schemaname = 'public'
  loop
    execute format('alter table %I enable row level security', t.tablename);
  end loop;
end $$;

-- PROFILES: cada uno lo suyo; admin todo.
create policy profiles_select_own on profiles for select
  using (id = auth.uid() or is_admin());
create policy profiles_update_own on profiles for update
  using (id = auth.uid() and deleted_at is null)
  with check (id = auth.uid() and role = (select role from profiles where id = auth.uid())); -- rol inmutable por el usuario

-- CANDIDATE_PROFILES: dueño CRUD; empresas VERIFICADAS ven solo perfiles PUBLICADOS
-- (regla explícita de visibilidad) y sin bloqueo cruzado.
create policy cand_owner_all on candidate_profiles for all
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());
create policy cand_visible_to_verified_companies on candidate_profiles for select
  using (
    is_published
    and deleted_at is null
    and is_verified_company_member()
    and not are_blocked(profile_id, auth.uid())
  );
create policy cand_admin on candidate_profiles for all using (is_admin());

-- COMPANY_PROFILES: miembros gestionan; cualquiera autenticado ve empresas verificadas
-- (necesario para mostrar la empresa en una oferta).
create policy comp_member_select on company_profiles for select
  using (is_company_member(id) or (verification_status = 'approved' and deleted_at is null) or is_admin());
create policy comp_member_update on company_profiles for update
  using (exists (select 1 from company_members
                 where company_id = id and profile_id = auth.uid()
                   and member_role in ('owner','admin')));
create policy comp_insert on company_profiles for insert
  with check (created_by = auth.uid());

-- COMPANY_MEMBERS: miembros ven su empresa; owner/admin gestionan.
create policy cm_select on company_members for select
  using (is_company_member(company_id) or is_admin());
create policy cm_manage on company_members for insert
  with check (exists (select 1 from company_members
                      where company_id = company_members.company_id
                        and profile_id = auth.uid() and member_role in ('owner','admin')));
create policy cm_delete on company_members for delete
  using (exists (select 1 from company_members me
                 where me.company_id = company_members.company_id
                   and me.profile_id = auth.uid() and me.member_role in ('owner','admin')));

-- COMPANY_VERIFICATIONS: la empresa crea y consulta; solo admin resuelve.
create policy cv_company_insert on company_verifications for insert
  with check (is_company_member(company_id) and submitted_by = auth.uid());
create policy cv_company_select on company_verifications for select
  using (is_company_member(company_id) or is_admin());
create policy cv_admin_update on company_verifications for update
  using (is_admin());

-- VIDEOS: dueño CRUD; empresa ve el video si ve el contexto (perfil publicado o postulación a SU oferta).
create policy videos_owner_all on videos for all
  using (owner_profile_id = auth.uid())
  with check (owner_profile_id = auth.uid());
create policy videos_company_select on videos for select
  using (
    deleted_at is null and status = 'ready' and (
      exists (select 1 from candidate_profiles c
              where c.video_id = videos.id and c.is_published
                and is_verified_company_member()
                and not are_blocked(c.profile_id, auth.uid()))
      or exists (select 1 from job_applications a
                 join jobs j on j.id = a.job_id
                 where a.video_id = videos.id and is_company_member(j.company_id))
      or exists (select 1 from jobs j            -- video pitch de la propia oferta, visible a todos
                 where j.video_id = videos.id and j.status = 'active')
    )
  );
create policy videos_admin on videos for all using (is_admin());

-- TRANSCRIPTS: hereda la visibilidad del video.
create policy tr_select on transcripts for select
  using (exists (select 1 from videos v where v.id = transcripts.video_id)); -- RLS de videos ya filtró
  -- Nota: la subconsulta corre bajo las policies de videos ⇒ visible solo si el video es visible.

-- JOBS: ofertas activas visibles para cualquier autenticado; la empresa gestiona las suyas.
create policy jobs_public_select on jobs for select
  using ((status = 'active' and deleted_at is null) or is_company_member(company_id) or is_admin());
create policy jobs_company_write on jobs for insert
  with check (is_company_member(company_id));
create policy jobs_company_update on jobs for update
  using (is_company_member(company_id));

-- JOB_APPLICATIONS: candidato crea/ve/retira lo suyo; la empresa ve/gestiona postulaciones a SUS ofertas.
create policy app_candidate_insert on job_applications for insert
  with check (candidate_profile_id = candidate_id()
              and exists (select 1 from jobs j where j.id = job_id
                          and j.status = 'active' and j.deleted_at is null));
create policy app_candidate_select on job_applications for select
  using (candidate_profile_id = candidate_id());
create policy app_candidate_withdraw on job_applications for update
  using (candidate_profile_id = candidate_id())
  with check (status = 'withdrawn');
create policy app_company_select on job_applications for select
  using (exists (select 1 from jobs j where j.id = job_id and is_company_member(j.company_id)));
create policy app_company_update on job_applications for update
  using (exists (select 1 from jobs j where j.id = job_id and is_company_member(j.company_id)));
create policy app_admin on job_applications for all using (is_admin());

-- INVITATIONS: empresa emite y ve; candidato ve y responde las suyas.
create policy inv_company_insert on invitations for insert
  with check (is_company_member(company_id) and sent_by = auth.uid());
create policy inv_company_select on invitations for select
  using (is_company_member(company_id));
create policy inv_candidate_select on invitations for select
  using (candidate_profile_id = candidate_id());
create policy inv_candidate_respond on invitations for update
  using (candidate_profile_id = candidate_id())
  with check (status in ('viewed','accepted','declined'));

-- MATCHES: lectura por las dos partes; escritura solo service role (sin policy de insert/update).
create policy match_candidate_select on matches for select
  using (candidate_profile_id = candidate_id());
create policy match_company_select on matches for select
  using (exists (select 1 from jobs j where j.id = job_id and is_company_member(j.company_id)));

-- CONVERSATIONS y MESSAGES: solo participantes; blocks cortan visibilidad y escritura.
create policy conv_participants_select on conversations for select
  using (
    (candidate_profile_id = candidate_id() or is_company_member(company_id))
    and not are_blocked(
      (select profile_id from candidate_profiles c where c.id = candidate_profile_id),
      auth.uid())
  );
create policy msg_participants_select on messages for select
  using (deleted_at is null
         and exists (select 1 from conversations c where c.id = conversation_id)); -- RLS de conversations filtra
create policy msg_participants_insert on messages for insert
  with check (
    sender_profile_id = auth.uid()
    and exists (select 1 from conversations c where c.id = conversation_id)        -- soy participante no bloqueado
  );
create policy msg_mark_read on messages for update
  using (exists (select 1 from conversations c where c.id = conversation_id))
  with check (sender_profile_id <> auth.uid());   -- solo marcar leído lo ajeno

-- SAVED_JOBS: solo el candidato.
create policy saved_own on saved_jobs for all
  using (candidate_profile_id = candidate_id())
  with check (candidate_profile_id = candidate_id());

-- NOTIFICATIONS: dueño lee y marca leído; inserta el backend (service role).
create policy notif_owner_select on notifications for select using (profile_id = auth.uid());
create policy notif_owner_read on notifications for update
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());

-- PUSH_DEVICES: solo el dueño.
create policy push_own on push_devices for all
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());

-- NOTIFICATION_PREFS: solo el dueño gestiona sus preferencias.
create policy nprefs_own on notification_prefs for all
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());

-- REPORTS: denunciante crea y ve lo suyo; admin gestiona.
create policy rep_insert on reports for insert with check (reporter_profile_id = auth.uid());
create policy rep_select_own on reports for select
  using (reporter_profile_id = auth.uid() or is_admin());
create policy rep_admin_update on reports for update using (is_admin());

-- BLOCKS: el que bloquea gestiona sus bloqueos.
create policy blocks_own on blocks for all
  using (blocker_profile_id = auth.uid()) with check (blocker_profile_id = auth.uid());

-- MODERATION_ACTIONS y ADMIN_AUDIT_LOG: solo admin (audit log sin update/delete).
create policy mod_admin on moderation_actions for all using (is_admin());
create policy audit_admin_select on admin_audit_log for select using (is_admin());
create policy audit_admin_insert on admin_audit_log for insert with check (is_admin());
revoke update, delete on admin_audit_log from authenticated, anon;

-- CONSENTS: append-only. El usuario inserta (otorga, o revoca con granted=false) y consulta.
-- Sin policy de UPDATE/DELETE: la revocación es SIEMPRE una fila nueva (PRIVACY, Ley 25.326).
create policy consent_own_insert on consents for insert with check (profile_id = auth.uid());
create policy consent_own_select on consents for select
  using (profile_id = auth.uid() or is_admin());
revoke update, delete on consents from authenticated, anon;

-- PLANS / PLAN_PRICES: catálogo público de solo lectura; escribe admin/service role.
create policy plans_public on plans for select using (is_active or is_admin());
create policy prices_public on plan_prices for select using (true);
create policy plans_admin on plans for all using (is_admin());
create policy prices_admin on plan_prices for all using (is_admin());

-- SUBSCRIPTIONS: titular (o miembros de la empresa titular) leen; escribe SOLO service role.
create policy subs_select on subscriptions for select
  using (profile_id = auth.uid()
         or (company_id is not null and is_company_member(company_id))
         or is_admin());

-- PAYMENTS: NADIE escribe salvo service role (cero policies de insert/update/delete).
create policy pay_select on payments for select
  using (payer_profile_id = auth.uid()
         or (company_id is not null and is_company_member(company_id))
         or is_admin());
revoke insert, update, delete on payments from authenticated, anon;

-- PAYMENT_EVENTS: exclusivo service role (ninguna policy; RLS habilitado bloquea todo lo demás).
revoke all on payment_events from authenticated, anon;

-- RECONCILE_LOG: escribe solo service role (job de reconciliación); admin consulta.
create policy reconcile_admin_select on reconcile_log for select using (is_admin());
revoke insert, update, delete on reconcile_log from authenticated, anon;

-- AI_USAGE: dueño ve lo suyo, admin todo; escribe service role.
create policy ai_select on ai_usage for select
  using (profile_id = auth.uid() or is_admin());

-- AI_PRICING: catálogo interno; admin gestiona, las Edge Functions lo leen con service role.
create policy ai_pricing_admin on ai_pricing for all using (is_admin());

-- SECTORS: catálogo público de solo lectura (como geo); escribe admin/service role.
create policy sectors_read on sectors for select using (true);
create policy sector_tr_read on sector_translations for select using (true);
create policy sectors_admin on sectors for all using (is_admin());
create policy sector_tr_admin on sector_translations for all using (is_admin());

-- GEO_*: lectura pública (incluso anon para el onboarding), sin escritura.
create policy geo_prov_read on geo_provincias for select using (true);
create policy geo_loc_read on geo_localidades for select using (true);
create policy geo_bar_read on geo_barrios for select using (true);

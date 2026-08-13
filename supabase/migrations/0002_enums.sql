-- Generado desde docs/DATA_MODEL.md (fuente de verdad; §8 define el orden).
-- No editar sin actualizar el documento. Bloque A: T-005/T-006/T-007.

create type user_role as enum ('candidate','company','admin');
create type verification_status as enum ('pending','in_review','approved','rejected');
create type company_member_role as enum ('owner','admin','recruiter','viewer');
create type video_status as enum ('uploading','processing','ready','failed','expired','removed');
create type video_purpose as enum ('candidate_presentation','job_pitch','application_answer');
create type job_status as enum ('draft','active','paused','expired','closed');
create type work_mode as enum ('presencial','hibrido','remoto');
create type contract_type as enum ('relacion_dependencia','monotributo','plazo_fijo','temporal','pasantia','freelance');
create type jornada_type as enum ('full_time','part_time','por_turnos','fin_de_semana','por_horas');
create type experience_level as enum ('sin_experiencia','hasta_1_anio','1_a_3_anios','3_a_5_anios','mas_de_5_anios');
create type availability_type as enum ('inmediata','en_1_semana','en_2_semanas','en_1_mes','a_convenir');
create type salary_period as enum ('mensual','anual','por_hora');
create type application_status as enum ('submitted','viewed','shortlisted','interview','offer','rejected','withdrawn','hired');  -- canónica: UX_FLOWS.md §12 (ver equivalencias ES↔EN en §2.3)
create type invitation_status as enum ('sent','viewed','accepted','declined','expired');
create type match_source as enum ('ai','rule','manual');
create type conversation_origin as enum ('application','invitation');
create type notification_type as enum ('application_update','new_application','invitation','message','job_expiring','video_expiring','verification_update','payment','system');
create type push_platform as enum ('ios','android','web');
create type report_target as enum ('profile','company','job','video','message');
create type report_status as enum ('open','in_review','resolved','dismissed');
create type moderation_action_type as enum ('warning','content_removed','account_suspended','account_banned','account_reinstated');
create type consent_type as enum ('data_processing','video_profile_publication','ai_features','ai_training','age_declaration');  -- 1:1 con PRIVACY.md §4 (mapeo a toggles A/B/C en §2.7)
create type plan_audience as enum ('candidate','company');
create type billing_period as enum ('monthly','quarterly','yearly');
create type subscription_status as enum ('trialing','active','past_due','paused','canceled','expired');
create type payment_provider as enum ('mercado_pago');            -- extensible
create type payment_status as enum ('pending','in_process','approved','rejected','refunded','partially_refunded','charged_back','cancelled');
create type ai_feature as enum ('transcription','matching','job_description','moderation','profile_summary');

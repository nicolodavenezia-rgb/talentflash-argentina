-- Bloque D (T-022): bucket de avatares PRIVADO con thumbnail y URLs firmadas.
--
-- DECISIÓN (contradicción documental resuelta): ARCHITECTURE.md §3.5 describía
-- `avatars` como bucket público. Prevalecen el criterio verificable de T-022
-- ("URL firmada vencida no sirve el archivo") y la minimización de PRIVACY/
-- SECURITY: el bucket es privado, `profiles.avatar_url` guarda SOLO el path
-- canónico (jamás una URL firmada) y toda lectura pasa por URLs firmadas de
-- TTL corto que el cliente renueva. ARCHITECTURE.md queda actualizado.
--
-- Layout de objetos (namespace por candidate_profile_id, NO por auth.uid():
-- así la proyección de T-024 nunca expone el id de auth del candidato):
--   avatars/<candidate_profile_id>/avatar.jpg   (512 px máx, re-encodeado)
--   avatars/<candidate_profile_id>/thumb.jpg    (128×128 cuadrado)
-- Nombres estables: reemplazar sobreescribe los mismos objetos, sin huérfanos.
--
-- Escrituras: NINGUNA policy de INSERT/UPDATE/DELETE para authenticated.
-- Todo alta/reemplazo/borrado pasa por la Edge Function `avatar`, que valida
-- magic bytes, decodifica, re-encodea (EXIF fuera, orientación aplicada),
-- genera el thumbnail y escribe con el service role del runtime local. El
-- original crudo del cliente jamás toca el bucket.

-- ---------------------------------------------------------------------------
-- Restauración del grant estándar de Supabase a `service_role` (hueco de
-- fundación descubierto acá). 0018 concedió DML a `authenticated` sobre todas
-- las tablas de `public` pero nunca a `service_role`, que quedó solo con
-- TRUNCATE/REFERENCES/TRIGGER. `service_role` bypassa RLS y es, por diseño
-- (ARCHITECTURE.md §3.2), el ÚNICO camino de escritura server-side de las
-- Edge Functions (pagos, webhooks, y desde este bloque el avatar) — sin estos
-- privilegios de tabla toda función server-side falla con "permission denied".
-- La Edge Function `avatar` es el primer consumidor real, por eso el fix vive
-- acá. La key jamás está en el cliente (secret del runtime; lo verifica el
-- test de arquitectura), así que ampliar `service_role` no expone superficie.
grant select, insert, update, delete
  on all tables in schema public to service_role;
-- Tablas futuras: que ninguna otra Edge Function vuelva a chocar con esto.
alter default privileges in schema public
  grant select, insert, update, delete on tables to service_role;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'avatars',
  'avatars',
  false,                                   -- privado: solo URLs firmadas
  2097152,                                 -- 2 MiB, límite conservador (T-022)
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do nothing;

-- Lectura fail-closed, testeable por pgTAP: dueño del perfil, empresa que
-- puede ver al candidato (misma regla única que la proyección de T-024) o
-- admin. Un path malformado nunca revienta la query: devuelve false.
create or replace function public.can_read_avatar_object(p_name text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  folder text;
  cid uuid;
begin
  if auth.uid() is null then
    return false;
  end if;
  folder := (storage.foldername(p_name))[1];
  if folder is null
     or folder !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    return false;
  end if;
  cid := folder::uuid;

  if exists (
    select 1 from public.candidate_profiles cp
    where cp.id = cid and cp.profile_id = auth.uid() and cp.deleted_at is null
  ) then
    return true;
  end if;

  return public.is_admin() or public.company_can_view_candidate(cid);
end $$;

revoke all on function public.can_read_avatar_object(text) from public;
grant execute on function public.can_read_avatar_object(text) to authenticated, anon;

create policy avatars_read on storage.objects for select
  using (bucket_id = 'avatars' and public.can_read_avatar_object(name));

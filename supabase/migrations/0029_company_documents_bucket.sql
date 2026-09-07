-- Bloque E — T-028: bucket PRIVADO para la constancia de ARCA.
--
-- Mismo criterio que `avatars` (0024): bucket privado, la columna guarda SOLO
-- el path canónico y toda lectura pasa por una URL firmada de vida corta.
-- Diferencias con avatares, y por qué:
--
--   - Acá SÍ hay policies de escritura para `authenticated`. En avatares todo
--     pasa por la Edge Function `avatar` porque hay que re-encodear la imagen
--     (EXIF fuera, thumbnail). Una constancia es un documento que se guarda tal
--     cual: no hay transformación que justifique un salto por service_role, y
--     meter un PDF por una Edge Function solo para copiarlo agregaría una
--     superficie con la key secreta sin ganar nada. El control queda en la
--     policy, que es lo que pgTAP puede probar.
--
--   - El namespace es el `company_id`, y el nombre del archivo es fijo. Las dos
--     mitades del path las decide el servidor: la carpeta la resuelve
--     `private.caller_company()` desde `auth.uid()` y el nombre sale de la
--     lista cerrada de extensiones de 0028.
--
--     PRECISIÓN, porque la diferencia importa: el path NO es secreto ni difícil
--     de fabricar. La forma es fija y el `company_id` de una empresa aprobada lo
--     lee cualquiera por `comp_member_select` (0015). Un atacante arma
--     `<uuid ajeno>/constancia-arca.pdf` en dos segundos. Lo que sostiene la
--     seguridad NO es que el path sea difícil de adivinar, sino que la policy
--     revalida la membresía contra `auth.uid()` en cada acceso: un path
--     fabricado no sirve para nada. `company_document_upload_path()` es
--     comodidad para el cliente, no un control. Si alguna vez aparece un camino
--     que confíe en que el path es impredecible —una URL semipública, un
--     endpoint que acepte el path del cliente sin revalidar—, ese camino es
--     inseguro por su cuenta, no por esta migración.
--
-- Límites: 5 MiB y una lista cerrada de MIME. Una constancia de ARCA es un PDF
-- de dos páginas o una foto; 5 MiB es holgado y a la vez acota el daño de un
-- upload abusivo. El límite lo aplica storage antes de que el objeto exista, así
-- que no depende de que el cliente se porte bien.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'company-docs',
  'company-docs',
  false,                                   -- privado: solo URLs firmadas
  5242880,                                 -- 5 MiB
  array['application/pdf', 'image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- Quién puede LEER un objeto.
--
-- Dos caminos, y ninguno acepta un path que no tenga la forma exacta
-- `<uuid>/constancia-arca.<ext>`:
--
--   a) integrar la empresa dueña de la carpeta (cualquier member_role: el
--      equipo tiene que poder ver qué se mandó);
--   b) revisar verificaciones, que es rol admin + AAL2.
--
-- El caso (b) pide segundo factor a propósito: mirar la constancia ES parte de
-- la revisión, y sería incoherente exigir AAL2 para aprobar pero no para leer
-- el documento con el que se aprueba. Un admin sin AAL2 no ve el documento de
-- una empresa que no integra, ni aunque conozca el UUID.
--
-- Fail-closed: sin sesión, con un path raro o con una carpeta que no es un
-- UUID, devuelve false y la policy no deja pasar nada.
-- ---------------------------------------------------------------------------

create or replace function public.can_read_company_document(p_name text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  cid uuid;
begin
  if auth.uid() is null then
    return false;
  end if;
  cid := private.company_document_path_company(p_name);
  if cid is null then
    return false;
  end if;
  if public.is_company_member(cid) then
    return true;
  end if;
  return public.is_admin() and private.caller_is_aal2();
end $$;

-- ---------------------------------------------------------------------------
-- Quién puede ESCRIBIR (crear, reemplazar o borrar) un objeto.
--
-- Solo el owner de ESA empresa. Un recruiter o un viewer pueden mirar la
-- constancia pero no cambiarla, igual que no pueden pedir la verificación
-- (0028). Un admin de plataforma tampoco escribe acá: revisar es leer y
-- decidir, nunca sustituir la prueba que mandó la empresa.
--
-- `is_company_owner` ya filtra `company_profiles.deleted_at`, así que una
-- empresa dada de baja deja de poder escribir sin ninguna comprobación extra.
-- ---------------------------------------------------------------------------

create or replace function public.can_write_company_document(p_name text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  cid uuid;
begin
  if auth.uid() is null then
    return false;
  end if;
  cid := private.company_document_path_company(p_name);
  if cid is null then
    return false;
  end if;
  return public.is_company_owner(cid);
end $$;

revoke all on function public.can_read_company_document(text) from public;
revoke all on function public.can_write_company_document(text) from public;
grant execute on function public.can_read_company_document(text) to authenticated, anon;
grant execute on function public.can_write_company_document(text) to authenticated, anon;

-- ---------------------------------------------------------------------------
-- Policies. `to authenticated` en todas: `anon` no tiene ningún camino acá, ni
-- siquiera el de evaluar la función (una policy sin `to` alcanza también al rol
-- anónimo, que es como quedó `avatars_read` en 0024).
--
-- UPDATE lleva USING y WITH CHECK: sin el WITH CHECK, quien puede escribir en
-- su carpeta podría renombrar el objeto hacia la carpeta de otra empresa.
-- ---------------------------------------------------------------------------

create policy company_docs_read on storage.objects for select to authenticated
  using (bucket_id = 'company-docs' and public.can_read_company_document(name));

create policy company_docs_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'company-docs' and public.can_write_company_document(name));

create policy company_docs_update on storage.objects for update to authenticated
  using (bucket_id = 'company-docs' and public.can_write_company_document(name))
  with check (bucket_id = 'company-docs' and public.can_write_company_document(name));

create policy company_docs_delete on storage.objects for delete to authenticated
  using (bucket_id = 'company-docs' and public.can_write_company_document(name));

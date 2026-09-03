// Tipos mínimos y explícitos para el bundle vendorizado de
// @supabase/supabase-js@2.49.4 (esm.sh/@supabase/supabase-js@2.49.4/es2022/).
//
// Los .d.ts oficiales que esm.sh anuncia por cabecera HTTP encadenan
// `@types/ws` y `@types/phoenix`, que a su vez exigen `npm:@types/node`: el
// edge runtime resolvería esa cadena por red al construir el grafo, que es
// justamente lo que este directorio evita. Este archivo declara SOLO el
// contrato que index.ts consume: dos tablas, un bucket y cinco operaciones.
// Cualquier otra tabla, bucket o método es un error de tipos, de modo que un
// uso nuevo obliga a ampliar esta declaración a conciencia. Las formas de
// respuesta replican las de supabase-js 2.49 (`{ data, error }`).
//
// Archivo escrito a mano: no proviene de esm.sh y no figura en manifest.json.

// --- Auth -------------------------------------------------------------------

/** Usuario de GoTrue: index.ts lee `id` y `app_metadata.role`. */
export interface AuthUser {
  id: string;
  app_metadata?: { role?: string; [key: string]: unknown };
  [key: string]: unknown;
}

export interface AuthError {
  message: string;
  status?: number;
}

export interface AuthUserResponse {
  data: { user: AuthUser | null };
  error: AuthError | null;
}

export interface SupabaseAuthClient {
  /** Valida el JWT contra Auth y devuelve el usuario, o error. */
  getUser(jwt?: string): Promise<AuthUserResponse>;
}

// --- PostgREST ---------------------------------------------------------------

export interface PostgrestError {
  message: string;
  code?: string;
  details?: string | null;
  hint?: string | null;
}

export interface PostgrestResponse {
  data: unknown;
  error: PostgrestError | null;
}

export interface PostgrestMaybeSingleResponse<Row> {
  data: Row | null;
  error: PostgrestError | null;
}

/** Builder encadenable; `await` directo resuelve `{ data, error }`. */
export interface PostgrestFilterBuilder<Row> extends PromiseLike<PostgrestResponse> {
  eq(column: string, value: string | number | boolean | null): PostgrestFilterBuilder<Row>;
  is(column: string, value: null | boolean): PostgrestFilterBuilder<Row>;
  maybeSingle(): Promise<PostgrestMaybeSingleResponse<Row>>;
}

export interface PostgrestQueryBuilder<Row> {
  select(columns: string): PostgrestFilterBuilder<Row>;
  update(values: Partial<Row>): PostgrestFilterBuilder<Row>;
}

/** Columnas que index.ts lee o escribe; no es el esquema completo. */
export interface CandidateProfileRow {
  id: string;
}

export interface ProfileRow {
  avatar_url: string | null;
}

export interface Tables {
  candidate_profiles: CandidateProfileRow;
  profiles: ProfileRow;
}

// --- Storage -----------------------------------------------------------------

export interface StorageError {
  message: string;
  statusCode?: string;
}

export interface StorageResponse {
  data: unknown;
  error: StorageError | null;
}

export interface StorageUploadOptions {
  contentType?: string;
  upsert?: boolean;
  cacheControl?: string;
}

export interface StorageFileApi {
  upload(
    path: string,
    body: Uint8Array | ArrayBuffer | Blob,
    options?: StorageUploadOptions,
  ): Promise<StorageResponse>;
  remove(paths: string[]): Promise<StorageResponse>;
}

export interface StorageClient {
  from(bucket: "avatars"): StorageFileApi;
}

// --- Cliente -----------------------------------------------------------------

export interface SupabaseClientOptions {
  auth?: {
    persistSession?: boolean;
    autoRefreshToken?: boolean;
    detectSessionInUrl?: boolean;
  };
}

export interface SupabaseClient {
  auth: SupabaseAuthClient;
  storage: StorageClient;
  from<T extends keyof Tables>(table: T): PostgrestQueryBuilder<Tables[T]>;
}

export declare function createClient(
  supabaseUrl: string,
  supabaseKey: string,
  options?: SupabaseClientOptions,
): SupabaseClient;

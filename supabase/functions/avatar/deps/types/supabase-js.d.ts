// Declaración mínima de tipos para el bundle vendorizado de
// @supabase/supabase-js@2.49.4 (esm.sh/.../denonext/supabase-js.mjs).
//
// Los .d.ts oficiales que esm.sh anuncia por cabecera HTTP encadenan
// `@types/ws` y `@types/phoenix`, que a su vez exigen `npm:@types/node`: el
// edge runtime resolvería esa cadena por red al construir el grafo, que es
// justamente lo que este directorio evita. Este archivo declara solo el
// contrato que index.ts consume, sin depender de nada externo. Si en algún
// momento se necesita el cliente tipado, hay que vendorizar los .d.ts y su
// cadena de tipos completa.
//
// Archivo escrito a mano: no proviene de esm.sh y no figura en manifest.json.

// deno-lint-ignore no-explicit-any
export type SupabaseClient = any;

export declare function createClient(
  supabaseUrl: string,
  supabaseKey: string,
  options?: Record<string, unknown>,
): SupabaseClient;

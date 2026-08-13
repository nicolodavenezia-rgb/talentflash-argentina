# Edge Functions

Vacío a propósito en el Bloque A. El catálogo previsto (ARCHITECTURE.md §3):
`ai-proxy`, `mp-webhook`, `mp-reconcile`, `stream-webhook`, `verify-cuit`,
`export-data`, `delete-account`, `moderation-queue`.

Cada función llega con su bloque del ROADMAP (B+). Regla transversal:
ningún secreto en el cliente — las API keys viven solo acá (env vars de
Supabase) y en GitHub Secrets.

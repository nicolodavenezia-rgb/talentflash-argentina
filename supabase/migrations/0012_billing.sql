-- Generado desde docs/DATA_MODEL.md (fuente de verdad; §8 define el orden).
-- No editar sin actualizar el documento. Bloque A: T-005/T-006/T-007.

create table plans (
  id         uuid primary key default gen_random_uuid(),
  code       text not null unique,              -- 'candidate_free','company_starter','company_pro'
  audience   plan_audience not null,
  name       text not null,
  features   jsonb not null default '{}',
  limits     jsonb not null default '{}',       -- {active_jobs: 3, invitations_month: 50,...} (valores: propuesta a validar)
  is_active  boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table plan_prices (
  id            uuid primary key default gen_random_uuid(),
  plan_id       uuid not null references plans(id) on delete cascade,
  amount        numeric(12,2) not null check (amount >= 0),  -- montos: propuesta a validar, se cargan por seed/admin
  currency_code char(3) not null default 'ARS',
  country_code  char(2) not null default 'AR',
  billing_period billing_period not null default 'monthly',
  valid_from    timestamptz not null default now(),          -- vigencia
  valid_to      timestamptz,                                 -- null = vigente
  provider_price_id text,                                    -- id del plan en Mercado Pago
  created_at    timestamptz not null default now(),
  unique (plan_id, currency_code, country_code, billing_period, valid_from)
);

create table subscriptions (
  id            uuid primary key default gen_random_uuid(),
  profile_id    uuid references profiles(id) on delete cascade,      -- suscriptor candidato
  company_id    uuid references company_profiles(id) on delete cascade, -- o empresa
  plan_id       uuid not null references plans(id),
  plan_price_id uuid not null references plan_prices(id),
  status        subscription_status not null default 'trialing',
  provider      payment_provider not null default 'mercado_pago',
  provider_subscription_id text unique,          -- preapproval_id MP
  current_period_start timestamptz not null,
  current_period_end   timestamptz not null,
  cancel_at_period_end boolean not null default false,
  trial_end     timestamptz,
  canceled_at   timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  check (num_nonnulls(profile_id, company_id) = 1)   -- exactamente un titular
);

-- Cubre 1:1 los campos mínimos de SPEC §8 (validación hecha; ver mapeo debajo).

create table payments (
  id                  uuid primary key default gen_random_uuid(),
  subscription_id     uuid references subscriptions(id) on delete set null,
  payer_profile_id    uuid not null references profiles(id),
  company_id          uuid references company_profiles(id),
  provider            payment_provider not null default 'mercado_pago',
  provider_customer_id text,                     -- §8: id del pagador en el proveedor (payer.id de MP)
  provider_payment_id text not null,             -- §8: payment.id de MP
  status              payment_status not null default 'pending',
  status_detail       text,                      -- status_detail crudo de MP
  amount              numeric(12,2) not null,    -- §8: monto cobrado
  gross_amount        numeric(12,2),             -- §8: bruto antes de fees/impuestos (transaction_amount de MP)
  currency_code       char(3) not null default 'ARS',
  country_code        char(2) not null default 'AR',
  description         text,
  payment_method      text,                      -- 'credit_card','account_money',...
  installments        integer,
  provider_fee        numeric(12,2),             -- §8: comisión del proveedor (fee_details de MP)
  estimated_taxes     numeric(12,2),             -- §8: impuestos estimados (taxes de MP)
  net_amount          numeric(12,2),             -- §8: neto acreditado
  billing_period_start timestamptz,              -- §8: inicio del período facturado
  billing_period_end   timestamptz,              -- §8: fin del período facturado
  external_reference  text,                      -- nuestro id de correlación
  paid_at             timestamptz,
  refunded_at         timestamptz,
  refund_amount       numeric(12,2),
  failure_code        text,
  failure_reason      text,
  raw                 jsonb not null default '{}',
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  unique (provider, provider_payment_id)
);

-- Idempotencia de webhooks: cada evento del proveedor se registra una sola vez.

create table payment_events (
  id                 uuid primary key default gen_random_uuid(),
  provider           payment_provider not null default 'mercado_pago',
  provider_event_id  text not null,
  event_type         text not null,              -- 'payment.updated','subscription_preapproval',...
  payment_id         uuid references payments(id),
  payload            jsonb not null,
  processed_at       timestamptz,                -- null = pendiente/reintento
  error              text,
  received_at        timestamptz not null default now(),
  unique (provider, provider_event_id)           -- clave de idempotencia
);

-- Reconciliación periódica contra la API del proveedor (SPEC §8, ARCHITECTURE.md §7.3).
-- Append-only; escribe solo el service role desde el job programado.

create table reconcile_log (
  id               uuid primary key default gen_random_uuid(),
  provider         payment_provider not null default 'mercado_pago',
  period_start     timestamptz not null,
  period_end       timestamptz not null,
  payments_checked integer not null default 0,
  discrepancies    integer not null default 0,
  details          jsonb not null default '[]',  -- [{payment_id, campo, valor_local, valor_proveedor}]
  status           text not null default 'running',  -- 'running','ok','discrepancies','error'
  run_started_at   timestamptz not null default now(),
  run_finished_at  timestamptz
);

create table ai_usage (
  id            uuid primary key default gen_random_uuid(),
  profile_id    uuid references profiles(id) on delete set null,
  feature       ai_feature not null,
  model         text not null,
  input_tokens  integer not null default 0,
  output_tokens integer not null default 0,
  cost_usd      numeric(10,6) not null default 0,  -- calculado con ai_pricing vigente al momento del uso
  entity_type   text,                            -- 'video','job','candidate_profile'
  entity_id     uuid,
  created_at    timestamptz not null default now()
);

-- Precios de modelos de IA (ARCHITECTURE.md §5.4): nunca hardcodeados en Edge Functions.
-- Vigencia por rango; seed según SPEC §4: claude-fable-5 $10/$50, claude-sonnet-5 $3/$15,
-- claude-haiku-4-5 $1/$5 por MTok; Batch −50%; lecturas de caché ~0,1×.

create table ai_pricing (
  id                    uuid primary key default gen_random_uuid(),
  model                 text not null,           -- 'claude-fable-5','claude-sonnet-5','claude-haiku-4-5'
  input_usd_per_mtok    numeric(10,4) not null,
  output_usd_per_mtok   numeric(10,4) not null,
  batch_discount        numeric(4,3) not null default 0.500,   -- Batch API −50%
  cache_read_multiplier numeric(5,4) not null default 0.1000,  -- prompt caching ~0,1×
  valid_from            timestamptz not null default now(),
  valid_to              timestamptz,             -- null = vigente
  created_at            timestamptz not null default now(),
  unique (model, valid_from)
);

-- Catálogo de sectores localizable (ARCHITECTURE.md §8). Seed inicial: gastronomía y
-- hotelería; luego comercio, ventas, logística, depósitos (SPEC §2). Traducciones por
-- locale para la expansión es-UY/es-CL/es-CO/es-PE/pt-BR.

-- ============================================================
-- MIGRACIÓN 08 — Suscripciones Web Push
--
-- Guarda el endpoint y las claves de cada dispositivo del admin que
-- activó las notificaciones push. La función /api/push las usa con la
-- service_role key para enviar el aviso cuando entra un pedido.
--
-- El admin (authenticated) puede leer/escribir su suscripción.
-- anon no tiene acceso.
-- ============================================================

begin;

create table if not exists public.push_subscriptions (
  id bigserial primary key,
  endpoint text not null unique,
  p256dh text not null,
  auth text not null,
  user_agent text,
  created_at timestamptz not null default now(),
  last_seen_at timestamptz
);

create index if not exists push_subscriptions_created_idx
  on public.push_subscriptions (created_at desc);

alter table public.push_subscriptions enable row level security;

drop policy if exists "Push admin all" on public.push_subscriptions;
create policy "Push admin all"
  on public.push_subscriptions
  for all
  to authenticated
  using (true)
  with check (true);

revoke all on public.push_subscriptions from anon;
grant select, insert, update, delete on public.push_subscriptions to authenticated;
grant usage, select on sequence public.push_subscriptions_id_seq to authenticated;

commit;

-- Verificación
select column_name, data_type
from information_schema.columns
where table_schema = 'public' and table_name = 'push_subscriptions'
order by ordinal_position;

select policyname, cmd, roles
from pg_policies
where schemaname = 'public' and tablename = 'push_subscriptions';

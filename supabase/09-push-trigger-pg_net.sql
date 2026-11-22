-- ============================================================
-- MIGRACIÓN 09 — Aviso de pedido nuevo vía pg_net
--
-- Alternativa al Database Webhook del dashboard: un trigger AFTER INSERT
-- llama a la función de Vercel /api/push con pg_net.
--
-- ANTES DE EJECUTAR, reemplaza:
--   TU_DOMINIO   -> dominio de producción (ej: burger-app-julioapps.vercel.app)
--   TU_SECRETO   -> el mismo PUSH_WEBHOOK_SECRET de Vercel
--
-- Requiere:
--   - pg_net habilitado (Database -> Extensions -> pg_net, o el create de abajo)
--   - el deploy de producción con /api/push y sus variables de entorno
-- ============================================================

begin;

create extension if not exists pg_net;

create or replace function private.notify_new_order()
returns trigger
language plpgsql
security definer
set search_path = public, net, extensions
as $$
declare
  v_url    text := 'https://TU_DOMINIO/api/push';
  v_secret text := 'TU_SECRETO';
begin
  -- Si el push falla, el pedido NO debe fallar.
  begin
    perform net.http_post(
      url := v_url,
      body := jsonb_build_object(
        'type',   tg_op,
        'table',  'orders',
        'schema', 'public',
        'record', to_jsonb(new),
        'old_record', case when tg_op = 'UPDATE' then to_jsonb(old) else null end
      ),
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-webhook-secret', v_secret
      ),
      timeout_milliseconds := 5000
    );
  exception when others then
    raise warning 'No se pudo encolar la notificación push: %', sqlerrm;
  end;

  return new;
end;
$$;

drop trigger if exists trg_notify_new_order on public.orders;
create trigger trg_notify_new_order
after insert or update on public.orders
for each row execute function private.notify_new_order();

commit;

-- Verificación
select tgname
from pg_trigger
where tgname = 'trg_notify_new_order';

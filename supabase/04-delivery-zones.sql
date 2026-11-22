-- ============================================================
-- MIGRACIÓN 04 — Zonas de delivery
--
-- Agrega `delivery_config` a la tabla config. El admin lo edita desde
-- Negocio → Zonas de delivery y el cliente lo lee al abrir el checkout.
--
-- Formato:
--   { "zones": [ { "id": "casco", "name": "Casco Central", "fee": 2.00 }, ... ] }
--
-- Antes: backup. Es transaccional.
-- ============================================================

begin;

alter table public.config add column if not exists delivery_config jsonb;

-- Semilla opcional: si no hay zonas, crea las tres con la tarifa actual.
update public.config
set delivery_config = jsonb_build_object(
  'zones', jsonb_build_array(
    jsonb_build_object('id', 'casco',  'name', 'Casco Central', 'fee', coalesce(deliveryfee, 2)),
    jsonb_build_object('id', 'urbano', 'name', 'Urbano',        'fee', coalesce(deliveryfee, 2)),
    jsonb_build_object('id', 'extra',  'name', 'Extra Urbano',  'fee', coalesce(deliveryfee, 2))
  )
)
where id = 1 and delivery_config is null;

commit;

-- Verificación
select id, brand, deliveryfee, delivery_config
from public.config
where id = 1;

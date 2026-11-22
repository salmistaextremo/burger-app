-- ============================================================
-- MIGRACIÓN 05 — Delivery por distancia (2 tarifas)
--
-- Formato nuevo de delivery_config:
--   {
--     "store_lat": 10.4806,
--     "store_lng": -66.9036,
--     "threshold_km": 4,
--     "urban_fee": 2.00,
--     "extra_fee": 3.50
--   }
--
-- Conserva las tarifas de las zonas anteriores (Urbano / Extra Urbano) y
-- deja las coordenadas en NULL: el admin debe pegar la ubicación de la tienda.
--
-- Antes: backup. Es transaccional.
-- ============================================================

begin;

alter table public.config add column if not exists delivery_config jsonb;

update public.config
set delivery_config = jsonb_build_object(
  'store_lat',    delivery_config->'store_lat',
  'store_lng',    delivery_config->'store_lng',
  'threshold_km', coalesce((delivery_config->>'threshold_km')::numeric, 4),
  'urban_fee',    coalesce(
                    (delivery_config->>'urban_fee')::numeric,
                    (delivery_config->'zones'->1->>'fee')::numeric,
                    deliveryfee,
                    2
                  ),
  'extra_fee',    coalesce(
                    (delivery_config->>'extra_fee')::numeric,
                    (delivery_config->'zones'->2->>'fee')::numeric,
                    deliveryfee,
                    4
                  )
)
where id = 1;

commit;

-- Verificación
select id, deliveryfee, delivery_config
from public.config
where id = 1;

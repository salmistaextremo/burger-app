-- ============================================================
-- ENDURECIMIENTO 01 — cambios seguros e idempotentes
--
-- Qué hace:
--   1. Fija search_path en las RPC SECURITY DEFINER (evita secuestro de esquema).
--   2. Quita a `anon` permisos que no necesita (escritura en catálogo/config,
--      y todo acceso directo a `drivers`).
--
-- Qué NO hace (a propósito):
--   - No toca las políticas de `orders` (pendiente confirmar si otra app usa la BD).
--   - No cambia las contraseñas de repartidores (requiere las definiciones de las RPC).
--
-- Antes de ejecutar: backup del proyecto. Revisar. Es transaccional.
-- ============================================================

begin;

-- 1) search_path fijo en funciones SECURITY DEFINER
alter function public.verify_driver(text, text) set search_path = public, pg_temp;
alter function public.get_driver_orders(text, text) set search_path = public, pg_temp;
alter function public.mark_order_delivered(text, text, uuid) set search_path = public, pg_temp;
alter function public.get_order_by_code(text) set search_path = public, pg_temp;
alter function public.confirm_order_received(text) set search_path = public, pg_temp;
alter function public.rate_order(text, integer, text) set search_path = public, pg_temp;

-- 2) `anon` no necesita escribir catálogo/config ni tocar drivers
revoke all on public.drivers from anon;
revoke insert, update, delete, truncate, references, trigger on public.orders from anon;
revoke insert, update, delete, truncate, references, trigger on public.config from anon;
revoke insert, update, delete, truncate, references, trigger on public.categories from anon;
revoke insert, update, delete, truncate, references, trigger on public.products from anon;

commit;

-- Verificación: esto debe mostrar solo SELECT para anon en config/categories/products,
-- INSERT en orders, y NADA en drivers.
select table_name as tabla,
       string_agg(privilege_type, ', ' order by privilege_type) as privilegios_anon
from information_schema.role_table_grants
where table_schema = 'public'
  and grantee = 'anon'
  and table_name in ('config', 'categories', 'products', 'orders', 'drivers')
group by 1
order by 1;

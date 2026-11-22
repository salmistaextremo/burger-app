-- ============================================================
-- DIAGNÓSTICO 02 — lo que falta para la migración de contraseñas
-- SOLO LECTURA.
-- ============================================================

-- 1) Definiciones completas de las RPC (cuerpo y tipo de retorno).
--    Pega el resultado tal cual: es lo que permite reescribirlas sin romper nada.
select p.proname as funcion,
       pg_get_function_result(p.oid) as retorno,
       p.prosecdef as security_definer,
       p.proacl as permisos,
       pg_get_functiondef(p.oid) as definicion
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('verify_driver', 'get_driver_orders', 'mark_order_delivered',
                    'get_order_by_code', 'confirm_order_received', 'rate_order')
order by p.proname;

-- 2) Políticas de Storage con su condición real (bucket y carpeta)
select policyname as politica,
       cmd,
       roles,
       qual as usando,
       with_check as check
from pg_policies
where schemaname = 'storage'
order by policyname;

-- 3) ¿Quién está autenticado en el proyecto? (conteo; evita compartir correos)
select count(*) as usuarios_auth from auth.users;

-- 4) ¿Hay perfiles/roles de otra app?
select count(*) as perfiles,
       count(*) filter (where role::text in ('staff', 'admin', 'super_admin')) as staff
from public.profiles;

-- 5) Tablas del esquema public (para ver si la BD se comparte con otra app)
select table_name
from information_schema.tables
where table_schema = 'public' and table_type = 'BASE TABLE'
order by table_name;

-- 6) Columnas de orders (para la política de inserción)
select column_name, data_type, is_nullable
from information_schema.columns
where table_schema = 'public' and table_name = 'orders'
order by ordinal_position;

-- 7) ¿Existe order_items y la usa esta app? (indicio de app compartida)
select table_name
from information_schema.tables
where table_schema = 'public' and table_name in ('order_items', 'coupons', 'gift_cards', 'site_config')
order by 1;

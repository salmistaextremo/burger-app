-- ============================================================
-- DIAGNÓSTICO DE SEGURIDAD — DLV Food
-- SOLO LECTURA: no modifica nada.
-- Supabase → SQL Editor → New query → pegar → Run → copiar la celda JSON.
-- ============================================================

-- ------------------------------------------------------------
-- OPCIÓN A: una sola consulta que devuelve todo en un JSON
-- ------------------------------------------------------------
with
tbl as (
  select coalesce(jsonb_agg(jsonb_build_object(
           'tabla', c.relname,
           'rls', c.relrowsecurity,
           'forzada', c.relforcerowsecurity
         ) order by c.relname), '[]'::jsonb) as j
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind = 'r'
    and c.relname in ('config', 'categories', 'products', 'orders', 'drivers')
),
pol as (
  select coalesce(jsonb_agg(jsonb_build_object(
           'tabla', tablename, 'politica', policyname, 'roles', roles,
           'cmd', cmd, 'usando', qual, 'check', with_check
         ) order by tablename, policyname), '[]'::jsonb) as j
  from pg_policies
  where schemaname = 'public'
),
fn as (
  select coalesce(jsonb_agg(jsonb_build_object(
           'funcion', p.proname,
           'security_definer', p.prosecdef,
           'args', pg_get_function_identity_arguments(p.oid)
         ) order by p.proname), '[]'::jsonb) as j
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname in ('verify_driver', 'get_driver_orders', 'mark_order_delivered',
                      'get_order_by_code', 'confirm_order_received', 'rate_order')
),
gr as (
  select coalesce(jsonb_agg(jsonb_build_object(
           'tabla', table_name, 'rol', grantee, 'privilegios', privilegios
         ) order by table_name, grantee), '[]'::jsonb) as j
  from (
    select table_name, grantee,
           string_agg(privilege_type, ', ' order by privilege_type) as privilegios
    from information_schema.role_table_grants
    where table_schema = 'public'
      and grantee in ('anon', 'authenticated')
      and table_name in ('config', 'categories', 'products', 'orders', 'drivers')
    group by table_name, grantee
  ) x
),
dcols as (
  select coalesce(jsonb_agg(jsonb_build_object(
           'columna', column_name, 'tipo', data_type
         ) order by ordinal_position), '[]'::jsonb) as j
  from information_schema.columns
  where table_schema = 'public' and table_name = 'drivers'
),
buck as (
  select coalesce(jsonb_agg(jsonb_build_object(
           'bucket', b.id, 'publico', b."public"
         ) order by b.id), '[]'::jsonb) as j
  from storage.buckets b
),
srls as (
  select coalesce(jsonb_agg(jsonb_build_object(
           'tabla', c.relname, 'rls', c.relrowsecurity
         ) order by c.relname), '[]'::jsonb) as j
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'storage' and c.relname in ('objects', 'buckets')
),
spol as (
  select coalesce(jsonb_agg(jsonb_build_object(
           'tabla', tablename, 'politica', policyname, 'cmd', cmd, 'roles', roles
         ) order by tablename, policyname), '[]'::jsonb) as j
  from pg_policies
  where schemaname = 'storage'
)
select jsonb_pretty(jsonb_build_object(
  'resumen', jsonb_build_object(
    'rls_orders', (select relrowsecurity from pg_class where oid = to_regclass('public.orders')),
    'rls_drivers', (select relrowsecurity from pg_class where oid = to_regclass('public.drivers')),
    'anon_select_orders', exists(
      select 1 from information_schema.role_table_grants
      where table_schema = 'public' and table_name = 'orders'
        and grantee = 'anon' and privilege_type = 'SELECT'),
    'anon_select_drivers', exists(
      select 1 from information_schema.role_table_grants
      where table_schema = 'public' and table_name = 'drivers'
        and grantee = 'anon' and privilege_type = 'SELECT'),
    'drivers_tiene_password', exists(
      select 1 from information_schema.columns
      where table_schema = 'public' and table_name = 'drivers' and column_name = 'password'),
    'funciones_security_definer', (
      select coalesce(jsonb_agg(p.proname order by p.proname), '[]'::jsonb)
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.prosecdef
        and p.proname in ('verify_driver', 'get_driver_orders', 'mark_order_delivered',
                          'get_order_by_code', 'confirm_order_received', 'rate_order'))
  ),
  'tablas', (select j from tbl),
  'politicas_public', (select j from pol),
  'funciones', (select j from fn),
  'grants', (select j from gr),
  'drivers_columnas', (select j from dcols),
  'buckets', (select j from buck),
  'storage_rls', (select j from srls),
  'storage_politicas', (select j from spol)
)) as diagnostico;


-- ------------------------------------------------------------
-- OPCIÓN B: las mismas consultas por separado (si la A falla por permisos)
-- ------------------------------------------------------------

-- 1) ¿RLS activado en las tablas del negocio?
select c.relname as tabla,
       c.relrowsecurity as rls_habilitada,
       c.relforcerowsecurity as rls_forzada
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relkind = 'r'
  and c.relname in ('config', 'categories', 'products', 'orders', 'drivers')
order by 1;

-- 2) Políticas existentes (si no hay filas, no hay RLS efectivo)
select tablename, policyname, roles, cmd, qual, with_check
from pg_policies
where schemaname = 'public'
order by tablename, policyname;

-- 3) ¿Las RPC son SECURITY DEFINER?
select p.proname as funcion,
       p.prosecdef as security_definer,
       pg_get_function_identity_arguments(p.oid) as argumentos
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in (
    'verify_driver', 'get_driver_orders', 'mark_order_delivered',
    'get_order_by_code', 'confirm_order_received', 'rate_order'
  )
order by 1;

-- 4) Permisos de anon/authenticated sobre tablas sensibles
select table_name as tabla,
       grantee,
       string_agg(privilege_type, ', ' order by privilege_type) as privilegios
from information_schema.role_table_grants
where table_schema = 'public'
  and grantee in ('anon', 'authenticated')
  and table_name in ('config', 'categories', 'products', 'orders', 'drivers')
group by 1, 2
order by 1, 2;

-- 5) Columnas de drivers (¿sigue existiendo la contraseña en texto?)
select column_name, data_type
from information_schema.columns
where table_schema = 'public' and table_name = 'drivers'
order by ordinal_position;

-- 6) Buckets de Storage (¿comprobantes es público?)
select id, name, public
from storage.buckets
order by name;

-- 7) ¿RLS en storage.objects / buckets?
select c.relname, c.relrowsecurity
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'storage' and c.relname in ('objects', 'buckets');

-- 8) Políticas de Storage
select policyname, tablename, cmd, roles
from pg_policies
where schemaname = 'storage'
order by tablename, policyname;

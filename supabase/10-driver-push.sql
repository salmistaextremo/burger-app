-- ============================================================
-- MIGRACIÓN 10 — Push para repartidores
--
-- Agrega el rol a las suscripciones y las RPC que usa la app del
-- repartidor (que no inicia sesión con Supabase Auth, sino con token
-- propio). Las funciones validan el token de driver_sessions.
-- ============================================================

begin;

alter table public.push_subscriptions
  add column if not exists role text not null default 'admin';

alter table public.push_subscriptions
  add column if not exists driver_id uuid references public.drivers(id) on delete cascade;

create index if not exists push_subscriptions_role_idx
  on public.push_subscriptions (role);

-- Registrar/actualizar la suscripción del repartidor autenticado por token
create or replace function public.register_driver_push(
  driver_token text,
  sub_endpoint text,
  sub_p256dh text,
  sub_auth text,
  sub_user_agent text default null
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_driver uuid;
begin
  if driver_token is null or sub_endpoint is null or sub_p256dh is null or sub_auth is null then
    return false;
  end if;

  select ds.driver_id into v_driver
  from public.driver_sessions ds
  where ds.token = driver_token
    and ds.expires_at > now()
  limit 1;

  if v_driver is null then
    return false;
  end if;

  insert into public.push_subscriptions(endpoint, p256dh, auth, user_agent, role, driver_id, last_seen_at)
  values (sub_endpoint, sub_p256dh, sub_auth, left(coalesce(sub_user_agent, ''), 250), 'repartidor', v_driver, now())
  on conflict (endpoint) do update
    set p256dh = excluded.p256dh,
        auth = excluded.auth,
        user_agent = excluded.user_agent,
        role = 'repartidor',
        driver_id = excluded.driver_id,
        last_seen_at = now();

  return true;
end;
$$;

-- Quitar la suscripción al cerrar sesión
create or replace function public.unregister_driver_push(
  driver_token text,
  sub_endpoint text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_driver uuid;
begin
  select ds.driver_id into v_driver
  from public.driver_sessions ds
  where ds.token = driver_token
    and ds.expires_at > now()
  limit 1;

  if v_driver is null or sub_endpoint is null then
    return false;
  end if;

  delete from public.push_subscriptions
  where endpoint = sub_endpoint
    and role = 'repartidor'
    and driver_id = v_driver;

  return found;
end;
$$;

commit;

-- Verificación
select column_name, data_type
from information_schema.columns
where table_schema = 'public' and table_name = 'push_subscriptions'
order by ordinal_position;

select proname
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and proname in ('register_driver_push', 'unregister_driver_push');

-- ============================================================
-- MIGRACIÓN 03 — Contraseñas de repartidores y sesiones
--
-- Qué hace:
--   1. Agrega `password_hash` y migra las contraseñas actuales con bcrypt.
--   2. Un trigger convierte cualquier `password` que se escriba en hash y
--      borra el texto plano (así el admin sigue funcionando sin cambios).
--   3. Crea `driver_sessions` (token con expiración) y `login_attempts`
--      (límite de 8 intentos fallidos cada 15 minutos).
--   4. Reescribe las RPC: el segundo parámetro (`driver_password`) pasa a ser
--      el TOKEN de sesión. Las firmas no cambian.
--
-- ORDEN DE DESPLIEGUE:
--   1) Desplegar primero el código nuevo (repartidor.html).
--   2) Ejecutar esta migración.
--   3) Todos los repartidores deben cerrar sesión y volver a entrar una vez.
--
-- Antes: backup. Es transaccional.
-- ============================================================

begin;

create schema if not exists private;
create schema if not exists extensions;
set local search_path = public, extensions;

-- pgcrypto para crypt()/gen_salt() (en Supabase suele estar en `extensions`)
create extension if not exists pgcrypto with schema extensions;

-- 1) Columna de hash
alter table public.drivers add column if not exists password_hash text;

-- El trigger vacía `password`; si la columna era NOT NULL, hay que permitir NULL.
alter table public.drivers alter column password drop not null;

-- 2) Migrar contraseñas existentes
update public.drivers
set password_hash = crypt(password, gen_salt('bf', 10))
where password is not null
  and password <> ''
  and password_hash is null;

-- 3) Trigger: password -> hash, y nunca se guarda el texto plano
create or replace function private.hash_driver_password()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if new.password is not null and new.password <> '' then
    new.password_hash := crypt(new.password, gen_salt('bf', 10));
  elsif tg_op = 'UPDATE' then
    new.password_hash := old.password_hash;
  end if;
  new.password := null;
  return new;
end;
$$;

drop trigger if exists trg_hash_driver_password on public.drivers;
create trigger trg_hash_driver_password
before insert or update on public.drivers
for each row execute function private.hash_driver_password();

-- 4) Borrar el texto plano que quedaba
update public.drivers set password = null where password is not null;

-- 5) Sesiones de repartidor
create table if not exists public.driver_sessions (
  token text primary key default (gen_random_uuid()::text),
  driver_id uuid not null references public.drivers(id) on delete cascade,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  last_used_at timestamptz
);
create index if not exists driver_sessions_driver_id_idx on public.driver_sessions(driver_id);
alter table public.driver_sessions enable row level security;
revoke all on public.driver_sessions from anon, authenticated;

-- 6) Intentos de login (límite de fuerza bruta)
create table if not exists public.login_attempts (
  id bigserial primary key,
  email text not null,
  success boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists login_attempts_email_time_idx on public.login_attempts (lower(email), created_at);
alter table public.login_attempts enable row level security;
revoke all on public.login_attempts from anon, authenticated;

-- 7) verify_driver: valida hash, limita intentos y devuelve token
drop function if exists public.verify_driver(text, text);
create function public.verify_driver(driver_email text, driver_password text)
returns table(id uuid, name text, email text, active boolean, token text)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  d public.drivers%rowtype;
  v_token text;
  v_fails int;
  v_ok boolean := false;
begin
  if driver_email is null or driver_password is null then
    return;
  end if;

  select count(*) into v_fails
  from public.login_attempts la
  where lower(la.email) = lower(driver_email)
    and la.success = false
    and la.created_at > now() - interval '15 minutes';

  -- Mismo mensaje que credenciales incorrectas: no revelamos el bloqueo.
  if v_fails >= 8 then
    return;
  end if;

  select * into d
  from public.drivers dr
  where lower(dr.email) = lower(driver_email)
  limit 1;

  if found
     and d.active = true
     and d.password_hash is not null
     and d.password_hash = crypt(driver_password, d.password_hash) then
    v_ok := true;
  end if;

  insert into public.login_attempts(email, success)
  values (lower(driver_email), v_ok);

  if not v_ok then
    return;
  end if;

  insert into public.driver_sessions(driver_id, expires_at)
  values (d.id, now() + interval '7 days')
  returning token into v_token;

  return query select d.id, d.name, d.email, d.active, v_token;
end;
$$;

-- 8) get_driver_orders: ahora recibe token
create or replace function public.get_driver_orders(driver_email text, driver_password text)
returns setof public.orders
language plpgsql
security definer
set search_path = public
as $$
begin
  if exists (
    select 1
    from public.driver_sessions s
    join public.drivers d on d.id = s.driver_id
    where lower(d.email) = lower(driver_email)
      and s.token = driver_password
      and s.expires_at > now()
      and d.active = true
  ) then
    update public.driver_sessions
    set last_used_at = now()
    where token = driver_password;

    return query
    select * from public.orders
    where status in ('camino', 'listo')
    order by created_at;
  end if;
end;
$$;

-- 9) mark_order_delivered: valida token
create or replace function public.mark_order_delivered(driver_email text, driver_password text, order_uuid uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1
    from public.driver_sessions s
    join public.drivers d on d.id = s.driver_id
    where lower(d.email) = lower(driver_email)
      and s.token = driver_password
      and s.expires_at > now()
      and d.active = true
  ) then
    return false;
  end if;

  update public.orders set status = 'entregado' where id = order_uuid;
  return found;
end;
$$;

-- 10) confirm_order_received: solo pedidos entregados, y devuelve si actualizó
create or replace function public.confirm_order_received(order_code text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.orders
  set client_confirmed = true
  where upper(code) = upper(order_code)
    and status = 'entregado';
  return found;
end;
$$;

-- 11) rate_order: valida rango y estado
create or replace function public.rate_order(order_code text, order_rating integer, order_review text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if order_rating is null or order_rating < 1 or order_rating > 5 then
    return false;
  end if;

  update public.orders
  set rating = order_rating, review_text = order_review
  where upper(code) = upper(order_code)
    and status = 'entregado';
  return found;
end;
$$;

-- 12) driver_logout: revoca el token al cerrar sesión
create or replace function public.driver_logout(driver_token text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.driver_sessions where token = driver_token;
  return found;
end;
$$;

commit;

-- Verificación
select column_name, data_type
from information_schema.columns
where table_schema = 'public' and table_name = 'drivers'
order by ordinal_position;

select count(*) as repartidores_con_hash
from public.drivers
where password_hash is not null;

select count(*) as con_password_plano
from public.drivers
where password is not null;

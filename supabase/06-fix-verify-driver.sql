-- ============================================================
-- FIX 06 — verify_driver: referencia ambigua a "email"
--
-- Error original: 42702 "column reference email is ambiguous".
-- La función declaraba una columna de salida `email` y el cuerpo usaba
-- `email` sin calificar en las consultas. Se califican las columnas.
--
-- Ejecutar después de 03-driver-auth.sql. Es idempotente.
-- ============================================================

begin;

create or replace function public.verify_driver(driver_email text, driver_password text)
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

  insert into public.driver_sessions as ds (driver_id, expires_at)
  values (d.id, now() + interval '7 days')
  returning ds.token into v_token;

  return query select d.id, d.name, d.email, d.active, v_token;
end;
$$;

commit;

-- Recargar la caché de esquema de PostgREST para que tome la función nueva
notify pgrst, 'reload schema';

-- Verificación
select p.proname, pg_get_function_result(p.oid) as retorno
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'verify_driver';

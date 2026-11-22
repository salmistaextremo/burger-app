-- ============================================================
-- MIGRACIÓN 07 — Validación de pedidos en la base de datos
--
-- Refuerza del lado del servidor las mismas reglas del formulario:
--   - código A-XXXX / A-XXXXXX
--   - tipo delivery/pickup y estado inicial 'recibido'
--   - total >= 0
--   - nombre 2..60, letras/acentos/espacios/'./-
--   - teléfono 10..12 dígitos (58... o 0...)
--   - referencia <= 120
--   - delivery: zona y comprobante obligatorios
--   - items no vacío
--
-- Solo aplica a pedidos NUEVOS (BEFORE INSERT). No valida ni bloquea
-- pedidos antiguos ni las actualizaciones de estado del admin.
-- ============================================================

begin;

create schema if not exists private;

create or replace function private.validate_order_insert()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_name   text;
  v_phone  text;
  v_digits text;
  v_ref    text;
begin
  if new.code is null or new.code !~ '^A-[A-Z0-9]{4,8}$' then
    raise exception 'Código de pedido inválido (formato A-XXXX o A-XXXXXX)'
      using errcode = '23514';
  end if;

  if new.type is null or new.type not in ('delivery', 'pickup') then
    raise exception 'Tipo de pedido inválido'
      using errcode = '23514';
  end if;

  if new.status is distinct from 'recibido' then
    raise exception 'Un pedido nuevo debe iniciar en estado "recibido"'
      using errcode = '23514';
  end if;

  if new.total is null or new.total < 0 then
    raise exception 'Total del pedido inválido'
      using errcode = '23514';
  end if;

  if new.customer is null then
    raise exception 'Faltan los datos del cliente'
      using errcode = '23514';
  end if;

  v_name := btrim(regexp_replace(coalesce(new.customer->>'name', ''), '[[:space:]]+', ' ', 'g'));
  if length(v_name) < 2 or length(v_name) > 60
     or v_name !~ '^[A-Za-zÁÉÍÓÚÜÑáéíóúüñ'' .-]+$' then
    raise exception 'Nombre del cliente inválido'
      using errcode = '23514';
  end if;

  v_phone := coalesce(new.customer->>'phone', '');
  if v_phone !~ '^[0-9+() .-]+$' then
    raise exception 'El teléfono contiene caracteres inválidos'
      using errcode = '23514';
  end if;

  v_digits := regexp_replace(v_phone, '[^0-9]', '', 'g');
  if length(v_digits) < 10 or length(v_digits) > 12 then
    raise exception 'Teléfono inválido: deben ser entre 10 y 12 dígitos'
      using errcode = '23514';
  end if;
  if length(v_digits) = 12 and left(v_digits, 2) <> '58' then
    raise exception 'Teléfono inválido: con código de país debe empezar por 58'
      using errcode = '23514';
  end if;
  if length(v_digits) = 11 and left(v_digits, 1) <> '0' then
    raise exception 'Teléfono inválido: con 11 dígitos debe empezar por 0'
      using errcode = '23514';
  end if;

  v_ref := btrim(coalesce(new.customer->>'ref', ''));
  if length(v_ref) > 120 then
    raise exception 'El punto de referencia no puede pasar de 120 caracteres'
      using errcode = '23514';
  end if;

  if new.type = 'delivery' then
    if nullif(btrim(coalesce(new.proof_url, '')), '') is null then
      raise exception 'El delivery requiere comprobante de pago'
        using errcode = '23514';
    end if;
    if nullif(btrim(coalesce(new.customer->>'zone', '')), '') is null then
      raise exception 'El delivery requiere la zona calculada'
        using errcode = '23514';
    end if;
  end if;

  if new.items is null or new.items::text in ('[]', 'null') then
    raise exception 'El pedido no tiene productos'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_validate_order_insert on public.orders;
create trigger trg_validate_order_insert
before insert on public.orders
for each row execute function private.validate_order_insert();

commit;

-- Verificación: la función y el trigger deben existir
select p.proname, p.prosecdef
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'private' and p.proname = 'validate_order_insert';

select tgname, pg_get_triggerdef(t.oid) as definicion
from pg_trigger t
where t.tgname = 'trg_validate_order_insert';

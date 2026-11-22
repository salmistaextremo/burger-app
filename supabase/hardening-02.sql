-- ============================================================
-- ENDURECIMIENTO 02 — pedidos y comprobantes
--
-- Contexto: el proyecto Supabase es de uso exclusivo de DLV Food.
--
--   1. Los pedidos solo pueden crearse como pedidos nuevos y válidos.
--   2. El bucket `comprobantes` deja de ser público. El cliente sube la
--      imagen y guarda la RUTA; el admin firma la URL al abrirla.
--
-- Orden de despliegue (importante):
--   1) Desplegar el código nuevo (index.html + admin.html): guarda rutas y firma URLs.
--   2) Ejecutar este SQL: recién ahí el bucket pasa a privado.
--   Así ningún comprobante nuevo queda con una URL rota. Los antiguos se siguen
--   abriendo porque el admin extrae la ruta de la URL pública y la firma.
--
-- Revisar y hacer backup antes. Es transaccional.
-- ============================================================

begin;

-- 1) Inserción de pedidos acotada
drop policy if exists "Pedidos insercion publica" on public.orders;
create policy "Pedidos insercion publica"
  on public.orders for insert
  to anon, authenticated
  with check (
    status = 'recibido'
    and type in ('delivery', 'pickup')
    and total >= 0
    and code ~ '^A-[A-Z0-9]{4,8}$'
    and customer is not null
  );

-- 2) Comprobantes privados
update storage.buckets set public = false where id = 'comprobantes';

-- Solo el admin autenticado puede leer/firmar comprobantes
drop policy if exists "Comprobantes lectura publica" on storage.objects;
create policy "Comprobantes lectura admin"
  on storage.objects for select
  to authenticated
  using (bucket_id = 'comprobantes');

-- El cliente sigue subiendo, pero solo a ese bucket
drop policy if exists "Comprobantes subida publica" on storage.objects;
create policy "Comprobantes subida publica"
  on storage.objects for insert
  to anon, authenticated
  with check (bucket_id = 'comprobantes');

commit;

-- Verificación
select id, name, public from storage.buckets where id = 'comprobantes';
select policyname, cmd, roles from pg_policies
where schemaname = 'storage' and policyname like 'Comprobantes%'
order by policyname;

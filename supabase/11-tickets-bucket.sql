-- ============================================================
-- MIGRACIÓN 11 — Bucket privado para tickets de pedidos
--
-- La imagen se sube desde /api/ticket con la service_role y se
-- devuelve un link firmado (7 días). No se expone el bucket.
-- ============================================================

begin;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('tickets', 'tickets', false, 2097152, array['image/png'])
on conflict (id) do update
  set public = false,
      file_size_limit = 2097152,
      allowed_mime_types = array['image/png'];

commit;

select id, name, public, file_size_limit, allowed_mime_types
from storage.buckets
where id = 'tickets';

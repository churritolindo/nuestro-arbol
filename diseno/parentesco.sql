-- ============================================================
--  NUESTRO ÁRBOL — Parentesco (para el árbol genealógico)
--  Pega esto en Supabase → SQL Editor → New query → Run
--  Añade a cada persona de quién es hijo/a, su pareja y sus apellidos.
-- ============================================================

alter table miembros add column if not exists padre_id  uuid;
alter table miembros add column if not exists madre_id  uuid;
alter table miembros add column if not exists pareja_id uuid;
alter table miembros add column if not exists apellidos text;
alter table miembros add column if not exists expareja boolean default false;

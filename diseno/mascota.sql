-- ============================================================
--  NUESTRO ÁRBOL — Árbol de mascotas
--  Pega esto en Supabase → SQL Editor → New query → Run
--  Añade la casilla para saber si la familia quiere el arbolito de mascotas.
-- ============================================================

alter table arboles add column if not exists mascota boolean default false;

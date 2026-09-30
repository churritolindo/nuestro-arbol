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
alter table miembros add column if not exists tipo_pareja text default 'pareja';  -- casados / pareja / novios / ex
alter table miembros add column if not exists lugar_nac text;   -- dónde nació (ciudad)
alter table miembros add column if not exists nicho text;       -- dónde descansa (si ha fallecido)
alter table miembros add column if not exists trabajo text;     -- dónde/en qué trabajó

-- Muro de anécdotas firmadas (reutiliza la tabla contenido con tipo='anecdota')
alter table contenido add column if not exists autor text;      -- quién firma la anécdota (ej. "su nieto Luis")

-- Grupos de amigos/mascotas ("Amigos de Luis", "Amigos de la familia"…)
alter table miembros add column if not exists grupo text default 'Familia';

-- Especie (imagen) elegida para el arbolito de amigos y el de mascotas
alter table arboles add column if not exists especie_amigos   text default 'cerezo';
alter table arboles add column if not exists especie_mascotas text default 'olivo';

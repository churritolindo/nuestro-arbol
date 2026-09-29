-- Añade el hueco para la foto de cada persona.
-- Pega en Supabase → SQL Editor → New query → Run.
alter table miembros add column if not exists foto text;

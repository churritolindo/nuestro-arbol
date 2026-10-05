-- ============================================================
--  NUESTRO ÁRBOL — FASE 2 (compartir): tablas de invitaciones y miembros
--  Pega esto en Supabase → SQL Editor → New query → Run
--  Es ADITIVO: crea tablas nuevas, NO toca las que ya funcionan.
--  (El permiso para que el invitado VEA tu árbol se hará en un
--   segundo paso aparte, con cuidado y con "deshacer" preparado.)
-- ============================================================

-- 1) Códigos de invitación que genera el dueño del árbol
create table if not exists invitaciones (
  id          uuid primary key default gen_random_uuid(),
  arbol_id    uuid not null references arboles(id) on delete cascade,
  codigo      text unique not null,
  rol         text not null default 'visitante',   -- visitante | colaborador
  creado_por  uuid,
  usos        int default 0,
  max_usos    int default 50,
  caduca      timestamptz,
  creado      timestamptz default now()
);
alter table invitaciones enable row level security;

-- El dueño del árbol crea, ve y borra SUS invitaciones
drop policy if exists inv_dueno_all on invitaciones;
create policy inv_dueno_all on invitaciones for all
  using      (exists (select 1 from arboles a where a.id = invitaciones.arbol_id and a.dueno = auth.uid()))
  with check (exists (select 1 from arboles a where a.id = invitaciones.arbol_id and a.dueno = auth.uid()));

-- 2) Quién puede entrar en cada árbol y con qué rol
create table if not exists arbol_miembros (
  arbol_id  uuid not null references arboles(id) on delete cascade,
  user_id   uuid not null,
  rol       text not null default 'visitante',   -- visitante | colaborador | dueno
  creado    timestamptz default now(),
  primary key (arbol_id, user_id)
);
alter table arbol_miembros enable row level security;

-- El dueño gestiona los miembros de su árbol; cada uno puede ver su propia fila
drop policy if exists am_dueno on arbol_miembros;
create policy am_dueno on arbol_miembros for all
  using      (exists (select 1 from arboles a where a.id = arbol_miembros.arbol_id and a.dueno = auth.uid()))
  with check (exists (select 1 from arboles a where a.id = arbol_miembros.arbol_id and a.dueno = auth.uid()));

drop policy if exists am_propia on arbol_miembros;
create policy am_propia on arbol_miembros for select using (user_id = auth.uid());

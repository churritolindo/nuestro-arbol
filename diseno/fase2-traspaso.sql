-- ============================================================
--  NUESTRO ÁRBOL — TRASPASO DE PROPIEDAD (cambiar de dueño con aceptación)
--  Pega esto en Supabase → SQL Editor → New query → Run.
--  Aditivo y reversible. Requiere el arreglo de recursión (es_dueno).
--
--  Qué hace:
--   · El dueño genera un código de traspaso y elige cómo quiere quedarse
--     (como familiar, o salirse del árbol).
--   · Otra persona mete el código y lo ACEPTA → pasa a ser el nuevo dueño.
--   · El cambio solo ocurre con esa aceptación (nadie puede robar el árbol).
-- ============================================================

create table if not exists traspasos (
  id            uuid primary key default gen_random_uuid(),
  arbol_id      uuid not null references arboles(id) on delete cascade,
  codigo        text unique not null,
  creado_por    uuid,                                   -- dueño que sale
  rol_saliente  text not null default 'familiar',       -- 'familiar' | 'fuera'
  estado        text not null default 'pendiente',      -- pendiente | aceptado | cancelado
  aceptado_por  uuid,
  creado        timestamptz default now(),
  caduca        timestamptz default (now() + interval '7 days')
);
alter table traspasos enable row level security;

-- El dueño crea, ve y cancela los traspasos de SU árbol
drop policy if exists tr_dueno on traspasos;
create policy tr_dueno on traspasos for all to authenticated
  using ( es_dueno(arbol_id) )
  with check ( es_dueno(arbol_id) );

-- Aceptar un traspaso (cambia el dueño de forma segura)
create or replace function aceptar_traspaso(p_codigo text) returns uuid
  language plpgsql security definer set search_path = public as $$
declare t traspasos; aid uuid; viejo uuid;
begin
  select * into t from traspasos where codigo = p_codigo and estado = 'pendiente' limit 1;
  if t.id is null then raise exception 'codigo no valido o ya usado'; end if;
  if t.caduca is not null and t.caduca < now() then raise exception 'codigo caducado'; end if;
  if t.creado_por = auth.uid() then raise exception 'no puedes aceptar tu propio traspaso'; end if;

  aid := t.arbol_id;
  viejo := (select dueno from arboles where id = aid);

  -- 1) cambiar el dueño del árbol
  update arboles set dueno = auth.uid() where id = aid;

  -- 2) qué pasa con el dueño que sale
  if t.rol_saliente = 'fuera' then
     delete from arbol_miembros where arbol_id = aid and user_id = viejo;
  else
     if exists (select 1 from arbol_miembros where arbol_id = aid and user_id = viejo) then
        update arbol_miembros set rol = 'colaborador' where arbol_id = aid and user_id = viejo;
     else
        insert into arbol_miembros (arbol_id, user_id, rol, miembro_ok)
          values (aid, viejo, 'colaborador', true);
     end if;
  end if;

  -- 3) cerrar este traspaso y cancelar otros pendientes del mismo árbol
  update traspasos set estado = 'aceptado', aceptado_por = auth.uid() where id = t.id;
  update traspasos set estado = 'cancelado' where arbol_id = aid and estado = 'pendiente' and id <> t.id;

  return aid;
end; $$;

grant execute on function aceptar_traspaso(text) to authenticated;

-- ============================================================
--  ⏪ DESHACER
-- ============================================================
-- drop function if exists aceptar_traspaso(text);
-- drop table if exists traspasos;

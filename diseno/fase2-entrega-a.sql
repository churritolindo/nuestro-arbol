-- ============================================================
--  NUESTRO ÁRBOL — ENTREGA REAL · FASE A ("¿quién eres en este árbol?")
--  Pega esto en Supabase → SQL Editor → New query → Run.
--  Aditivo y reversible. Requiere el arreglo de recursión ya aplicado
--  (usa es_miembro).
--
--  Qué hace:
--   · Enlaza cada cuenta con SU persona del árbol (miembro_id).
--   · El enlace que pone uno mismo queda PENDIENTE (miembro_ok = false)
--     hasta que el dueño lo confirma. El dueño, al ponerse a sí mismo,
--     queda confirmado directamente.
--   · La función es segura: solo toca la fila de quien la llama y solo
--     permite elegir una ficha que de verdad es de ese árbol.
-- ============================================================

-- 1) Columnas nuevas en arbol_miembros
alter table arbol_miembros add column if not exists miembro_id uuid;
alter table arbol_miembros add column if not exists miembro_ok boolean default false;

-- 2) Función: "yo soy esta persona del árbol" (segura, security definer)
create or replace function fijar_quien_soy(aid uuid, mid uuid) returns void
  language plpgsql security definer set search_path = public as $$
declare es_d boolean;
begin
  if not es_miembro(aid) then raise exception 'sin acceso a este arbol'; end if;
  if mid is not null and not exists (select 1 from miembros where id = mid and arbol_id = aid) then
     raise exception 'esa ficha no es de este arbol';
  end if;
  es_d := exists (select 1 from arboles where id = aid and dueno = auth.uid());
  if exists (select 1 from arbol_miembros where arbol_id = aid and user_id = auth.uid()) then
     update arbol_miembros
        set miembro_id = mid, miembro_ok = es_d   -- el dueño se auto-confirma; el resto queda pendiente
      where arbol_id = aid and user_id = auth.uid();
  else
     insert into arbol_miembros (arbol_id, user_id, miembro_id, miembro_ok, rol)
       values (aid, auth.uid(), mid, es_d, case when es_d then 'dueno' else 'visitante' end);
  end if;
end; $$;

grant execute on function fijar_quien_soy(uuid, uuid) to authenticated;

-- (El dueño confirma/cambia los enlaces de los demás con un UPDATE normal
--  sobre arbol_miembros, que ya le permite su política am_dueno.)

-- ============================================================
--  ⏪ DESHACER (si quieres quitarlo)
-- ============================================================
-- drop function if exists fijar_quien_soy(uuid, uuid);
-- (las columnas miembro_id / miembro_ok pueden quedarse; no molestan)

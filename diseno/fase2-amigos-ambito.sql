-- ============================================================
--  NUESTRO ÁRBOL — Fase 2 AMIGOS: que quien entra con el código de
--  AMIGOS solo vea y añada AMIGOS (nunca la familia).
--  Pega TODO esto en Supabase → SQL Editor → New query → Run.
--  Es SEGURO: aditivo y REVERSIBLE (al final el "DESHACER"). No borra nada.
--  Requiere el arreglo de recursión ya aplicado (es_miembro / arbol_de).
--
--  Cómo funciona: a cada miembro del árbol se le guarda un "ámbito":
--   · 'familia' (por defecto) = ve y añade TODO (lo de siempre).
--   · 'amigos'  = solo ve y añade fichas de la pestaña Amigos.
--  El dueño siempre es 'familia'. Las reglas nuevas son RESTRICTIVAS:
--  no le quitan nada a los de 'familia'; solo acotan a los de 'amigos'.
--  Hasta que la app marque a alguien como 'amigos', esto no cambia nada.
-- ============================================================

-- 1) Marca de ámbito en cada miembro del árbol (y en la invitación)
alter table arbol_miembros add column if not exists ambito text default 'familia';
alter table invitaciones   add column if not exists ambito text default 'familia';

-- 2) ¿Cuál es MI ámbito en este árbol? (el dueño siempre ve todo)
create or replace function public.mi_ambito(aid uuid) returns text
  language sql security definer stable set search_path = public as $$
  select case
    when exists (select 1 from arboles where id = aid and dueno = auth.uid()) then 'familia'
    else coalesce(
      (select ambito from arbol_miembros
        where arbol_id = aid and user_id = auth.uid() limit 1),
      'familia')
  end;
$$;
grant execute on function public.mi_ambito(uuid) to authenticated, anon;

-- 3) FICHAS: si tu ámbito es 'amigos', solo puedes ver/añadir fichas de clase 'amigo'
drop policy if exists mi_solo_amigos on miembros;
create policy mi_solo_amigos on miembros
  as restrictive for all
  using      ( mi_ambito(arbol_id) = 'familia' or clase = 'amigo' )
  with check ( mi_ambito(arbol_id) = 'familia' or clase = 'amigo' );

-- 4) RECUERDOS: igual, solo los de fichas de clase 'amigo'
drop policy if exists co_solo_amigos on contenido;
create policy co_solo_amigos on contenido
  as restrictive for all
  using      ( mi_ambito( arbol_de(miembro_id) ) = 'familia'
               or exists (select 1 from miembros m
                          where m.id = contenido.miembro_id and m.clase = 'amigo') )
  with check ( mi_ambito( arbol_de(miembro_id) ) = 'familia'
               or exists (select 1 from miembros m
                          where m.id = contenido.miembro_id and m.clase = 'amigo') );

-- 5) Que el canje de código seguro también guarde el ámbito
create or replace function public.usar_invitacion(p_codigo text) returns uuid
  language plpgsql security definer set search_path = public as $$
declare inv invitaciones;
begin
  select * into inv from invitaciones where codigo = p_codigo limit 1;
  if not found then raise exception 'codigo no valido'; end if;
  if coalesce(inv.un_solo_uso,false) and coalesce(inv.usado,false) then
     raise exception 'codigo ya usado';
  end if;
  if not exists (select 1 from arbol_miembros where arbol_id = inv.arbol_id and user_id = auth.uid()) then
     insert into arbol_miembros (arbol_id, user_id, rol, ambito)
       values (inv.arbol_id, auth.uid(), coalesce(inv.rol,'visitante'), coalesce(inv.ambito,'familia'));
  end if;
  if coalesce(inv.un_solo_uso,false) then
     update invitaciones set usado = true, usado_por = auth.uid() where codigo = p_codigo;
  end if;
  return inv.arbol_id;
end; $$;
grant execute on function public.usar_invitacion(text) to authenticated;

-- ============================================================
--  ⏪ DESHACER (vuelve a como estaba: todos ven todo)
-- ============================================================
-- drop policy if exists mi_solo_amigos on miembros;
-- drop policy if exists co_solo_amigos on contenido;
-- drop function if exists public.mi_ambito(uuid);
-- (las columnas 'ambito' pueden quedarse; no molestan)

-- ============================================================
--  NUESTRO ÁRBOL — Códigos "para una persona" (un solo uso) / "para todos"
--  Pega esto en Supabase → SQL Editor → New query → Run.
--  Aditivo y reversible. Requiere el arreglo de recursión (usa arbol_miembros).
--
--  Qué hace:
--   · Añade a las invitaciones la marca "un_solo_uso" (y a quién/si se usó).
--   · Crea una función segura usar_invitacion(codigo) que da acceso al árbol
--     y, si el código era de un solo uso, lo marca como gastado para que no
--     lo pueda reutilizar otra persona.
-- ============================================================

-- 1) Columnas nuevas en invitaciones
alter table invitaciones add column if not exists un_solo_uso boolean default false;
alter table invitaciones add column if not exists usado       boolean default false;
alter table invitaciones add column if not exists usado_por   uuid;

-- 2) Canjear un código de forma segura (da de alta como miembro y marca usado)
create or replace function usar_invitacion(p_codigo text) returns uuid
  language plpgsql security definer set search_path = public as $$
declare inv invitaciones;
begin
  select * into inv from invitaciones where codigo = p_codigo limit 1;
  if not found then raise exception 'codigo no valido'; end if;
  if coalesce(inv.un_solo_uso,false) and coalesce(inv.usado,false) then
     raise exception 'codigo ya usado';
  end if;
  -- alta como miembro si aún no lo es
  if not exists (select 1 from arbol_miembros where arbol_id = inv.arbol_id and user_id = auth.uid()) then
     insert into arbol_miembros (arbol_id, user_id, rol)
       values (inv.arbol_id, auth.uid(), coalesce(inv.rol,'visitante'));
  end if;
  -- si era de un solo uso, marcarlo como gastado
  if coalesce(inv.un_solo_uso,false) then
     update invitaciones set usado = true, usado_por = auth.uid() where codigo = p_codigo;
  end if;
  return inv.arbol_id;
end; $$;

grant execute on function usar_invitacion(text) to authenticated;

-- ============================================================
--  ⏪ DESHACER
-- ============================================================
-- drop function if exists usar_invitacion(text);
-- alter table invitaciones drop column if exists un_solo_uso;
-- alter table invitaciones drop column if exists usado;
-- alter table invitaciones drop column if exists usado_por;

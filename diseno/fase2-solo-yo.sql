-- ============================================================
--  NUESTRO ÁRBOL — "SOLO YO / TODO EL GRUPO" en cada recuerdo
--  Pega esto en Supabase → SQL Editor → New query → Run.
--  Aditivo y reversible. Requiere el arreglo de recursión ya aplicado
--  (fase2-fix-recursion.sql), porque reusa la función es_miembro/arbol_de.
--
--  Qué hace:
--   · Añade una marca "solo_autor" a cada recuerdo.
--   · Si está marcado, ese recuerdo solo lo ve QUIEN lo subió
--     (el dueño del árbol, como guardián, sigue viéndolo todo).
--   · Si no está marcado, lo ve todo el árbol, como hasta ahora.
-- ============================================================

-- 1) La marca (por defecto NO, o sea "todo el grupo")
alter table contenido add column if not exists solo_autor boolean default false;

-- 2) Regla de lectura: los miembros ven el contenido del árbol,
--    pero NO los recuerdos marcados "solo yo" de otras personas.
drop policy if exists co_ver_miembro on contenido;
create policy co_ver_miembro on contenido for select
  using (
    es_miembro( arbol_de(miembro_id) )
    and ( coalesce(solo_autor,false) = false or subido_por = auth.uid() )
  );

-- ============================================================
--  ⏪ DESHACER (vuelve a como estaba: todos los miembros ven todo)
-- ============================================================
-- drop policy if exists co_ver_miembro on contenido;
-- create policy co_ver_miembro on contenido for select
--   using ( es_miembro( arbol_de(miembro_id) ) );
-- (la columna solo_autor puede quedarse; no molesta)

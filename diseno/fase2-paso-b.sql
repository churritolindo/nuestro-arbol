-- ============================================================
--  NUESTRO ÁRBOL — FASE 2 · PASO B (el código abre el árbol correcto)
--  Pega esto en Supabase → SQL Editor → New query → Run
--  Es ADITIVO (solo AÑADE permisos de LECTURA para miembros; no quita
--  nada al dueño) y es REVERSIBLE (al final tienes el "DESHACER").
--  Requiere que ya exista la tabla arbol_miembros e invitaciones
--  (diseno/fase2-compartir.sql) y la columna invitaciones.ambito.
-- ============================================================

-- 1) Cualquier usuario identificado puede LEER una invitación por su código
--    (lo necesita para poder canjearlo). Solo lectura.
drop policy if exists inv_leer_para_canjear on invitaciones;
create policy inv_leer_para_canjear on invitaciones
  for select to authenticated using (true);

-- 2) Un usuario puede darse de alta como MIEMBRO de un árbol
--    siempre que ese árbol tenga alguna invitación (es decir, te invitaron).
drop policy if exists am_alta_invitado on arbol_miembros;
create policy am_alta_invitado on arbol_miembros
  for insert to authenticated with check (
    user_id = auth.uid()
    and exists (select 1 from invitaciones i where i.arbol_id = arbol_miembros.arbol_id)
  );

-- 3) Los MIEMBROS pueden VER el árbol, sus fichas y sus recuerdos
--    (esto se SUMA al permiso que ya tiene el dueño; el dueño no pierde nada).
drop policy if exists arb_ver_miembro on arboles;
create policy arb_ver_miembro on arboles
  for select using (
    dueno = auth.uid()
    or exists (select 1 from arbol_miembros m
               where m.arbol_id = arboles.id and m.user_id = auth.uid())
  );

drop policy if exists mi_ver_miembro on miembros;
create policy mi_ver_miembro on miembros
  for select using (
    exists (select 1 from arboles a
            where a.id = miembros.arbol_id
              and ( a.dueno = auth.uid()
                    or exists (select 1 from arbol_miembros m
                               where m.arbol_id = a.id and m.user_id = auth.uid()) ))
  );

drop policy if exists co_ver_miembro on contenido;
create policy co_ver_miembro on contenido
  for select using (
    exists (select 1 from miembros mm
            join arboles a on a.id = mm.arbol_id
            where mm.id = contenido.miembro_id
              and ( a.dueno = auth.uid()
                    or exists (select 1 from arbol_miembros m
                               where m.arbol_id = a.id and m.user_id = auth.uid()) ))
  );

-- ============================================================
--  ⏪ DESHACER (si algo se ve raro, pega SOLO esto y Run; vuelve a estar como antes)
-- ============================================================
-- drop policy if exists inv_leer_para_canjear on invitaciones;
-- drop policy if exists am_alta_invitado on arbol_miembros;
-- drop policy if exists arb_ver_miembro on arboles;
-- drop policy if exists mi_ver_miembro on miembros;
-- drop policy if exists co_ver_miembro on contenido;

-- NOTA: las FOTOS/vídeos (Storage) todavía no se verán para los invitados;
--       eso es un permiso aparte de Storage que haremos en el Paso B.2.
--       El árbol, las fichas y los textos/recuerdos sí se verán.

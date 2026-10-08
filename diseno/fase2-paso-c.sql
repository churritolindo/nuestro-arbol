-- ============================================================
--  NUESTRO ÁRBOL — FASE 2 · PASO C (escribir según el rol)
--  Pega esto en Supabase → SQL Editor → Run (DESPUÉS del Paso B y B.2).
--  ADITIVO (solo AÑADE permisos; el dueño no pierde nada) y REVERSIBLE.
--
--  Resultado:
--   · COLABORADOR  → añade/edita fichas, sube fotos/vídeos/audios y deja
--                    ofrendas (como un copropietario de ESE árbol).
--   · VISITANTE    → solo puede dejar OFRENDAS (flores, velas, frases).
--                    No sube fotos ni añade personas.
--   · DUEÑO        → igual que siempre (manda).
-- ============================================================

-- 1) COLABORADOR: crear/editar/borrar FICHAS del árbol
drop policy if exists mi_escribir_colab on miembros;
create policy mi_escribir_colab on miembros for all to authenticated
  using ( exists (select 1 from arboles a where a.id = miembros.arbol_id
            and ( a.dueno = auth.uid()
                  or exists (select 1 from arbol_miembros m
                             where m.arbol_id=a.id and m.user_id=auth.uid() and m.rol='colaborador'))) )
  with check ( exists (select 1 from arboles a where a.id = miembros.arbol_id
            and ( a.dueno = auth.uid()
                  or exists (select 1 from arbol_miembros m
                             where m.arbol_id=a.id and m.user_id=auth.uid() and m.rol='colaborador'))) );

-- 2) COLABORADOR: crear/editar/borrar RECUERDOS (contenido: fotos, vídeos, audios, textos, ofrendas)
drop policy if exists co_escribir_colab on contenido;
create policy co_escribir_colab on contenido for all to authenticated
  using ( exists (select 1 from miembros mm join arboles a on a.id=mm.arbol_id
            where mm.id = contenido.miembro_id
              and ( a.dueno = auth.uid()
                    or exists (select 1 from arbol_miembros m
                               where m.arbol_id=a.id and m.user_id=auth.uid() and m.rol='colaborador'))) )
  with check ( exists (select 1 from miembros mm join arboles a on a.id=mm.arbol_id
            where mm.id = contenido.miembro_id
              and ( a.dueno = auth.uid()
                    or exists (select 1 from arbol_miembros m
                               where m.arbol_id=a.id and m.user_id=auth.uid() and m.rol='colaborador'))) );

-- 3) VISITANTE (y colaborador): dejar OFRENDAS en cualquier ficha del árbol al que pertenece
drop policy if exists co_ofrenda_visitante on contenido;
create policy co_ofrenda_visitante on contenido for insert to authenticated
  with check ( tipo = 'ofrenda'
    and exists (select 1 from miembros mm join arboles a on a.id=mm.arbol_id
                where mm.id = contenido.miembro_id
                  and exists (select 1 from arbol_miembros m
                              where m.arbol_id=a.id and m.user_id=auth.uid())) );

-- 4) COLABORADOR: subir/editar/borrar ARCHIVOS (Storage) de las fichas de su árbol
--    (la ruta es  uid/miembro/archivo ; comprobamos que ese 'miembro' sea de un árbol suyo)
drop policy if exists media_colab_rw on storage.objects;
create policy media_colab_rw on storage.objects for all to authenticated
  using ( bucket_id='media' and exists (
            select 1 from miembros mm join arboles a on a.id=mm.arbol_id
            where mm.id::text = (storage.foldername(name))[2]
              and ( a.dueno = auth.uid()
                    or exists (select 1 from arbol_miembros m
                               where m.arbol_id=a.id and m.user_id=auth.uid() and m.rol='colaborador'))) )
  with check ( bucket_id='media' and exists (
            select 1 from miembros mm join arboles a on a.id=mm.arbol_id
            where mm.id::text = (storage.foldername(name))[2]
              and ( a.dueno = auth.uid()
                    or exists (select 1 from arbol_miembros m
                               where m.arbol_id=a.id and m.user_id=auth.uid() and m.rol='colaborador'))) );

-- ============================================================
--  ⏪ DESHACER (si algo se ve raro, pega SOLO esto y Run)
-- ============================================================
-- drop policy if exists mi_escribir_colab    on miembros;
-- drop policy if exists co_escribir_colab    on contenido;
-- drop policy if exists co_ofrenda_visitante on contenido;
-- drop policy if exists media_colab_rw       on storage.objects;

-- ============================================================
--  NUESTRO ÁRBOL — FASE 2 · PASO B.2 (que el invitado vea FOTOS y VÍDEOS)
--  Pega esto en Supabase → SQL Editor → New query → Run
--  Es ADITIVO (solo AÑADE permiso de LECTURA de archivos a los miembros;
--  el dueño no pierde nada) y REVERSIBLE (al final el "DESHACER").
--  Hazlo DESPUÉS del Paso B (fase2-paso-b.sql).
-- ============================================================

-- Un MIEMBRO puede LEER (ver) un archivo del cubo 'media' si ese archivo
-- pertenece a una ficha/recuerdo de un árbol al que tiene acceso
-- (ya sea el dueño o un invitado dado de alta en arbol_miembros).
drop policy if exists media_ver_miembro on storage.objects;
create policy media_ver_miembro on storage.objects
  for select to authenticated using (
    bucket_id = 'media'
    and (
      -- fotos/vídeos/audios de recuerdos (contenido.archivo_path)
      exists (
        select 1 from contenido c
        join miembros mm on mm.id = c.miembro_id
        join arboles  a  on a.id  = mm.arbol_id
        where c.archivo_path = storage.objects.name
          and ( a.dueno = auth.uid()
                or exists (select 1 from arbol_miembros m
                           where m.arbol_id = a.id and m.user_id = auth.uid()) )
      )
      -- foto de perfil de cada ficha (miembros.foto)
      or exists (
        select 1 from miembros mm
        join arboles a on a.id = mm.arbol_id
        where mm.foto = storage.objects.name
          and ( a.dueno = auth.uid()
                or exists (select 1 from arbol_miembros m
                           where m.arbol_id = a.id and m.user_id = auth.uid()) )
      )
    )
  );

-- ============================================================
--  ⏪ DESHACER (si algo se ve raro, pega SOLO esto y Run)
-- ============================================================
-- drop policy if exists media_ver_miembro on storage.objects;

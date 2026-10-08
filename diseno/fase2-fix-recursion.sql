-- ============================================================
--  NUESTRO ÁRBOL — ARREGLO: "infinite recursion detected in policy for relation arboles"
--  Pega TODO esto en Supabase → SQL Editor → New query → Run.
--
--  QUÉ PASA: dos reglas (RLS) se llamaban la una a la otra en círculo
--  (árboles ↔ miembros), y Postgres entra en bucle. Esto lo arregla de
--  forma correcta y definitiva: mete las comprobaciones dentro de unas
--  funciones de seguridad que NO vuelven a disparar las reglas.
--
--  Es SEGURO: el dueño no pierde nada. Y es REVERSIBLE (al final, "DESHACER").
--  Después de correr esto, la app vuelve a leer tus datos con normalidad.
-- ============================================================

-- 1) FUNCIONES DE SEGURIDAD (rompen el círculo)
--    'security definer' = se ejecutan por dentro sin volver a aplicar las reglas.
create or replace function public.es_dueno(aid uuid) returns boolean
  language sql security definer stable set search_path = public as $$
  select exists (select 1 from arboles a where a.id = aid and a.dueno = auth.uid());
$$;

create or replace function public.es_miembro(aid uuid) returns boolean
  language sql security definer stable set search_path = public as $$
  select exists (select 1 from arboles a where a.id = aid and a.dueno = auth.uid())
      or exists (select 1 from arbol_miembros m where m.arbol_id = aid and m.user_id = auth.uid());
$$;

create or replace function public.es_colaborador(aid uuid) returns boolean
  language sql security definer stable set search_path = public as $$
  select exists (select 1 from arboles a where a.id = aid and a.dueno = auth.uid())
      or exists (select 1 from arbol_miembros m
                 where m.arbol_id = aid and m.user_id = auth.uid() and m.rol = 'colaborador');
$$;

create or replace function public.arbol_de(mid uuid) returns uuid
  language sql security definer stable set search_path = public as $$
  select arbol_id from miembros where id = mid;
$$;

grant execute on function public.es_dueno(uuid), public.es_miembro(uuid),
  public.es_colaborador(uuid), public.arbol_de(uuid) to authenticated, anon;

-- 2) REESCRIBIMOS LAS REGLAS usando las funciones (ya no se muerden la cola)

-- ÁRBOLES: puedo ver un árbol si soy su dueño o un miembro invitado
drop policy if exists arb_ver_miembro on arboles;
create policy arb_ver_miembro on arboles for select
  using ( es_miembro(id) );

-- ARBOL_MIEMBROS: el dueño gestiona los miembros de su árbol
drop policy if exists am_dueno on arbol_miembros;
create policy am_dueno on arbol_miembros for all
  using ( es_dueno(arbol_id) )
  with check ( es_dueno(arbol_id) );
-- (la regla am_propia "cada uno ve su fila" se queda igual)

-- INVITACIONES: el dueño crea/ve/borra sus invitaciones
drop policy if exists inv_dueno_all on invitaciones;
create policy inv_dueno_all on invitaciones for all
  using ( es_dueno(arbol_id) )
  with check ( es_dueno(arbol_id) );
-- (inv_leer_para_canjear "leer por código" se queda igual)

-- MIEMBROS (fichas): verlas si eres miembro; editarlas si eres dueño o colaborador
drop policy if exists mi_ver_miembro on miembros;
create policy mi_ver_miembro on miembros for select
  using ( es_miembro(arbol_id) );

drop policy if exists mi_escribir_colab on miembros;
create policy mi_escribir_colab on miembros for all
  using ( es_colaborador(arbol_id) )
  with check ( es_colaborador(arbol_id) );

-- CONTENIDO (recuerdos): ver si eres miembro; escribir si dueño/colaborador; ofrenda cualquier miembro
drop policy if exists co_ver_miembro on contenido;
create policy co_ver_miembro on contenido for select
  using ( es_miembro( arbol_de(miembro_id) ) );

drop policy if exists co_escribir_colab on contenido;
create policy co_escribir_colab on contenido for all
  using ( es_colaborador( arbol_de(miembro_id) ) )
  with check ( es_colaborador( arbol_de(miembro_id) ) );

drop policy if exists co_ofrenda_visitante on contenido;
create policy co_ofrenda_visitante on contenido for insert
  with check ( tipo = 'ofrenda' and es_miembro( arbol_de(miembro_id) ) );

-- (Las reglas de Storage —fotos/vídeos— NO se tocan: ya no causan bucle.)

-- ============================================================
--  ✅ LISTO. Vuelve a abrir la app: ya debería leer tus datos.
-- ============================================================

-- ============================================================
--  ⏪ DESHACER TOTAL (si quieres volver al estado "solo el dueño", pega SOLO esto)
-- ============================================================
-- drop policy if exists arb_ver_miembro    on arboles;
-- drop policy if exists mi_ver_miembro      on miembros;
-- drop policy if exists mi_escribir_colab   on miembros;
-- drop policy if exists co_ver_miembro      on contenido;
-- drop policy if exists co_escribir_colab   on contenido;
-- drop policy if exists co_ofrenda_visitante on contenido;
-- -- (deja am_dueno / inv_dueno_all como están: el dueño los necesita y ya no hay bucle)

-- ============================================================
--  🚑 EMERGENCIA (si solo quieres que la app LEA YA y arreglar el resto luego):
--     pega SOLO esta línea y Run. Quita la vista de invitados; el dueño entra bien.
-- ============================================================
-- drop policy if exists arb_ver_miembro on arboles;

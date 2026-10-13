-- ==========================================================
--  NUESTRO ÁRBOL — TODO EN UNO (Fase 2)
--  Pega TODO esto en Supabase → SQL Editor → New query → Run.
--  Es seguro ejecutarlo aunque ya hubieras corrido alguna parte
--  (todo lleva "si no existe" / "reemplazar"). Orden ya correcto.
--  Requiere el arreglo de recursion ya aplicado (es_dueno/es_miembro).
-- ==========================================================


-- ===================== (1/6) fase2-solo-yo.sql =====================
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

-- ===================== (2/6) fase2-entrega-a.sql =====================
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

-- ===================== (3/6) fase2-entrega-c.sql =====================
-- ============================================================
--  NUESTRO ÁRBOL — ENTREGA REAL · FASE C (seguridad en la base de datos)
--  Pega esto en Supabase → SQL Editor → New query → Run.
--  Aditivo y REVERSIBLE (al final el "DESHACER"). Requiere: arreglo de
--  recursión (es_miembro/es_dueno/arbol_de) y Fase A (miembro_ok).
--
--  Qué consigue:
--   · Un mensaje privado SOLO lo puede leer: su autor, el dueño del árbol,
--     o el destinatario CONFIRMADO, y únicamente cuando llega su momento
--     (fecha / fallecimiento / siempre). Ni antes, ni otra persona.
--   · "Confirmado" = el dueño ha validado quién es ese invitado (miembro_ok).
--     Así nadie puede hacerse pasar por otro para leer su carta.
-- ============================================================

-- 1) ¿Qué persona del árbol soy yo, YA CONFIRMADO por el dueño?
create or replace function mi_miembro_confirmado(aid uuid) returns uuid
  language sql security definer stable set search_path = public as $$
  select miembro_id from arbol_miembros
   where arbol_id = aid and user_id = auth.uid() and coalesce(miembro_ok,false) = true
   limit 1;
$$;

-- 2) ¿Ha llegado el momento de abrir el mensaje?
create or replace function _tiempo_ok_sql(p_cuando text, p_fecha date, p_miembro uuid) returns boolean
  language sql security definer stable set search_path = public as $$
  select case
    when p_cuando = 'siempre' then true
    when p_cuando = 'fecha' then (p_fecha is not null and p_fecha <= current_date)
    when p_cuando = 'fallecimiento' then exists (select 1 from miembros where id = p_miembro and fallecimiento is not null)
    else false
  end;
$$;

-- 3) ¿Soy yo (confirmado) un destinatario de este mensaje?
create or replace function _soy_destinatario(p_destino text, p_para_ids text, aid uuid) returns boolean
  language sql security definer stable set search_path = public as $$
  select case
    when p_destino = 'todos' then true
    when p_destino = 'persona' then (
      mi_miembro_confirmado(aid) is not null
      and mi_miembro_confirmado(aid)::text = any (string_to_array(coalesce(p_para_ids,''), ','))
    )
    when p_destino in ('familia','amigos') then exists (
      select 1 from miembros m
      where m.id = mi_miembro_confirmado(aid)
        and ( (p_destino = 'amigos'  and m.clase = 'amigo')
           or (p_destino = 'familia' and coalesce(m.clase,'') <> 'amigo') )
    )
    else false
  end;
$$;

grant execute on function mi_miembro_confirmado(uuid), _tiempo_ok_sql(text,date,uuid),
  _soy_destinatario(text,text,uuid) to authenticated;

-- 4) Regla de lectura de contenido (sustituye la anterior, ahora con la zona privada protegida)
drop policy if exists co_ver_miembro on contenido;
create policy co_ver_miembro on contenido for select using (
  es_miembro( arbol_de(miembro_id) )
  and ( coalesce(solo_autor,false) = false or subido_por = auth.uid() )   -- "solo yo"
  and (
        coalesce(privado,false) = false           -- contenido normal: como siempre
     or subido_por = auth.uid()                    -- soy el autor
     or es_dueno( arbol_de(miembro_id) )            -- soy el dueño (guardián)
     or (                                          -- soy destinatario confirmado Y ha llegado el momento
          _soy_destinatario(destino, para_ids, arbol_de(miembro_id))
          and _tiempo_ok_sql(cuando, fecha_ver, miembro_id)
        )
  )
);

-- ============================================================
--  ⏪ DESHACER (vuelve a la regla anterior; la zona privada dejaría de
--     estar protegida a nivel base de datos, pero la pantalla sí la filtra)
-- ============================================================
-- drop policy if exists co_ver_miembro on contenido;
-- create policy co_ver_miembro on contenido for select
--   using ( es_miembro( arbol_de(miembro_id) )
--     and ( coalesce(solo_autor,false) = false or subido_por = auth.uid() ) );
-- drop function if exists mi_miembro_confirmado(uuid);
-- drop function if exists _tiempo_ok_sql(text,date,uuid);
-- drop function if exists _soy_destinatario(text,text,uuid);

-- ===================== (4/6) fase2-traspaso.sql =====================
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

-- ===================== (5/6) fase2-parentesco.sql =====================
-- ============================================================
--  NUESTRO ÁRBOL — Etiqueta de PARENTESCO en cada ficha
--  Pega esto en Supabase → SQL Editor → New query → Run.
--  Aditivo y reversible. No afecta a nada de lo que ya hay.
--
--  Qué hace:
--   · Añade una columna de texto "parentesco" a las fichas de personas
--     (primo, tío, abuelo, bisabuelo, sobrino, primo segundo…).
--   · Es solo una etiqueta informativa que se ve en la ficha.
--  (Mientras no ejecutes esto, la app funciona igual: al guardar te avisa
--   de que el parentesco necesita este pasito, pero lo demás se guarda.)
-- ============================================================

alter table miembros add column if not exists parentesco text;

-- ============================================================
--  ⏪ DESHACER (si quieres quitarlo)
-- ============================================================
-- alter table miembros drop column if exists parentesco;

-- ===================== (6/6) fase2-invit-usos.sql =====================
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

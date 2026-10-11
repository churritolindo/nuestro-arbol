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

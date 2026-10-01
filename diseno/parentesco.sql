-- ============================================================
--  NUESTRO ÁRBOL — Parentesco (para el árbol genealógico)
--  Pega esto en Supabase → SQL Editor → New query → Run
--  Añade a cada persona de quién es hijo/a, su pareja y sus apellidos.
-- ============================================================

alter table miembros add column if not exists padre_id  uuid;
alter table miembros add column if not exists madre_id  uuid;
alter table miembros add column if not exists pareja_id uuid;
alter table miembros add column if not exists apellidos text;
alter table miembros add column if not exists expareja boolean default false;
alter table miembros add column if not exists tipo_pareja text default 'pareja';  -- casados / pareja / novios / ex
alter table miembros add column if not exists lugar_nac text;   -- dónde nació (ciudad)
alter table miembros add column if not exists nicho text;       -- dónde descansa (si ha fallecido)
alter table miembros add column if not exists trabajo text;     -- dónde/en qué trabajó

-- Muro de anécdotas firmadas (reutiliza la tabla contenido con tipo='anecdota')
alter table contenido add column if not exists autor text;      -- quién firma la anécdota (ej. "su nieto Luis")

-- Grupos de amigos/mascotas ("Amigos de Luis", "Amigos de la familia"…)
alter table miembros add column if not exists grupo text default 'Familia';

-- Mote / apodo (ej. "el guapo", "el gordi") — se muestra bajo el nombre en la ficha
alter table miembros add column if not exists apodo text;

-- Aniversario de boda (además de cumpleaños -nacimiento- y aniversario -fallecimiento-)
alter table miembros add column if not exists fecha_boda date;

-- Zona privada (diario + mensajes con destinatario y temporizador)
alter table miembros  add column if not exists zona_codigo text;   -- código de la zona privada (huella, no el código en claro)
alter table miembros  add column if not exists responsable text;   -- quién podrá abrir la zona privada el día de mañana
alter table contenido add column if not exists privado boolean default false;  -- true = está en la zona privada, no en Recuerdos
alter table contenido add column if not exists para_quien text;    -- destinatario libre (ej. "mis hijos", "Pilar")
alter table contenido add column if not exists relacion text;      -- familiar / amigo / pareja / otro
alter table contenido add column if not exists cuando text;        -- 'fallecimiento' | 'fecha' | 'siempre'
alter table contenido add column if not exists fecha_ver date;     -- si cuando='fecha', día en que se puede ver
alter table contenido add column if not exists destino text;       -- 'todos' | 'familia' | 'amigos' | 'persona'
alter table contenido add column if not exists para_id uuid;       -- (compat) si destino='persona', un solo id
alter table contenido add column if not exists para_ids text;      -- si destino='persona', ids separados por coma (varias personas)
alter table contenido add column if not exists leido boolean default false;  -- true = ya lo leíste; deja de avisar y pasa a "Mensajes guardados"

-- Especie (imagen) elegida para el arbolito de amigos y el de mascotas
alter table arboles add column if not exists especie_amigos   text default 'cerezo';
alter table arboles add column if not exists especie_mascotas text default 'olivo';

-- Cabeza del árbol principal: la pareja desde la que se pintan las 3 generaciones
-- (los antepasados por encima -bisabuelos, tatarabuelos- solo salen en "Ver su rama")
alter table arboles add column if not exists raiz_id uuid;

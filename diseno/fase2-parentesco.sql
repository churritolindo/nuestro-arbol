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

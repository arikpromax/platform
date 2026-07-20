-- ============================================================
--  SUSHI SHARK: додати галочку «Розтягнути фото на всю картку»
--  Оновлює ТІЛЬКИ конфіг (жодних видалень даних).
--  Запускати у SQL Editor проєкту platform
-- ============================================================

update public.sites
set config = jsonb_set(
  config,
  '{collections,0,fields}',
  (config #> '{collections,0,fields}') || '[
    {"key": "fill", "name": "Розтягнути фото на всю картку", "type": "checkbox", "extra": true}
  ]'::jsonb
)
where slug = 'sushishark';

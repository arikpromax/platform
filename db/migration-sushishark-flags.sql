-- ============================================================
--  SUSHI SHARK: позначки «Акція» і «Нема в наявності»
--  Оновлює ТІЛЬКИ конфіг. Запускати у SQL Editor проєкту platform
-- ============================================================

update public.sites
set config = jsonb_set(
  config,
  '{collections,0,fields}',
  (config #> '{collections,0,fields}') || '[
    {"key": "sale", "name": "Акція (жовта позначка)", "type": "checkbox", "extra": true},
    {"key": "out", "name": "Нема в наявності (блокує замовлення)", "type": "checkbox", "extra": true}
  ]'::jsonb
)
where slug = 'sushishark';
